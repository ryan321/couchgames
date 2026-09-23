//! Platform API for Home: accounts, the master library, and package downloads.
//!
//! The player talks only to this HTTP API. The SQLite file is this server's data.
//! It is the local stand-in for Neon; desktop apps never open it.

mod pages;
mod zipstore;

use getrandom::getrandom;
use rusqlite::{Connection, OptionalExtension, params};
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::{
    fs,
    io::{self, Read},
    path::{Path, PathBuf},
    sync::{Arc, Mutex},
    time::{SystemTime, UNIX_EPOCH},
};
use tiny_http::{Header, Method, Request, Response, Server, StatusCode};

pub use zipstore::{extract_stored, write_stored};

const CODE_ALPHABET: &[u8] = b"ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("{0}")]
    Message(String),
    #[error(transparent)]
    Io(#[from] io::Error),
    #[error(transparent)]
    Db(#[from] rusqlite::Error),
}

pub struct Platform {
    db: Mutex<Connection>,
    packages: PathBuf,
    origin: String,
}

pub fn open(data_dir: &Path, packages: &Path, origin: &str) -> Result<Platform, Error> {
    fs::create_dir_all(data_dir)?;
    fs::create_dir_all(packages)?;
    let db = Connection::open(data_dir.join("platform.sqlite"))?;
    db.execute_batch(
        "CREATE TABLE IF NOT EXISTS accounts (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE COLLATE NOCASE,
            salt BLOB NOT NULL,
            password_hash BLOB NOT NULL
        );
        CREATE TABLE IF NOT EXISTS sessions (
            token_hash TEXT PRIMARY KEY,
            account_id TEXT NOT NULL,
            name TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS device_codes (
            device_code TEXT PRIMARY KEY,
            user_code TEXT NOT NULL UNIQUE,
            account_id TEXT,
            name TEXT,
            expires_at INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS games (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            players TEXT NOT NULL,
            runtime TEXT NOT NULL,
            version TEXT NOT NULL,
            downloadable INTEGER NOT NULL,
            package_name TEXT NOT NULL,
            color TEXT NOT NULL
        );",
    )?;
    seed(&db)?;
    Ok(Platform {
        db: Mutex::new(db),
        packages: packages.to_path_buf(),
        origin: origin.trim_end_matches('/').to_string(),
    })
}

/// Build the Blob Island package the master library serves.
pub fn publish_blob_island(packages: &Path, source: &Path) -> Result<(), Error> {
    let files = [
        ("gigacouch.json", fs::read(source.join("gigacouch.json"))?),
        ("web/index.html", fs::read(source.join("web/index.html"))?),
        ("web/game.js", fs::read(source.join("web/game.js"))?),
        ("web/game.css", fs::read(source.join("web/game.css"))?),
    ];
    let owned: Vec<(&str, Vec<u8>)> = files
        .iter()
        .map(|(name, bytes)| (*name, bytes.clone()))
        .collect();
    let slices: Vec<(&str, &[u8])> = owned
        .iter()
        .map(|(name, bytes)| (*name, bytes.as_slice()))
        .collect();
    let zip = write_stored(&slices)?;
    fs::create_dir_all(packages)?;
    fs::write(packages.join("blob-island.zip"), zip)?;
    Ok(())
}

fn seed(db: &Connection) -> Result<(), Error> {
    let count: i64 = db.query_row("SELECT count(*) FROM games", [], |row| row.get(0))?;
    if count > 0 {
        return Ok(());
    }
    let games = [
        (
            "blob-island",
            "Blob Island",
            "A small island and a crowd of blobs.",
            "1–16 on this couch",
            "web-1",
            "0.1.0",
            1,
            "blob-island.zip",
            "#8ce8be",
        ),
        (
            "little-world",
            "Little World",
            "A tiny island. A whole couch of friends.",
            "1–16 players",
            "godot",
            "0.1.0",
            0,
            "",
            "#a5cfa1",
        ),
        (
            "cloudbound",
            "Cloudbound",
            "A scenic flight through the clouds.",
            "1 player",
            "godot",
            "0.1.0",
            0,
            "",
            "#9acbd8",
        ),
        (
            "pocket-rally",
            "Pocket Rally",
            "Your car. Your corner of the screen.",
            "1–16, split screen",
            "godot",
            "0.1.0",
            0,
            "",
            "#efba87",
        ),
        (
            "world-1-1",
            "Super Mario Bros.",
            "The original first level, recreated.",
            "1 player",
            "godot",
            "0.1.0",
            0,
            "",
            "#e8ba87",
        ),
        (
            "gauntlet",
            "Gauntlet",
            "Four heroes. Three vaults. A whole couch.",
            "1–16 together",
            "godot",
            "0.1.0",
            0,
            "",
            "#c5a0d9",
        ),
        (
            "sunbreak",
            "Sunbreak",
            "A sunlit island. A closing storm. Your last stand.",
            "1 player",
            "godot",
            "0.1.0",
            0,
            "",
            "#78bdba",
        ),
        (
            "haymaker",
            "Haymaker",
            "Host a brawl. Every player brings a screen.",
            "2–8 over the network",
            "godot",
            "0.1.0",
            0,
            "",
            "#e07a5f",
        ),
    ];
    for game in games {
        db.execute(
            "INSERT INTO games (id, title, description, players, runtime, version, downloadable, package_name, color)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)",
            params![game.0, game.1, game.2, game.3, game.4, game.5, game.6, game.7, game.8],
        )?;
    }
    Ok(())
}

pub fn handle_request(
    platform: &Platform,
    request: &mut Request,
) -> Response<std::io::Cursor<Vec<u8>>> {
    dispatch_one(platform, request)
}

fn dispatch(platform: Arc<Platform>, request: &mut Request) -> Response<std::io::Cursor<Vec<u8>>> {
    dispatch_one(&platform, request)
}

fn dispatch_one(platform: &Platform, request: &mut Request) -> Response<std::io::Cursor<Vec<u8>>> {
    let url = request.url().to_string();
    let path = url.split('?').next().unwrap_or("/");
    let mut body = Vec::new();
    let length = request.body_length().unwrap_or(0).min(32 * 1024 * 1024);
    if request
        .as_reader()
        .take(length as u64)
        .read_to_end(&mut body)
        .is_err()
    {
        return json_response(
            400,
            &json!({"ok": false, "error": "could not read the request"}),
        );
    }
    let method = request.method().clone();
    let result = route(platform, &method, path, &body, request);
    match result {
        Ok(response) => response,
        Err(error) => json_response(400, &json!({"ok": false, "error": error.to_string()})),
    }
}

fn route(
    platform: &Platform,
    method: &Method,
    path: &str,
    body: &[u8],
    request: &Request,
) -> Result<Response<std::io::Cursor<Vec<u8>>>, Error> {
    match (method, path) {
        (Method::Get, "/health") => Ok(json_response(200, &json!({"ok": true}))),
        (Method::Get, "/") => Ok(html_response(pages::LANDING_PAGE)),
        (Method::Get, "/site.css") => Ok(css_response(pages::SITE_CSS)),
        (Method::Get, "/brand/mark.png") => Ok(png_response(pages::MARK_PNG)),
        (Method::Get, "/account") | (Method::Get, "/link") => {
            Ok(html_response(pages::ACCOUNT_PAGE))
        }
        (Method::Post, "/v1/signup") => Ok(json_response(200, &signup(platform, body)?)),
        (Method::Post, "/v1/login") => Ok(json_response(200, &login(platform, body)?)),
        (Method::Post, "/v1/device") => Ok(json_response(200, &start_device(platform)?)),
        (Method::Post, "/v1/device/token") => Ok(json_response(200, &poll_device(platform, body)?)),
        (Method::Post, "/v1/link") => Ok(json_response(200, &approve_device(platform, body)?)),
        (Method::Get, "/v1/library") => {
            let account = require_account(platform, request)?;
            Ok(json_response(200, &library(platform, &account)?))
        }
        (Method::Get, package)
            if package.starts_with("/v1/games/") && package.ends_with("/package") =>
        {
            let account = require_account(platform, request)?;
            let id = package
                .trim_start_matches("/v1/games/")
                .trim_end_matches("/package");
            package_bytes(platform, &account, id)
        }
        _ => Ok(json_response(
            404,
            &json!({"ok": false, "error": "not found"}),
        )),
    }
}

fn start_device(platform: &Platform) -> Result<Value, Error> {
    let db = platform.db.lock().expect("platform db");
    let device_code = random_token();
    let raw = random_code(8);
    let user_code = format!("{}-{}", &raw[..4], &raw[4..]);
    let expires = unix_now() + 600;
    db.execute(
        "INSERT INTO device_codes (device_code, user_code, expires_at) VALUES (?1, ?2, ?3)",
        params![device_code, user_code, expires],
    )?;
    Ok(json!({
        "device_code": device_code,
        "user_code": user_code,
        "verification_uri": format!("{}/link", platform.origin),
        "expires_in": 600,
        "interval": 1
    }))
}

fn poll_device(platform: &Platform, body: &[u8]) -> Result<Value, Error> {
    let value: Value = serde_json::from_slice(body).unwrap_or(json!({}));
    let device_code = value
        .get("device_code")
        .and_then(|item| item.as_str())
        .unwrap_or("");
    let db = platform.db.lock().expect("platform db");
    let row = db
        .query_row(
            "SELECT account_id, name, expires_at FROM device_codes WHERE device_code = ?1",
            [device_code],
            |row| {
                Ok((
                    row.get::<_, Option<String>>(0)?,
                    row.get::<_, Option<String>>(1)?,
                    row.get::<_, i64>(2)?,
                ))
            },
        )
        .optional()?;
    let Some((account_id, name, expires)) = row else {
        return Ok(json!({"status": "expired"}));
    };
    if expires < unix_now() {
        return Ok(json!({"status": "expired"}));
    }
    let (Some(account_id), Some(name)) = (account_id, name) else {
        return Ok(json!({"status": "pending"}));
    };
    let token = random_token();
    db.execute(
        "INSERT INTO sessions (token_hash, account_id, name) VALUES (?1, ?2, ?3)",
        params![hash_text(&token), account_id, name],
    )?;
    db.execute(
        "DELETE FROM device_codes WHERE device_code = ?1",
        [device_code],
    )?;
    Ok(json!({"status": "approved", "token": token, "name": name, "account_id": account_id}))
}

fn approve_device(platform: &Platform, body: &[u8]) -> Result<Value, Error> {
    let value: Value =
        serde_json::from_slice(body).map_err(|_| Error::Message("sign-in must be JSON".into()))?;
    let user_code = value
        .get("user_code")
        .and_then(|item| item.as_str())
        .unwrap_or("")
        .trim()
        .to_ascii_uppercase();
    let name = value
        .get("name")
        .and_then(|item| item.as_str())
        .unwrap_or("")
        .trim();
    let passphrase = value
        .get("passphrase")
        .and_then(|item| item.as_str())
        .unwrap_or("");
    if !(1..=24).contains(&name.chars().count())
        || name
            .chars()
            .any(|ch| !ch.is_ascii_alphanumeric() && ch != ' ')
    {
        return Err(Error::Message(
            "use 1–24 letters, numbers, or spaces for the name".into(),
        ));
    }
    if passphrase.chars().count() < 8 {
        return Err(Error::Message(
            "use a passphrase of at least 8 characters".into(),
        ));
    }
    let db = platform.db.lock().expect("platform db");
    let found = db
        .query_row(
            "SELECT device_code, expires_at FROM device_codes WHERE user_code = ?1",
            [&user_code],
            |row| Ok((row.get::<_, String>(0)?, row.get::<_, i64>(1)?)),
        )
        .optional()?;
    let Some((device_code, expires)) = found else {
        return Err(Error::Message("that code is not waiting".into()));
    };
    if expires < unix_now() {
        return Err(Error::Message(
            "that code expired. Start sign-in on the couch again.".into(),
        ));
    }
    let account = ensure_account(&db, name, passphrase)?;
    db.execute(
        "UPDATE device_codes SET account_id = ?1, name = ?2 WHERE device_code = ?3",
        params![account, name, device_code],
    )?;
    let token = issue_session(&db, &account, name)?;
    Ok(json!({"ok": true, "name": name, "token": token, "account_id": account}))
}

fn signup(platform: &Platform, body: &[u8]) -> Result<Value, Error> {
    let (name, passphrase) = credentials(body)?;
    let db = platform.db.lock().expect("platform db");
    if account_row(&db, &name)?.is_some() {
        return Err(Error::Message("that name already has an account".into()));
    }
    let account = insert_account(&db, &name, &passphrase)?;
    let token = issue_session(&db, &account, &name)?;
    Ok(json!({"ok": true, "name": name, "token": token, "account_id": account}))
}

fn login(platform: &Platform, body: &[u8]) -> Result<Value, Error> {
    let (name, passphrase) = credentials(body)?;
    let db = platform.db.lock().expect("platform db");
    let Some((id, salt, expected)) = account_row(&db, &name)? else {
        return Err(Error::Message("that name does not have an account".into()));
    };
    if password_hash(&salt, &passphrase) != expected {
        return Err(Error::Message(
            "that passphrase does not match this name".into(),
        ));
    }
    let token = issue_session(&db, &id, &name)?;
    Ok(json!({"ok": true, "name": name, "token": token, "account_id": id}))
}

fn credentials(body: &[u8]) -> Result<(String, String), Error> {
    let value: Value =
        serde_json::from_slice(body).map_err(|_| Error::Message("sign-in must be JSON".into()))?;
    let name = value
        .get("name")
        .and_then(|item| item.as_str())
        .unwrap_or("")
        .trim()
        .to_string();
    let passphrase = value
        .get("passphrase")
        .and_then(|item| item.as_str())
        .unwrap_or("")
        .to_string();
    check_credentials(&name, &passphrase)?;
    Ok((name, passphrase))
}

fn check_credentials(name: &str, passphrase: &str) -> Result<(), Error> {
    if !(1..=24).contains(&name.chars().count())
        || name
            .chars()
            .any(|ch| !ch.is_ascii_alphanumeric() && ch != ' ')
    {
        return Err(Error::Message(
            "use 1–24 letters, numbers, or spaces for the name".into(),
        ));
    }
    if passphrase.chars().count() < 8 {
        return Err(Error::Message(
            "use a passphrase of at least 8 characters".into(),
        ));
    }
    Ok(())
}

type StoredAccount = (String, Vec<u8>, Vec<u8>);

fn account_row(db: &Connection, name: &str) -> Result<Option<StoredAccount>, Error> {
    Ok(db
        .query_row(
            "SELECT id, salt, password_hash FROM accounts WHERE name = ?1 COLLATE NOCASE",
            [name],
            |row| {
                Ok((
                    row.get::<_, String>(0)?,
                    row.get::<_, Vec<u8>>(1)?,
                    row.get::<_, Vec<u8>>(2)?,
                ))
            },
        )
        .optional()?)
}

fn insert_account(db: &Connection, name: &str, passphrase: &str) -> Result<String, Error> {
    let id = random_token();
    let salt = random_bytes(16);
    db.execute(
        "INSERT INTO accounts (id, name, salt, password_hash) VALUES (?1, ?2, ?3, ?4)",
        params![id, name, salt, password_hash(&salt, passphrase)],
    )?;
    Ok(id)
}

fn ensure_account(db: &Connection, name: &str, passphrase: &str) -> Result<String, Error> {
    if let Some((id, salt, expected)) = account_row(db, name)? {
        if password_hash(&salt, passphrase) != expected {
            return Err(Error::Message(
                "that passphrase does not match this name".into(),
            ));
        }
        return Ok(id);
    }
    insert_account(db, name, passphrase)
}

fn issue_session(db: &Connection, account_id: &str, name: &str) -> Result<String, Error> {
    let token = random_token();
    db.execute(
        "INSERT INTO sessions (token_hash, account_id, name) VALUES (?1, ?2, ?3)",
        params![hash_text(&token), account_id, name],
    )?;
    Ok(token)
}

fn library(platform: &Platform, _account: &str) -> Result<Value, Error> {
    let db = platform.db.lock().expect("platform db");
    let mut statement = db.prepare(
        "SELECT id, title, description, players, runtime, version, downloadable, color FROM games ORDER BY rowid",
    )?;
    let rows = statement.query_map([], |row| {
        Ok(json!({
            "id": row.get::<_, String>(0)?,
            "title": row.get::<_, String>(1)?,
            "description": row.get::<_, String>(2)?,
            "players": row.get::<_, String>(3)?,
            "runtime": row.get::<_, String>(4)?,
            "version": row.get::<_, String>(5)?,
            "downloadable": row.get::<_, i64>(6)? == 1,
            "color": row.get::<_, String>(7)?,
        }))
    })?;
    let games: Vec<Value> = rows.collect::<Result<_, _>>()?;
    Ok(json!({"games": games}))
}

fn package_bytes(
    platform: &Platform,
    _account: &str,
    id: &str,
) -> Result<Response<std::io::Cursor<Vec<u8>>>, Error> {
    let db = platform.db.lock().expect("platform db");
    let package: Option<(i64, String)> = db
        .query_row(
            "SELECT downloadable, package_name FROM games WHERE id = ?1",
            [id],
            |row| Ok((row.get(0)?, row.get(1)?)),
        )
        .optional()?;
    let Some((downloadable, name)) = package else {
        return Ok(json_response(
            404,
            &json!({"ok": false, "error": "that game is not in the library"}),
        ));
    };
    if downloadable != 1 || name.is_empty() {
        return Ok(json_response(
            404,
            &json!({"ok": false, "error": "that game has no package to download yet"}),
        ));
    }
    let path = platform.packages.join(&name);
    let bytes = fs::read(&path)
        .map_err(|_| Error::Message(format!("{} is not published on this server", id)))?;
    drop(db);
    let mut response = Response::from_data(bytes).with_status_code(StatusCode(200));
    if let Ok(header) = Header::from_bytes(b"Content-Type", b"application/zip") {
        response = response.with_header(header);
    }
    if let Ok(header) = Header::from_bytes(b"Cache-Control", b"no-store") {
        response = response.with_header(header);
    }
    Ok(response)
}

fn require_account(platform: &Platform, request: &Request) -> Result<String, Error> {
    let header = request
        .headers()
        .iter()
        .find(|header| header.field.equiv("Authorization"))
        .map(|header| header.value.as_str().to_string())
        .unwrap_or_default();
    let Some(token) = header.strip_prefix("Bearer ") else {
        return Err(Error::Message("sign in is required".into()));
    };
    let db = platform.db.lock().expect("platform db");
    let account = db
        .query_row(
            "SELECT account_id FROM sessions WHERE token_hash = ?1",
            [hash_text(token)],
            |row| row.get::<_, String>(0),
        )
        .optional()?;
    account.ok_or_else(|| Error::Message("sign in is required".into()))
}

fn password_hash(salt: &[u8], passphrase: &str) -> Vec<u8> {
    let mut hasher = Sha256::new();
    hasher.update(salt);
    hasher.update(passphrase.as_bytes());
    hasher.finalize().to_vec()
}

fn hash_text(value: &str) -> String {
    hex_encode(&Sha256::digest(value.as_bytes()))
}

fn random_token() -> String {
    hex_encode(&random_bytes(32))
}

fn random_code(len: usize) -> String {
    let bytes = random_bytes(len);
    bytes
        .into_iter()
        .map(|byte| CODE_ALPHABET[(byte as usize) % CODE_ALPHABET.len()] as char)
        .collect()
}

fn random_bytes(len: usize) -> Vec<u8> {
    let mut bytes = vec![0; len];
    getrandom(&mut bytes).expect("random");
    bytes
}

fn hex_encode(bytes: &[u8]) -> String {
    const HEX: &[u8] = b"0123456789abcdef";
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        out.push(HEX[(byte >> 4) as usize] as char);
        out.push(HEX[(byte & 0xf) as usize] as char);
    }
    out
}

fn unix_now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|value| value.as_secs() as i64)
        .unwrap_or(0)
}

fn json_response(status: u16, value: &Value) -> Response<std::io::Cursor<Vec<u8>>> {
    let mut response =
        Response::from_data(value.to_string().into_bytes()).with_status_code(StatusCode(status));
    if let Ok(header) = Header::from_bytes(b"Content-Type", b"application/json") {
        response = response.with_header(header);
    }
    if let Ok(header) = Header::from_bytes(b"Cache-Control", b"no-store") {
        response = response.with_header(header);
    }
    response
}

fn html_response(body: &str) -> Response<std::io::Cursor<Vec<u8>>> {
    let mut response =
        Response::from_data(body.as_bytes().to_vec()).with_status_code(StatusCode(200));
    if let Ok(header) = Header::from_bytes(b"Content-Type", b"text/html; charset=utf-8") {
        response = response.with_header(header);
    }
    response
}

fn png_response(body: &[u8]) -> Response<std::io::Cursor<Vec<u8>>> {
    let mut response = Response::from_data(body.to_vec()).with_status_code(StatusCode(200));
    if let Ok(header) = Header::from_bytes(b"Content-Type", b"image/png") {
        response = response.with_header(header);
    }
    response
}

fn css_response(body: &str) -> Response<std::io::Cursor<Vec<u8>>> {
    let mut response =
        Response::from_data(body.as_bytes().to_vec()).with_status_code(StatusCode(200));
    if let Ok(header) = Header::from_bytes(b"Content-Type", b"text/css; charset=utf-8") {
        response = response.with_header(header);
    }
    response
}

/// Block until the process is stopped. `public_url` is the link shown for sign-in.
pub fn serve_until_stopped(
    data_dir: &Path,
    packages: &Path,
    bind: &str,
    public_url: Option<&str>,
) -> Result<(), Error> {
    let origin = public_url
        .map(|url| url.trim_end_matches('/').to_string())
        .unwrap_or_else(|| {
            if bind.starts_with("http") {
                bind.to_string()
            } else {
                format!("http://{bind}")
            }
        });
    let platform = open(data_dir, packages, &origin)?;
    let server = Server::http(bind)
        .map_err(|err| Error::Message(format!("could not bind {bind}: {err}")))?;
    println!("Giga Couch platform\n{origin}\nSign-in page: {origin}/link");
    let _ = io::Write::flush(&mut io::stdout());
    let platform = Arc::new(platform);
    for mut request in server.incoming_requests() {
        let response = dispatch(Arc::clone(&platform), &mut request);
        let _ = request.respond(response);
    }
    Ok(())
}
