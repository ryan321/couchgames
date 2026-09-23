use std::{
    fs,
    io::{BufRead, BufReader},
    process::{Command, Stdio},
    time::Duration,
};

#[test]
fn web_serve_prints_a_loopback_origin_and_does_not_download_a_browser() {
    let root = tempfile::tempdir().unwrap();
    let package = root.path().join("game");
    fs::create_dir_all(package.join("web")).unwrap();
    fs::write(
        package.join("web/index.html"),
        "<!DOCTYPE html><head></head><body>blob</body>",
    )
    .unwrap();
    fs::write(
        package.join("gigacouch.json"),
        r#"{"manifest_version":1,"game_id":"gigacouch.blob-island","title":"Blob Island","version":"0.1.0","runtime":"web-1","entrypoint":"web/index.html","gigacouch_api":"1","players":{"min":1,"max":4}}"#,
    )
    .unwrap();
    let mut child = Command::new(env!("CARGO_BIN_EXE_couch"))
        .args(["--json", "--data-dir"])
        .arg(root.path().join("data"))
        .args(["web-serve", "--package"])
        .arg(&package)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .unwrap();
    let stdout = child.stdout.take().unwrap();
    let reader = BufReader::new(stdout);
    let (tx, rx) = std::sync::mpsc::channel();
    std::thread::spawn(move || {
        let mut lines = reader.lines();
        tx.send(lines.next()).ok();
    });
    let line = rx
        .recv_timeout(Duration::from_secs(10))
        .expect("web-serve did not print")
        .expect("stdout closed")
        .expect("line");
    let value: serde_json::Value = serde_json::from_str(&line).unwrap();
    assert_eq!(value["ok"], true);
    assert_eq!(value["runtime"], "web-1");
    let origin = value["origin"].as_str().unwrap();
    assert!(origin.starts_with("http://127.0.0.1:"));
    let _ = child.kill();
    let _ = child.wait();
}
