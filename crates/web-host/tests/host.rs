use couch_web_host::{DevicePost, Host, Session, WebPackage, exchange, raw_exchange};
use serde_json::json;
use std::path::PathBuf;
use std::{
    fs,
    time::{Duration, Instant},
};

fn package(dir: &std::path::Path, max_players: u8, entry: &str) {
    fs::create_dir_all(dir.join("web")).unwrap();
    fs::write(
        dir.join("web/index.html"),
        "<!DOCTYPE html><head><title>Blob</title></head><body><script src=\"game.js\"></script></body>",
    )
    .unwrap();
    fs::write(dir.join("web/game.js"), "/* sample bytes */").unwrap();
    fs::write(dir.join("secret.txt"), "nope").unwrap();
    fs::write(
        dir.join("gigacouch.json"),
        json!({
            "manifest_version": 1,
            "game_id": "gigacouch.blob-island",
            "title": "Blob Island",
            "version": "0.1.0",
            "runtime": "web-1",
            "entrypoint": entry,
            "gigacouch_api": "1",
            "players": { "min": 1, "max": max_players }
        })
        .to_string(),
    )
    .unwrap();
}

#[test]
fn package_rejects_paths_outside_web() {
    let dir = tempfile::tempdir().unwrap();
    package(dir.path(), 16, "web/index.html");
    fs::write(
        dir.path().join("gigacouch.json"),
        fs::read_to_string(dir.path().join("gigacouch.json"))
            .unwrap()
            .replace("web/index.html", "web/../secret.txt"),
    )
    .unwrap();
    let error = WebPackage::read(dir.path()).unwrap_err();
    assert_eq!(error.code(), "INVALID_WEB_PACKAGE");
    assert!(error.to_string().contains("web/"));
}

#[test]
fn host_serves_the_game_and_hides_the_package_root() {
    let dir = tempfile::tempdir().unwrap();
    let saves = tempfile::tempdir().unwrap();
    package(dir.path(), 16, "web/index.html");
    let host = Host::start(dir.path(), saves.path()).unwrap();
    let (status, html) = exchange(host.origin(), "GET", "/", None);
    assert_eq!(status, 200);
    assert!(html.contains("/__gigacouch/input.js"));
    assert!(html.contains("/__gigacouch/bridge.js"));
    assert!(html.find("/__gigacouch/input.js").unwrap() < html.find("game.js").unwrap());
    let (status, script) = exchange(host.origin(), "GET", "/__gigacouch/bridge.js", None);
    assert_eq!(status, 200);
    assert!(script.contains("window.GigaCouch"));
    let (status, _) = exchange(host.origin(), "GET", "/../secret.txt", None);
    assert_eq!(status, 404);
    let (status, _) = exchange(host.origin(), "GET", "/%2e%2e/secret.txt", None);
    assert_eq!(status, 404);
    let (status, game) = exchange(host.origin(), "GET", "/game.js", None);
    assert_eq!(status, 200);
    assert!(game.contains("sample bytes"));
}

#[test]
fn response_carries_a_restrictive_content_policy() {
    let dir = tempfile::tempdir().unwrap();
    let saves = tempfile::tempdir().unwrap();
    package(dir.path(), 4, "web/index.html");
    let host = Host::start(dir.path(), saves.path()).unwrap();
    let text = raw_exchange(host.origin(), "GET", "/", None).to_ascii_lowercase();
    assert!(
        text.contains("content-security-policy: default-src 'self'"),
        "{text}"
    );
    assert!(text.contains("x-content-type-options: nosniff"), "{text}");
}

#[test]
fn south_joins_then_jumps_once_per_press() {
    let mut session = Session::new(16);
    let now = Instant::now();
    session.apply(post("pad-a", true, false), now);
    let snap = session.snapshot();
    assert_eq!(snap.players.len(), 1);
    assert_eq!(snap.players[0].id, 1);
    assert!(!snap.players[0].edges.jump);
    session.apply(post("pad-a", true, false), now);
    assert!(!session.snapshot().players[0].edges.jump);
    session.apply(post("pad-a", false, false), now);
    session.apply(post("pad-a", true, false), now);
    assert!(session.snapshot().players[0].edges.jump);
    assert!(!session.snapshot().players[0].edges.jump);
}

#[test]
fn the_seventeenth_pad_does_not_get_a_slot() {
    let mut session = Session::new(16);
    let devices = (0..17)
        .map(|index| {
            json!({
                "id": format!("pad-{index}"),
                "kind": "pad",
                "name": "Pad",
                "family": "generic",
                "south": true,
                "analog": false,
                "move": { "x": 0, "y": 0 }
            })
        })
        .collect::<Vec<_>>();
    session.apply(
        serde_json::from_value(json!({ "devices": devices })).unwrap(),
        Instant::now(),
    );
    assert_eq!(session.snapshot().players.len(), 16);
}

#[test]
fn holding_east_leaves_and_disconnect_frees_the_slot() {
    let mut session = Session::new(16);
    let now = Instant::now();
    session.apply(post("pad-a", true, false), now);
    session.apply(post("pad-a", false, true), now);
    assert_eq!(session.snapshot().players.len(), 1);
    session.apply(
        post("pad-a", false, true),
        now + Duration::from_millis(1249),
    );
    assert_eq!(session.snapshot().players.len(), 1);
    session.apply(
        post("pad-a", false, true),
        now + Duration::from_millis(1250),
    );
    assert!(session.snapshot().players.is_empty());

    session.apply(post("pad-a", true, false), now);
    session.apply(DevicePost { devices: vec![] }, now);
    assert!(session.snapshot().players.is_empty());
}

#[test]
fn keyboard_space_joins_without_jumping_and_backspace_leaves() {
    let mut session = Session::new(16);
    let now = Instant::now();
    session.apply(keyboard(false, true, false), now);
    let snap = session.snapshot();
    assert_eq!(snap.players.len(), 1);
    assert!(!snap.players[0].edges.jump);
    assert_eq!(snap.players[0].glyphs.jump, "Space");
    session.apply(keyboard(false, false, false), now);
    session.apply(keyboard(false, true, false), now);
    assert!(session.snapshot().players[0].edges.jump);
    session.apply(keyboard(false, false, true), now);
    assert!(session.snapshot().players.is_empty());
}

#[test]
fn analog_dead_zone_matches_the_sdk_ramp() {
    let mut session = Session::new(16);
    let now = Instant::now();
    session.apply(post("pad-a", true, false), now);
    session.apply(analog("pad-a", 0.1, 0.0), now);
    let snap = session.snapshot();
    assert_eq!(snap.players[0].movement.x, 0.0);
    session.apply(analog("pad-a", 0.6, 0.0), now);
    let snap = session.snapshot();
    assert!((snap.players[0].movement.x - 0.5).abs() < 0.001);
}

#[test]
fn saves_are_atomic_json_and_reject_a_bad_slot() {
    let dir = tempfile::tempdir().unwrap();
    let saves = tempfile::tempdir().unwrap();
    package(dir.path(), 16, "web/index.html");
    let host = Host::start(dir.path(), saves.path()).unwrap();
    let (status, body) = exchange(
        host.origin(),
        "POST",
        "/__gigacouch/v1/save/write",
        Some(br#"{"slot":"campaign","data":{"lives":3}}"#),
    );
    assert_eq!(status, 200, "{body}");
    let (status, body) = exchange(
        host.origin(),
        "POST",
        "/__gigacouch/v1/save/read",
        Some(br#"{"slot":"campaign"}"#),
    );
    assert_eq!(status, 200, "{body}");
    assert!(body.contains("\"lives\":3"));
    let (status, _) = exchange(
        host.origin(),
        "POST",
        "/__gigacouch/v1/save/read",
        Some(br#"{"slot":"missing"}"#),
    );
    assert_eq!(status, 404);
    let (status, _) = exchange(
        host.origin(),
        "POST",
        "/__gigacouch/v1/save/write",
        Some(br#"{"slot":"../nope","data":1}"#),
    );
    assert_eq!(status, 400);
    let (status, body) = exchange(host.origin(), "POST", "/__gigacouch/v1/quit", Some(b""));
    assert_eq!(status, 200, "{body}");
    let (status, body) = exchange(host.origin(), "GET", "/__gigacouch/v1/control", None);
    assert_eq!(status, 200, "{body}");
    assert!(body.contains("\"quit\":true"));
}

#[test]
fn menu_hears_confirm_and_back_without_a_separate_join_step() {
    let mut session = Session::new(16);
    let now = Instant::now();
    session.apply(post("pad-a", true, false), now);
    let snap = session.snapshot();
    assert!(snap.menu.confirm);
    assert!(!snap.menu.back);
    session.apply(post("pad-a", false, true), now);
    let snap = session.snapshot();
    assert!(snap.menu.back);
    assert_eq!(snap.players.len(), 1);
}

#[test]
fn home_signs_in_a_local_player_and_serves_blob_island() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let home = root.join("../../runtimes/web/home");
    let blob = root.join("../../runtimes/web/examples/blob-island/web");
    let dir = tempfile::tempdir().unwrap();
    let profiles = dir.path().join("home-profiles.json");
    let host = Host::start_home(&home, &[("blob-island", blob.as_path())], &profiles).unwrap();
    let (status, html) = exchange(host.origin(), "GET", "/", None);
    assert_eq!(status, 200, "{html}");
    assert!(html.contains("home.js"));
    let (status, script) = exchange(host.origin(), "GET", "/home.js", None);
    assert_eq!(status, 200, "{script}");
    assert!(script.contains("Who's on the couch"));
    let (status, body) = exchange(host.origin(), "GET", "/__gigacouch/v1/home", None);
    assert_eq!(status, 200, "{body}");
    assert!(body.contains("Blob Island"));
    assert!(body.contains("Family"));
    let (status, _) = exchange(
        host.origin(),
        "POST",
        "/__gigacouch/v1/home/add",
        Some(br#"{"name":"Ada"}"#),
    );
    assert_eq!(status, 200);
    let (status, body) = exchange(host.origin(), "GET", "/__gigacouch/v1/home", None);
    assert_eq!(status, 200, "{body}");
    assert!(body.contains("Ada"));
    let (status, game) = exchange(host.origin(), "GET", "/play/blob-island/game.js", None);
    assert_eq!(status, 200, "{game}");
    assert!(game.contains("canvas"));
    let (status, _) = exchange(
        host.origin(),
        "GET",
        "/play/blob-island/../../catalog.json",
        None,
    );
    assert_eq!(status, 404);
}

#[test]
fn home_asks_for_a_godot_window_and_keeps_the_reply() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let home = root.join("../../runtimes/web/home");
    let dir = tempfile::tempdir().unwrap();
    let profiles = dir.path().join("home-profiles.json");
    let (tx, rx) = std::sync::mpsc::channel();
    let games = serde_json::json!([{
        "id": "little-world",
        "title": "Little World",
        "runtime": "godot",
        "playable": true,
        "players": "1–16",
        "description": "A tiny island.",
        "color": "#a5cfa1"
    }]);
    let host = Host::start_home_with(&home, &[], &profiles, Some(games), Some(tx), None).unwrap();
    let origin = host.origin().to_string();
    std::thread::spawn(move || {
        let request = rx.recv_timeout(Duration::from_secs(3)).unwrap();
        assert_eq!(request.id, "little-world");
        assert_eq!(request.profile, "family");
        request.reply.send(Ok("Little World".into())).unwrap();
    });
    let (status, body) = exchange(
        &origin,
        "POST",
        "/__gigacouch/v1/home/play",
        Some(br#"{"id":"little-world"}"#),
    );
    assert_eq!(status, 200, "{body}");
    assert!(body.contains("own window"), "{body}");
}

#[test]
fn home_downloads_a_signed_in_package_and_serves_it() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let home = root.join("../../runtimes/web/home");
    let source = root.join("../../runtimes/web/examples/blob-island");
    let dir = tempfile::tempdir().unwrap();
    let packages = dir.path().join("packages");
    couch_platform::publish_blob_island(&packages, &source).unwrap();
    let platform = couch_platform::open(dir.path(), &packages, "http://127.0.0.1:9").unwrap();
    let server = tiny_http::Server::http("127.0.0.1:0").unwrap();
    let port = server.server_addr().to_ip().unwrap().port();
    let origin = format!("http://127.0.0.1:{port}");
    std::thread::spawn(move || {
        for mut request in server.incoming_requests() {
            let response = couch_platform::handle_request(&platform, &mut request);
            let _ = request.respond(response);
        }
    });
    let started: serde_json::Value =
        serde_json::from_str(&post_raw(&origin, "/v1/device", "{}")).unwrap();
    let user_code = started["user_code"].as_str().unwrap();
    let device = started["device_code"].as_str().unwrap();
    post_raw(
        &origin,
        "/v1/link",
        &format!(
            "{{\"user_code\":\"{user_code}\",\"name\":\"Ada\",\"passphrase\":\"couch-night\"}}"
        ),
    );
    let approved: serde_json::Value = serde_json::from_str(&post_raw(
        &origin,
        "/v1/device/token",
        &format!("{{\"device_code\":\"{device}\"}}"),
    ))
    .unwrap();
    let token = approved["token"].as_str().unwrap();
    let account_path = dir.path().join("account.json");
    std::fs::write(
        &account_path,
        format!("{{\"token\":\"{token}\",\"name\":\"Ada\"}}"),
    )
    .unwrap();
    let host = Host::start_home_with(
        &home,
        &[],
        &dir.path().join("profiles.json"),
        None,
        None,
        Some(couch_web_host::AccountStore {
            base: origin,
            token_path: account_path,
            install_root: dir.path().join("installed"),
        }),
    )
    .unwrap();
    let (status, body) = exchange(
        host.origin(),
        "POST",
        "/__gigacouch/v1/library/download",
        Some(br#"{"id":"blob-island"}"#),
    );
    assert_eq!(status, 200, "{body}");
    let (status, home_body) = exchange(host.origin(), "GET", "/__gigacouch/v1/home", None);
    assert_eq!(status, 200, "{home_body}");
    let listed: serde_json::Value = serde_json::from_str(&home_body).unwrap();
    let cards = listed["games"].as_array().unwrap();
    let blob = cards
        .iter()
        .find(|game| game["id"] == "blob-island")
        .unwrap();
    assert_eq!(blob["place"], "here", "{blob}");
    assert_eq!(blob["installed"], true, "{blob}");
    let waiting = cards
        .iter()
        .find(|game| game["id"] == "little-world")
        .unwrap();
    assert_eq!(waiting["place"], "library", "{waiting}");
    let (status, game) = exchange(host.origin(), "GET", "/play/blob-island/game.js", None);
    assert_eq!(status, 200, "{game}");
    assert!(game.contains("canvas"), "{game}");
}

#[test]
fn downloaded_game_stays_playable_when_the_library_server_is_down() {
    let root = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let home = root.join("../../runtimes/web/home");
    let dir = tempfile::tempdir().unwrap();
    let install = dir.path().join("installed").join("blob-island");
    std::fs::create_dir_all(install.join("web")).unwrap();
    std::fs::write(install.join("gigacouch.json"), r#"{"title":"Blob Island"}"#).unwrap();
    std::fs::write(
        install.join("web/index.html"),
        "<!DOCTYPE html><head></head><body></body>",
    )
    .unwrap();
    std::fs::write(install.join("web/game.js"), "/* downloaded canvas */").unwrap();
    let account_path = dir.path().join("account.json");
    std::fs::write(&account_path, r#"{"token":"saved-token","name":"Ada"}"#).unwrap();
    let host = Host::start_home_with(
        &home,
        &[],
        &dir.path().join("profiles.json"),
        Some(serde_json::json!([])),
        None,
        Some(couch_web_host::AccountStore {
            base: "http://127.0.0.1:9".into(),
            token_path: account_path.clone(),
            install_root: dir.path().join("installed"),
        }),
    )
    .unwrap();
    let (status, body) = exchange(host.origin(), "GET", "/__gigacouch/v1/home", None);
    assert_eq!(status, 200, "{body}");
    let listed: serde_json::Value = serde_json::from_str(&body).unwrap();
    assert_eq!(listed["account"]["server"], "down");
    assert_eq!(listed["account"]["name"], "Ada");
    let cards = listed["games"].as_array().unwrap();
    let blob = cards
        .iter()
        .find(|game| game["id"] == "blob-island")
        .unwrap();
    assert_eq!(blob["place"], "here", "{blob}");
    assert_eq!(blob["installed"], true, "{blob}");
    assert_eq!(blob["playable"], true, "{blob}");
    let (status, game) = exchange(host.origin(), "GET", "/play/blob-island/game.js", None);
    assert_eq!(status, 200, "{game}");
    assert!(game.contains("downloaded canvas"), "{game}");
    assert!(account_path.is_file());
}

fn post_raw(origin: &str, path: &str, body: &str) -> String {
    let (status, text) = exchange(origin, "POST", path, Some(body.as_bytes()));
    assert!(status == 200 || status == 400, "{status} {text}");
    text
}

fn post(id: &str, south: bool, east: bool) -> DevicePost {
    serde_json::from_value(json!({
        "devices": [{
            "id": id,
            "kind": "pad",
            "name": "Pad",
            "family": "xbox",
            "south": south,
            "east": east,
            "analog": false,
            "move": { "x": 0, "y": 0 }
        }]
    }))
    .unwrap()
}

fn analog(id: &str, x: f32, y: f32) -> DevicePost {
    serde_json::from_value(json!({
        "devices": [{
            "id": id,
            "kind": "pad",
            "name": "Pad",
            "family": "xbox",
            "south": false,
            "east": false,
            "analog": true,
            "move": { "x": x, "y": y }
        }]
    }))
    .unwrap()
}

fn keyboard(south: bool, jump: bool, leave: bool) -> DevicePost {
    serde_json::from_value(json!({
        "devices": [{
            "id": "keyboard",
            "kind": "keyboard",
            "name": "Keyboard",
            "family": "keyboard",
            "south": south,
            "jump": jump,
            "leave": leave,
            "analog": false,
            "move": { "x": 1, "y": 0 }
        }]
    }))
    .unwrap()
}
