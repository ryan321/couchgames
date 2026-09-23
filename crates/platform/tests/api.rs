use couch_platform::{extract_stored, open, publish_blob_island, write_stored};
use serde_json::json;
use std::{
    io::{Read, Write},
    net::TcpStream,
    path::PathBuf,
    thread,
    time::Duration,
};

#[test]
fn landing_page_and_signup_open_the_library() {
    let dir = tempfile::tempdir().unwrap();
    let packages = dir.path().join("packages");
    let platform = open(dir.path(), &packages, "http://127.0.0.1:9").unwrap();
    let server = tiny_http::Server::http("127.0.0.1:0").unwrap();
    let port = server.server_addr().to_ip().unwrap().port();
    let origin = format!("http://127.0.0.1:{port}");
    thread::spawn(move || {
        for mut request in server.incoming_requests() {
            let response = couch_platform::handle_request(&platform, &mut request);
            let _ = request.respond(response);
        }
    });
    let page = get(&origin, "/", None);
    assert!(page.contains("couch game"), "{page}");
    let account = get(&origin, "/account", None);
    assert!(account.contains("Create account"), "{account}");
    let created = post(
        &origin,
        "/v1/signup",
        &json!({"name": "Ada", "passphrase": "couch-night"}).to_string(),
        None,
    );
    assert_eq!(created["ok"], true, "{created}");
    let token = created["token"].as_str().unwrap();
    let library = get(&origin, "/v1/library", Some(token));
    assert!(library.contains("Blob Island"), "{library}");
}

#[test]
fn stored_zip_round_trips() {
    let bytes = write_stored(&[
        ("gigacouch.json", br#"{"id":"blob"}"#),
        ("web/game.js", b"play"),
    ])
    .unwrap();
    let mut names = Vec::new();
    extract_stored(&bytes, |name, data| {
        names.push((name.to_string(), data.to_vec()));
        Ok(())
    })
    .unwrap();
    assert_eq!(names[0].0, "gigacouch.json");
    assert_eq!(names[1].1, b"play");
}

#[test]
fn device_code_approves_and_download_requires_that_account() {
    let dir = tempfile::tempdir().unwrap();
    let packages = dir.path().join("packages");
    let source =
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../runtimes/web/examples/blob-island");
    publish_blob_island(&packages, &source).unwrap();
    let platform = open(dir.path(), &packages, "http://127.0.0.1:9").unwrap();
    let server = tiny_http::Server::http("127.0.0.1:0").unwrap();
    let port = server.server_addr().to_ip().unwrap().port();
    let origin = format!("http://127.0.0.1:{port}");
    thread::spawn(move || {
        for mut request in server.incoming_requests() {
            let response = couch_platform::handle_request(&platform, &mut request);
            let _ = request.respond(response);
        }
    });
    let started = post(&origin, "/v1/device", "{}", None);
    let device = started["device_code"].as_str().unwrap().to_string();
    let user_code = started["user_code"].as_str().unwrap();
    let pending = post(
        &origin,
        "/v1/device/token",
        &json!({"device_code": device}).to_string(),
        None,
    );
    assert_eq!(pending["status"], "pending");
    let approved = post(
        &origin,
        "/v1/link",
        &json!({"user_code": user_code, "name": "Ada", "passphrase": "couch-night"}).to_string(),
        None,
    );
    assert_eq!(approved["ok"], true, "{approved}");
    let token_body = post(
        &origin,
        "/v1/device/token",
        &json!({"device_code": device}).to_string(),
        None,
    );
    assert_eq!(token_body["status"], "approved", "{token_body}");
    let token = token_body["token"].as_str().unwrap();
    let denied = get(&origin, "/v1/library", None);
    assert!(denied.contains("sign in"));
    let library = get(&origin, "/v1/library", Some(token));
    assert!(library.contains("Blob Island"), "{library}");
    assert!(library.contains("Little World"), "{library}");
    let package = get_bytes(&origin, "/v1/games/blob-island/package", Some(token));
    assert!(package.windows(4).any(|mark| mark == b"PK\x03\x04"));
    let missing = get(&origin, "/v1/games/little-world/package", Some(token));
    assert!(missing.contains("no package"));
}

fn post(origin: &str, path: &str, body: &str, token: Option<&str>) -> serde_json::Value {
    let text = request(origin, "POST", path, Some(body.as_bytes()), token);
    serde_json::from_str(&text).unwrap_or(json!({"raw": text}))
}

fn get(origin: &str, path: &str, token: Option<&str>) -> String {
    request(origin, "GET", path, None, token)
}

fn get_bytes(origin: &str, path: &str, token: Option<&str>) -> Vec<u8> {
    let addr = origin.trim_start_matches("http://");
    let mut stream = TcpStream::connect(addr).unwrap();
    stream
        .set_read_timeout(Some(Duration::from_secs(2)))
        .unwrap();
    let mut head = format!("GET {path} HTTP/1.0\r\nHost: {addr}\r\nConnection: close\r\n");
    if let Some(token) = token {
        head.push_str(&format!("Authorization: Bearer {token}\r\n"));
    }
    head.push_str("\r\n");
    stream.write_all(head.as_bytes()).unwrap();
    let mut bytes = Vec::new();
    stream.read_to_end(&mut bytes).unwrap();
    let split = bytes
        .windows(4)
        .position(|mark| mark == b"\r\n\r\n")
        .unwrap()
        + 4;
    bytes[split..].to_vec()
}

fn request(
    origin: &str,
    method: &str,
    path: &str,
    body: Option<&[u8]>,
    token: Option<&str>,
) -> String {
    let addr = origin.trim_start_matches("http://");
    let mut stream = TcpStream::connect(addr).unwrap();
    stream
        .set_read_timeout(Some(Duration::from_secs(2)))
        .unwrap();
    let length = body.map(|bytes| bytes.len()).unwrap_or(0);
    let mut head = format!(
        "{method} {path} HTTP/1.0\r\nHost: {addr}\r\nConnection: close\r\nContent-Length: {length}\r\n"
    );
    if body.is_some() {
        head.push_str("Content-Type: application/json\r\n");
    }
    if let Some(token) = token {
        head.push_str(&format!("Authorization: Bearer {token}\r\n"));
    }
    head.push_str("\r\n");
    stream.write_all(head.as_bytes()).unwrap();
    if let Some(body) = body {
        stream.write_all(body).unwrap();
    }
    let mut bytes = Vec::new();
    stream.read_to_end(&mut bytes).unwrap();
    let text = String::from_utf8_lossy(&bytes);
    text.split_once("\r\n\r\n")
        .map(|(_, body)| body.to_string())
        .unwrap_or_default()
}
