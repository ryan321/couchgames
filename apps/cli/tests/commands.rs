use serde_json::Value;
use std::{
    fs,
    path::{Path, PathBuf},
    process::Command,
};

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
        .arg("--godot")
        .arg(root.path().join("missing-godot"))
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

#[test]
fn required_godot_failure_retains_setup_guidance_in_json() {
    let root = tempfile::tempdir().unwrap();
    let output = Command::new(env!("CARGO_BIN_EXE_couch"))
        .args(["--json", "--godot"])
        .arg(root.path().join("missing"))
        .args(["doctor", "--require-godot"])
        .output()
        .unwrap();
    assert_eq!(output.status.code(), Some(1));
    let result: Value = serde_json::from_slice(&output.stdout).unwrap();
    assert_eq!(result["ok"], false);
    assert_eq!(result["error"]["code"], "GODOT_NOT_READY");
    assert_eq!(result["data"]["godot"]["status"], "unusable");
    assert!(
        !result["data"]["godot"]["instructions"]
            .as_array()
            .unwrap()
            .is_empty()
    );
}

#[cfg(unix)]
#[test]
fn explicit_engine_overrides_environment_and_unsupported_versions_fail_readiness() {
    use std::{fs, os::unix::fs::PermissionsExt};
    let root = tempfile::tempdir().unwrap();
    let old = root.path().join("old-godot");
    let current = root.path().join("current-godot");
    for (path, version) in [(&old, "4.6.1"), (&current, "4.7.2")] {
        fs::write(
            path,
            format!("#!/bin/sh\necho {version}.stable.official.abc\n"),
        )
        .unwrap();
        fs::set_permissions(path, fs::Permissions::from_mode(0o755)).unwrap();
    }
    let failed = Command::new(env!("CARGO_BIN_EXE_couch"))
        .env("COUCH_GODOT", &old)
        .args(["--json", "doctor", "--require-godot"])
        .output()
        .unwrap();
    assert_eq!(failed.status.code(), Some(1));
    let report: Value = serde_json::from_slice(&failed.stdout).unwrap();
    assert_eq!(report["data"]["godot"]["status"], "unsupported");
    let success = Command::new(env!("CARGO_BIN_EXE_couch"))
        .env("COUCH_GODOT", &old)
        .args(["--json", "--godot"])
        .arg(&current)
        .args(["doctor", "--require-godot"])
        .output()
        .unwrap();
    assert!(success.status.success());
    let report: Value = serde_json::from_slice(&success.stdout).unwrap();
    assert_eq!(report["data"]["godot"]["status"], "supported");
}

fn tiny_template(root: &Path) -> PathBuf {
    let template = root.join("template");
    fs::create_dir_all(template.join("addons/couchgames")).unwrap();
    fs::create_dir_all(template.join(".godot")).unwrap();
    fs::write(
        template.join("project.godot"),
        "[application]\nconfig/name=\"Template\"\n[autoload]\nPlatform=\"*res://addons/couchgames/platform.gd\"\n",
    )
    .unwrap();
    fs::write(
        template.join("addons/couchgames/platform.gd"),
        "# platform\n",
    )
    .unwrap();
    fs::copy(
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("../../sdk/addons/couchgames/runtime_policy.json"),
        template.join("addons/couchgames/runtime_policy.json"),
    )
    .unwrap();
    fs::write(template.join("AGENTS.md"), "# agents\n").unwrap();
    fs::write(
        template.join("couch.game.json"),
        r#"{"format":1,"id":"template","title":"Template","scene":"res://examples/little_world/world.tscn"}"#,
    )
    .unwrap();
    fs::write(template.join(".godot/cache"), "skip-me\n").unwrap();
    template
}

fn run_json(data_dir: &Path, args: &[&str]) -> (std::process::ExitStatus, Value) {
    let output = Command::new(env!("CARGO_BIN_EXE_couch"))
        .args(["--json", "--data-dir"])
        .arg(data_dir)
        .args(args)
        .output()
        .unwrap();
    let result: Value = serde_json::from_slice(&output.stdout).unwrap_or_else(|_| {
        panic!(
            "stdout: {}\nstderr: {}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        )
    });
    (output.status, result)
}

#[test]
fn init_copies_registers_and_refuses_overwrite() {
    let root = tempfile::tempdir().unwrap();
    let data = root.path().join("data");
    let parent = root.path().join("games");
    fs::create_dir_all(&parent).unwrap();
    let template = tiny_template(root.path());
    let (status, result) = run_json(
        &data,
        &[
            "init",
            "My Game",
            "--parent",
            parent.to_str().unwrap(),
            "--template",
            template.to_str().unwrap(),
        ],
    );
    assert!(status.success(), "{result}");
    let dest = parent.join("my-game");
    assert!(dest.join("project.godot").is_file());
    assert!(dest.join("addons/couchgames/platform.gd").is_file());
    assert!(dest.join("AGENTS.md").is_file());
    assert!(!dest.join(".godot").exists());
    assert_eq!(result["ok"], true);
    assert_eq!(result["data"]["id"], "my-game");
    assert_eq!(result["data"]["title"], "My Game");
    assert_eq!(result["data"]["registered"], true);
    assert_eq!(
        PathBuf::from(result["data"]["path"].as_str().unwrap()),
        fs::canonicalize(&dest).unwrap()
    );
    let game: Value =
        serde_json::from_slice(&fs::read(dest.join("couch.game.json")).unwrap()).unwrap();
    assert_eq!(game["format"], 1);
    assert_eq!(game["id"], "my-game");
    assert_eq!(game["title"], "My Game");
    assert_eq!(game["scene"], "res://examples/little_world/world.tscn");
    let project_godot = fs::read_to_string(dest.join("project.godot")).unwrap();
    assert!(project_godot.contains("config/name=\"My Game\""));
    let registry: Value =
        serde_json::from_slice(&fs::read(data.join("creator-projects.json")).unwrap()).unwrap();
    assert_eq!(registry["format"], 1);
    assert_eq!(registry["projects"][0]["id"], "my-game");
    assert_eq!(registry["projects"][0]["title"], "My Game");
    assert_eq!(
        PathBuf::from(registry["projects"][0]["path"].as_str().unwrap()),
        fs::canonicalize(&dest).unwrap()
    );
    fs::write(dest.join("marker.txt"), "keep\n").unwrap();
    let (status, retry) = run_json(
        &data,
        &[
            "init",
            "My Game",
            "--parent",
            parent.to_str().unwrap(),
            "--template",
            template.to_str().unwrap(),
        ],
    );
    assert_eq!(status.code(), Some(1));
    assert_eq!(retry["ok"], false);
    assert_eq!(retry["error"]["code"], "DESTINATION_EXISTS");
    assert_eq!(
        fs::read_to_string(dest.join("marker.txt")).unwrap(),
        "keep\n"
    );
    let registry: Value =
        serde_json::from_slice(&fs::read(data.join("creator-projects.json")).unwrap()).unwrap();
    assert_eq!(registry["projects"].as_array().unwrap().len(), 1);
}

#[test]
fn doctor_project_accepts_initialized_project() {
    let root = tempfile::tempdir().unwrap();
    let data = root.path().join("data");
    let parent = root.path().join("games");
    fs::create_dir_all(&parent).unwrap();
    let template = tiny_template(root.path());
    let (status, created) = run_json(
        &data,
        &[
            "init",
            "My Game",
            "--parent",
            parent.to_str().unwrap(),
            "--template",
            template.to_str().unwrap(),
        ],
    );
    assert!(status.success(), "{created}");
    let dest = parent.join("my-game");
    let missing_godot = root.path().join("missing-godot");
    let (status, result) = run_json(
        &data,
        &[
            "--godot",
            missing_godot.to_str().unwrap(),
            "doctor",
            "--project",
            dest.to_str().unwrap(),
        ],
    );
    assert!(status.success(), "{result}");
    assert_eq!(result["ok"], true);
    assert_eq!(result["data"]["godot_required_for_current_commands"], false);
    assert_eq!(result["data"]["project"]["supported"], true);
    let issues = result["data"]["project"]["issues"].as_array().unwrap();
    assert!(
        issues
            .iter()
            .all(|issue| issue["code"] == "COUCH_GAME_JSON_MISSING"),
        "{issues:?}"
    );
}

#[test]
fn doctor_project_reports_missing_addon() {
    let root = tempfile::tempdir().unwrap();
    let data = root.path().join("not-created");
    let project = root.path().join("bare");
    fs::create_dir_all(&project).unwrap();
    fs::write(
        project.join("project.godot"),
        "[application]\nconfig/name=\"Bare\"\n[autoload]\nPlatform=\"*res://addons/couchgames/platform.gd\"\n",
    )
    .unwrap();
    let missing_godot = root.path().join("missing-godot");
    let (status, result) = run_json(
        &data,
        &[
            "--godot",
            missing_godot.to_str().unwrap(),
            "doctor",
            "--project",
            project.to_str().unwrap(),
        ],
    );
    assert_eq!(status.code(), Some(1));
    assert_eq!(result["ok"], false);
    assert_eq!(result["data"]["project"]["supported"], false);
    assert_eq!(result["data"]["godot_required_for_current_commands"], false);
    let issues = result["data"]["project"]["issues"].as_array().unwrap();
    assert!(
        issues
            .iter()
            .any(|issue| issue["code"] == "PLATFORM_ADDON_MISSING"),
        "{issues:?}"
    );
    assert!(!data.exists());
}

#[test]
fn check_passes_initialized_project_and_publish_needs_pack() {
    let root = tempfile::tempdir().unwrap();
    let data = root.path().join("data");
    let parent = root.path().join("games");
    fs::create_dir_all(&parent).unwrap();
    let template = tiny_template(root.path());
    fs::write(
        template.join("main.tscn"),
        "[gd_scene format=3]\n\n[node name=\"Root\" type=\"Node\"]\n",
    )
    .unwrap();
    fs::write(
        template.join("couch.game.json"),
        r#"{"format":1,"id":"template","title":"Template","scene":"res://main.tscn"}"#,
    )
    .unwrap();
    fs::write(
        template.join("play.gd"),
        "func _ready():\n\tPlatform.install_lobby()\n",
    )
    .unwrap();
    let (status, created) = run_json(
        &data,
        &[
            "init",
            "Checked Game",
            "--parent",
            parent.to_str().unwrap(),
            "--template",
            template.to_str().unwrap(),
        ],
    );
    assert!(status.success(), "{created}");
    let dest = parent.join("checked-game");
    let (status, result) = run_json(&data, &["check", "--project", dest.to_str().unwrap()]);
    assert!(status.success(), "{result}");
    assert_eq!(result["ok"], true);
    assert_eq!(result["data"]["supported"], true);
    let (status, publish) = run_json(
        &data,
        &[
            "publish",
            "--project",
            dest.to_str().unwrap(),
            "--visibility",
            "private",
        ],
    );
    assert_eq!(status.code(), Some(1));
    assert_eq!(publish["error"]["code"], "NEED_PACK");
    let (status, public) = run_json(
        &data,
        &[
            "publish",
            "--project",
            dest.to_str().unwrap(),
            "--visibility",
            "public",
        ],
    );
    assert_eq!(status.code(), Some(1));
    assert_eq!(public["error"]["code"], "VISIBILITY_UNSUPPORTED");
}

#[test]
fn pack_without_godot_does_not_download_templates() {
    let root = tempfile::tempdir().unwrap();
    let data = root.path().join("data");
    let project = tiny_template(root.path());
    let (status, result) = run_json(
        &data,
        &[
            "--godot",
            root.path().join("missing-godot").to_str().unwrap(),
            "pack",
            "--project",
            project.to_str().unwrap(),
        ],
    );
    assert_eq!(status.code(), Some(1));
    assert_eq!(result["ok"], false);
    assert_eq!(result["error"]["code"], "GODOT_NOT_READY");
}
