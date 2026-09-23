//! Home's client for the platform API. The page never sees the account token.

use serde_json::{Value, json};
use std::{fs, path::PathBuf, time::Duration};

pub struct AccountStore {
    pub base: String,
    pub token_path: PathBuf,
    pub install_root: PathBuf,
}

pub(crate) struct Link {
    pub base: String,
    pub token_path: PathBuf,
    pub install_root: PathBuf,
    pub pending_device: Option<String>,
    pub pending_code: Option<String>,
    pub pending_uri: Option<String>,
}

impl Link {
    pub(crate) fn from_store(store: AccountStore) -> Self {
        Self {
            base: store.base.trim_end_matches('/').to_string(),
            token_path: store.token_path,
            install_root: store.install_root,
            pending_device: None,
            pending_code: None,
            pending_uri: None,
        }
    }

    pub(crate) fn status(&mut self) -> Value {
        if let Some(token) = self.token() {
            match platform_request(&self.base, "GET", "/v1/library", None, Some(&token)) {
                Ok((200, _)) => {
                    return json!({
                        "signed_in": true,
                        "server": "ok",
                        "name": self.saved_name(),
                        "user_code": "",
                        "verification_uri": ""
                    });
                }
                Ok(_) => {
                    let _ = fs::remove_file(&self.token_path);
                }
                Err(_) => {
                    return json!({
                        "signed_in": true,
                        "server": "down",
                        "name": self.saved_name(),
                        "user_code": "",
                        "verification_uri": ""
                    });
                }
            }
        }
        if let Some(device) = self.pending_device.clone() {
            match platform_request(
                &self.base,
                "POST",
                "/v1/device/token",
                Some(json!({"device_code": device}).to_string().into_bytes()),
                None,
            ) {
                Ok((200, body)) => {
                    let value: Value = serde_json::from_slice(&body).unwrap_or(json!({}));
                    if value["status"] == "approved"
                        && let (Some(token), Some(name)) =
                            (value["token"].as_str(), value["name"].as_str())
                    {
                        let _ = fs::write(
                            &self.token_path,
                            json!({"token": token, "name": name}).to_string(),
                        );
                        self.pending_device = None;
                        self.pending_code = None;
                        self.pending_uri = None;
                        return self.status();
                    }
                }
                Ok(_) => {}
                Err(_) => {
                    return json!({
                        "signed_in": false,
                        "server": "down",
                        "name": "",
                        "user_code": self.pending_code.clone().unwrap_or_default(),
                        "verification_uri": self.pending_uri.clone().unwrap_or_default()
                    });
                }
            }
        }
        json!({
            "signed_in": false,
            "server": "ok",
            "name": "",
            "user_code": self.pending_code.clone().unwrap_or_default(),
            "verification_uri": self.pending_uri.clone().unwrap_or_default()
        })
    }

    pub(crate) fn begin(&mut self) -> Result<Value, String> {
        let (status, body) =
            platform_request(&self.base, "POST", "/v1/device", Some(b"{}".to_vec()), None)
                .map_err(|_| "The library server is not running.".to_string())?;
        if status != 200 {
            return Err("The library server rejected sign-in.".into());
        }
        let value: Value = serde_json::from_slice(&body).unwrap_or(json!({}));
        self.pending_device = value["device_code"].as_str().map(str::to_string);
        self.pending_code = value["user_code"].as_str().map(str::to_string);
        self.pending_uri = value["verification_uri"].as_str().map(str::to_string);
        Ok(value)
    }

    pub(crate) fn library(&self) -> Result<Vec<Value>, String> {
        let token = self.token().ok_or_else(|| "Sign in first.".to_string())?;
        let (status, body) = platform_request(&self.base, "GET", "/v1/library", None, Some(&token))
            .map_err(|_| "The library server is not running.".to_string())?;
        if status != 200 {
            return Err("The library server did not return the shelf.".into());
        }
        let value: Value = serde_json::from_slice(&body).unwrap_or(json!({}));
        Ok(value["games"].as_array().cloned().unwrap_or_default())
    }

    pub(crate) fn download(&self, id: &str) -> Result<(), String> {
        if id.contains('/') || id.contains("..") {
            return Err("That game is not in the library.".into());
        }
        let token = self.token().ok_or_else(|| "Sign in first.".to_string())?;
        let (status, body) = platform_request(
            &self.base,
            "GET",
            &format!("/v1/games/{id}/package"),
            None,
            Some(&token),
        )
        .map_err(|_| "The library server is not running.".to_string())?;
        if status != 200 {
            let text = String::from_utf8_lossy(&body);
            let value: Value = serde_json::from_str(&text).unwrap_or(json!({}));
            return Err(value["error"]
                .as_str()
                .unwrap_or("The download failed.")
                .to_string());
        }
        let destination = self.install_root.join(id);
        let staging = self.install_root.join(format!(".{id}.partial"));
        let _ = fs::remove_dir_all(&staging);
        fs::create_dir_all(&staging).map_err(|_| "Could not prepare the download.".to_string())?;
        couch_platform::extract_stored(&body, |name, data| {
            let path = staging.join(name);
            if let Some(parent) = path.parent() {
                fs::create_dir_all(parent)?;
            }
            fs::write(path, data)
        })
        .map_err(|_| "The package could not be unpacked.".to_string())?;
        let _ = fs::remove_dir_all(&destination);
        fs::rename(&staging, &destination)
            .map_err(|_| "Could not finish the download.".to_string())?;
        Ok(())
    }

    pub(crate) fn installed(&self, id: &str) -> bool {
        self.install_root
            .join(id)
            .join("web")
            .join("index.html")
            .is_file()
    }

    pub(crate) fn downloaded(&self) -> Vec<Value> {
        let Ok(entries) = fs::read_dir(&self.install_root) else {
            return Vec::new();
        };
        let mut games = Vec::new();
        for entry in entries.flatten() {
            let path = entry.path();
            if !path.join("web").join("index.html").is_file() {
                continue;
            }
            let id = entry.file_name().to_string_lossy().to_string();
            if id.starts_with('.') {
                continue;
            }
            let title = read_title(&path.join("gigacouch.json")).unwrap_or_else(|| id.clone());
            games.push(json!({
                "id": id,
                "title": title,
                "description": "Downloaded to this Mac.",
                "players": "On this Mac",
                "runtime": "web-1",
                "color": "#8ce8be",
                "playable": true,
                "action": "play",
                "installed": true,
                "place": "here"
            }));
        }
        games
    }

    fn token(&self) -> Option<String> {
        let text = fs::read_to_string(&self.token_path).ok()?;
        let value: Value = serde_json::from_str(&text).ok()?;
        value
            .get("token")
            .and_then(|token| token.as_str())
            .map(str::to_string)
    }

    fn saved_name(&self) -> String {
        fs::read_to_string(&self.token_path)
            .ok()
            .and_then(|text| serde_json::from_str::<Value>(&text).ok())
            .and_then(|value| {
                value
                    .get("name")
                    .and_then(|name| name.as_str())
                    .map(str::to_string)
            })
            .unwrap_or_default()
    }
}

fn read_title(path: &std::path::Path) -> Option<String> {
    let text = fs::read_to_string(path).ok()?;
    let value: Value = serde_json::from_str(&text).ok()?;
    let title = value.get("title").and_then(|title| title.as_str())?;
    if title.is_empty() {
        None
    } else {
        Some(title.to_string())
    }
}

fn platform_request(
    base: &str,
    method: &str,
    path: &str,
    body: Option<Vec<u8>>,
    token: Option<&str>,
) -> std::io::Result<(u16, Vec<u8>)> {
    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(25))
        .build()
        .map_err(std::io::Error::other)?;
    let url = format!("{base}{path}");
    let mut request = match method {
        "POST" => client.post(url),
        _ => client.get(url),
    };
    if let Some(token) = token {
        request = request.bearer_auth(token);
    }
    if let Some(body) = body {
        request = request
            .header("content-type", "application/json")
            .body(body);
    }
    let response = request.send().map_err(std::io::Error::other)?;
    let status = response.status().as_u16();
    let bytes = response.bytes().map_err(std::io::Error::other)?.to_vec();
    Ok((status, bytes))
}
