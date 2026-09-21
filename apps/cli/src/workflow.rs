//! Creator check / pack / run / local private drop. Never downloads Godot or templates.

use crate::project::{self, CliError, Issue};
use anyhow::Result;
use couch_manifests::Target;
use serde_json::{Value, json};
use sha2::{Digest, Sha256};
use std::{
    fs::{self, File},
    io::Write,
    path::Path,
    process::Command,
};

pub fn check(path: &Path) -> Result<Value, CliError> {
    let report = project::inspect(path)?;
    let mut issues = report.issues;
    extra_checks(&report.path, &mut issues);
    let fatal = issues.iter().any(|issue| !is_warning(issue.code));
    Ok(json!({
        "path": report.path.display().to_string(),
        "supported": report.supported && !fatal,
        "issues": issues.iter().map(|issue| json!({
            "code": issue.code,
            "message": issue.message,
            "level": if is_warning(issue.code) { "warning" } else { "error" }
        })).collect::<Vec<_>>(),
    }))
}

fn is_warning(code: &str) -> bool {
    matches!(
        code,
        "COUCH_GAME_JSON_MISSING"
            | "AGENTS_MD_MISSING"
            | "ASSET_GUIDE_MISSING"
            | "TV_STRETCH_UNSET"
            | "LOBBY_UNUSED"
    )
}

fn extra_checks(root: &Path, issues: &mut Vec<Issue>) {
    if !root.join("AGENTS.md").is_file() {
        issues.push(Issue {
            code: "AGENTS_MD_MISSING",
            message: "AGENTS.md is missing; agents will not know the Platform API".into(),
        });
    }
    if !root.join("docs/asset_source_guide.md").is_file() {
        issues.push(Issue {
            code: "ASSET_GUIDE_MISSING",
            message: "docs/asset_source_guide.md is missing".into(),
        });
    }
    let godot = root.join("project.godot");
    if let Ok(text) = fs::read_to_string(&godot)
        && !text.contains("stretch/aspect")
    {
        issues.push(Issue {
            code: "TV_STRETCH_UNSET",
            message: "project.godot should set window/stretch/aspect to keep for TV".into(),
        });
    }
    let game = root.join("couch.game.json");
    if let Ok(text) = fs::read_to_string(&game)
        && let Ok(value) = serde_json::from_str::<Value>(&text)
        && let Some(scene) = value.get("scene").and_then(Value::as_str)
    {
        let file = root.join(scene.trim_start_matches("res://"));
        if !file.is_file() {
            issues.push(Issue {
                code: "ENTRY_SCENE_MISSING",
                message: format!("Entry scene {} is not a file in this project", scene),
            });
        }
    }
    let uses_lobby = fs::read_to_string(root.join("project.godot"))
        .ok()
        .and_then(|_| find_install_lobby(root));
    if uses_lobby != Some(true) && root.join("addons/couchgames/lobby.gd").is_file() {
        issues.push(Issue {
            code: "LOBBY_UNUSED",
            message: "Call Platform.install_lobby() so players can ready up on the couch".into(),
        });
    }
}

fn find_install_lobby(root: &Path) -> Option<bool> {
    let mut found = false;
    visit(root, &mut found).ok()?;
    Some(found)
}

fn visit(dir: &Path, found: &mut bool) -> Result<(), CliError> {
    let entries = match fs::read_dir(dir) {
        Ok(entries) => entries,
        Err(_) => return Ok(()),
    };
    for entry in entries.flatten() {
        let path = entry.path();
        let name = path.file_name().and_then(|n| n.to_str()).unwrap_or("");
        if name.starts_with('.') || name == "addons" {
            continue;
        }
        if path.is_dir() {
            visit(&path, found)?;
        } else if path.extension().and_then(|e| e.to_str()) == Some("gd")
            && let Ok(text) = fs::read_to_string(&path)
            && text.contains("install_lobby")
        {
            *found = true;
        }
    }
    Ok(())
}

pub fn pack(project: &Path, godot: &Path, target: Target) -> Result<Value, CliError> {
    let report = project::inspect(project)?;
    if !report.supported {
        return Err(CliError::new(
            "PROJECT_UNSUPPORTED",
            "couch check must pass before packing. Fix addons/couchgames and Platform autoload.",
        ));
    }
    let root = report.path;
    let dist = root.join("dist");
    fs::create_dir_all(&dist).map_err(|error| io(&dist, error))?;
    write_export_preset(&root)?;
    let pck_name = format!("{}-{}.pck", slug_from_root(&root), target);
    let pck = dist.join(&pck_name);
    let output = Command::new(godot)
        .args(["--headless", "--path"])
        .arg(&root)
        .args(["--export-pack", "GigaCouchPack"])
        .arg(&pck)
        .output()
        .map_err(|error| {
            CliError::new(
                "GODOT_PACK_FAILED",
                format!("could not start Godot to pack: {error}"),
            )
        })?;
    let log = format!(
        "{}{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
    if !output.status.success() || !pck.is_file() {
        let code = if log.to_lowercase().contains("template") {
            "PACK_TEMPLATES_MISSING"
        } else {
            "GODOT_PACK_FAILED"
        };
        return Err(CliError::new(
            code,
            format!(
                "Godot could not write {}. Export templates are not downloaded by this CLI. Install Godot export templates yourself if you need a PCK.\n{log}",
                pck.display()
            ),
        ));
    }
    let bytes = fs::read(&pck).map_err(|error| io(&pck, error))?;
    if bytes.len() < 64 || !bytes.starts_with(b"GDPC") {
        return Err(CliError::new(
            "PACK_NOT_PLAYABLE",
            format!("{} is not a Godot PCK (missing GDPC header)", pck.display()),
        ));
    }
    let sha = hex(Sha256::digest(&bytes));
    let game = read_game(&root);
    let manifest = json!({
        "manifest_version": 1,
        "game_id": game.get("id").and_then(Value::as_str).unwrap_or("game"),
        "title": game.get("title").and_then(Value::as_str).unwrap_or("Game"),
        "release_id": format!("dev-{}", unix_stamp()),
        "version": "0.1.0",
        "runtime": "1",
        "sdk": "0.1.0",
        "players": { "min": 1, "max": 16 },
        "artifacts": [{
            "os": match target {
                Target::WindowsX86_64 => "windows",
                _ => "macos",
            },
            "architecture": match target {
                Target::MacosX86_64 | Target::WindowsX86_64 => "x86_64",
                Target::MacosAarch64 => "aarch64",
            },
            "renderer": "gl_compatibility",
            "file": pck_name,
            "size_bytes": bytes.len() as u64,
            "sha256": sha
        }]
    });
    let manifest_path = dist.join("release.json");
    write_atomic(
        &manifest_path,
        &serde_json::to_vec_pretty(&manifest).unwrap(),
    )?;
    write_lock(&root)?;
    Ok(json!({
        "pck": pck.display().to_string(),
        "manifest": manifest_path.display().to_string(),
        "bytes": bytes.len(),
        "playable": true,
        "downloaded_templates": false
    }))
}

pub fn run_project(project: &Path, godot: &Path, data_dir: &Path) -> Result<Value, CliError> {
    let report = project::inspect(project)?;
    if !report.supported {
        return Err(CliError::new(
            "PROJECT_UNSUPPORTED",
            "Project is not a supported Giga Couch game. Run couch check --project.",
        ));
    }
    let root = report.path;
    let game = read_game(&root);
    let scene = game
        .get("scene")
        .and_then(Value::as_str)
        .unwrap_or("res://examples/little_world/world.tscn");
    let id = game.get("id").and_then(Value::as_str).unwrap_or("game");
    let saves = data_dir.join("saves").join("family").join(id);
    fs::create_dir_all(&saves).map_err(|error| io(&saves, error))?;
    let status = Command::new(godot)
        .arg("--path")
        .arg(&root)
        .arg(scene)
        .env("COUCH_SAVE_DIR", &saves)
        .env("COUCH_PROFILE", "family")
        .status()
        .map_err(|error| {
            CliError::new(
                "GODOT_RUN_FAILED",
                format!("could not start Godot: {error}"),
            )
        })?;
    Ok(json!({
        "path": root.display().to_string(),
        "exit_code": status.code().unwrap_or(1),
        "save_dir": saves.display().to_string()
    }))
}

pub fn publish_local(project: &Path, visibility: &str, data_dir: &Path) -> Result<Value, CliError> {
    if visibility != "private" {
        return Err(CliError::new(
            "VISIBILITY_UNSUPPORTED",
            "Only --visibility private is available. There is no public catalog yet.",
        ));
    }
    let root = project::inspect(project)?.path;
    let manifest = root.join("dist/release.json");
    if !manifest.is_file() {
        return Err(CliError::new(
            "NEED_PACK",
            "Run couch pack --project first. Nothing was uploaded.",
        ));
    }
    let parsed: Value =
        serde_json::from_str(&fs::read_to_string(&manifest).map_err(|error| io(&manifest, error))?)
            .map_err(|error| {
                CliError::new(
                    "NEED_PACK",
                    format!("dist/release.json is not valid JSON: {error}"),
                )
            })?;
    let game_id = parsed
        .get("game_id")
        .and_then(Value::as_str)
        .unwrap_or("game");
    let release_id = parsed
        .get("release_id")
        .and_then(Value::as_str)
        .unwrap_or("dev");
    let dest = data_dir
        .join("share")
        .join("outgoing")
        .join(game_id)
        .join(release_id);
    if dest.exists() {
        fs::remove_dir_all(&dest).map_err(|error| io(&dest, error))?;
    }
    copy_dir(&root.join("dist"), &dest)?;
    Ok(json!({
        "visibility": "private",
        "remote": false,
        "path": dest.display().to_string(),
        "message": "Copied the pack to a local private drop. No account upload exists yet."
    }))
}

fn write_export_preset(root: &Path) -> Result<(), CliError> {
    let path = root.join("export_presets.cfg");
    let body = r#"
[preset.0]

name="GigaCouchPack"
platform="macOS"
runnable=false
dedicated_server=false
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="dist/game.pck"
encryption_include_filters=""
encryption_exclude_filters=""
encrypt_pck=false
encrypt_directory=false
script_export_mode=2
"#;
    if !path.is_file() {
        write_atomic(&path, body.as_bytes())?;
    }
    Ok(())
}

fn write_lock(root: &Path) -> Result<(), CliError> {
    let policy = root.join("addons/couchgames/runtime_policy.json");
    let godot = if policy.is_file() {
        fs::read_to_string(&policy).unwrap_or_default()
    } else {
        String::new()
    };
    let version = serde_json::from_str::<Value>(&godot)
        .ok()
        .and_then(|value| {
            value
                .get("godot_version")
                .and_then(Value::as_str)
                .map(str::to_string)
        })
        .unwrap_or_else(|| "4.7.2".into());
    let lock = json!({
        "sdk": "addons/couchgames",
        "godot": version,
        "template": "pinned-in-project"
    });
    write_atomic(
        &root.join("couch.lock"),
        &serde_json::to_vec_pretty(&lock).unwrap(),
    )
}

fn read_game(root: &Path) -> Value {
    fs::read_to_string(root.join("couch.game.json"))
        .ok()
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_else(|| json!({}))
}

fn slug_from_root(root: &Path) -> String {
    root.file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("game")
        .chars()
        .map(|ch| {
            if ch.is_ascii_alphanumeric() {
                ch.to_ascii_lowercase()
            } else {
                '-'
            }
        })
        .collect()
}

fn unix_stamp() -> u64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs())
        .unwrap_or(0)
}

fn hex(bytes: impl AsRef<[u8]>) -> String {
    bytes.as_ref().iter().map(|b| format!("{b:02x}")).collect()
}

fn write_atomic(path: &Path, bytes: &[u8]) -> Result<(), CliError> {
    let tmp = path.with_extension("tmp");
    File::create(&tmp)
        .and_then(|mut file| file.write_all(bytes))
        .map_err(|error| io(path, error))?;
    fs::rename(&tmp, path).map_err(|error| io(path, error))
}

fn copy_dir(src: &Path, dest: &Path) -> Result<(), CliError> {
    fs::create_dir_all(dest).map_err(|error| io(dest, error))?;
    for entry in fs::read_dir(src).map_err(|error| io(src, error))? {
        let entry = entry.map_err(|error| io(src, error))?;
        let from = entry.path();
        let to = dest.join(entry.file_name());
        if from.is_dir() {
            copy_dir(&from, &to)?;
        } else {
            fs::copy(&from, &to).map_err(|error| io(&from, error))?;
        }
    }
    Ok(())
}

fn io(path: &Path, error: std::io::Error) -> CliError {
    CliError::new("PACKAGE_IO", format!("{}: {error}", path.display()))
}
