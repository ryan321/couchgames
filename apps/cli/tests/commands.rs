use serde_json::Value;
use std::{path::PathBuf, process::Command};

fn fixture() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../tests/fixtures/package/release.json")
}

#[test]
fn doctor_is_read_only_and_confirms_no_engine_downloads() {
    let root = tempfile::tempdir().unwrap();
    let data = root.path().join("not-created");
    let output = Command::new(env!("CARGO_BIN_EXE_couch"))
        .args(["--json", "--data-dir"])
        .arg(&data)
        .arg("doctor")
        .output()
        .unwrap();
    assert!(output.status.success());
    let result: Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(result["data"]["automatic_downloads"], false);
    assert_eq!(result["data"]["godot_required_for_current_commands"], false);
    assert!(!data.exists());
}

#[test]
fn validates_installs_retries_and_lists_from_separate_processes() {
    let data = tempfile::tempdir().unwrap();
    let run = |args: &[&str]| {
        let output = Command::new(env!("CARGO_BIN_EXE_couch"))
            .args(["--json", "--data-dir"])
            .arg(data.path())
            .args(args)
            .output()
            .unwrap();
        assert!(
            output.status.success(),
            "{}",
            String::from_utf8_lossy(&output.stdout)
        );
        serde_json::from_slice::<Value>(&output.stdout).unwrap()
    };
    let manifest = fixture();
    let path = manifest.to_str().unwrap();
    assert_eq!(run(&["validate", path])["data"]["artifacts_verified"], 3);
    assert_eq!(
        run(&["install", path, "--target", "macos-aarch64"])["data"]["already_installed"],
        false
    );
    assert_eq!(
        run(&["install", path, "--target", "macos-aarch64"])["data"]["already_installed"],
        true
    );
    assert_eq!(
        run(&["library"])["data"]["releases"]
            .as_array()
            .unwrap()
            .len(),
        1
    );
    assert!(!data.path().join("runtimes").exists());
}

#[test]
fn operational_errors_have_stable_codes_and_nonzero_exit() {
    let root = tempfile::tempdir().unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_couch"))
        .args(["--json", "validate"])
        .arg(root.path().join("missing.json"))
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(1));
    let result: Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(result["ok"], false);
    assert_eq!(result["error"]["code"], "PACKAGE_IO");
}
