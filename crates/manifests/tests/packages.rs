use couch_manifests::{Error, MAX_MANIFEST_BYTES, Manifest};
use serde_json::{Value, json};
use std::{fs, path::PathBuf};

fn fixture() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../tests/fixtures/package/release.json")
}

fn valid_json() -> Value {
    serde_json::from_slice(&fs::read(fixture()).unwrap()).unwrap()
}

fn rejects(value: Value) {
    if let Ok(manifest) = serde_json::from_value::<Manifest>(value) {
        assert!(manifest.validate().is_err());
    }
}

#[test]
fn validates_fixture_bytes_for_every_target() {
    let path = fixture();
    Manifest::read(&path)
        .unwrap()
        .verify_all(path.parent().unwrap())
        .unwrap();
}

#[test]
fn rejects_path_traversal_and_windows_device_names() {
    for name in [
        "../game.pck",
        "a/b.pck",
        "a\\b.pck",
        "/game.pck",
        "C:game.pck",
        "con.pck",
        "aux.extra.pck",
        "com1.pck",
        "lpt9.pck",
        "game .pck",
        "game..pck",
    ] {
        let mut value = valid_json();
        value["artifacts"][0]["file"] = json!(name);
        rejects(value);
    }
}

#[test]
fn rejects_unsafe_game_and_release_identifiers() {
    for field in ["game_id", "release_id"] {
        for id in ["", "..", "../outside", "a/b", "a\\b", "A", "name.", "name "] {
            let mut value = valid_json();
            value[field] = json!(id);
            rejects(value);
        }
    }
}

#[test]
fn rejects_unknown_fields_and_invalid_versions() {
    let mut value = valid_json();
    value["unrecognized"] = json!(true);
    rejects(value);
    for (field, bad) in [
        ("manifest_version", json!(2)),
        ("version", json!("1")),
        ("sdk", json!("1.0.0-01")),
        ("runtime", json!("0")),
        ("title", json!("\n")),
    ] {
        let mut value = valid_json();
        value[field] = bad;
        rejects(value);
    }
}

#[test]
fn rejects_invalid_players_and_duplicate_targets() {
    for players in [
        json!({"min": 0, "max": 4}),
        json!({"min": 4, "max": 2}),
        json!({"min": 1, "max": 5}),
    ] {
        let mut value = valid_json();
        value["players"] = players;
        rejects(value);
    }
    let mut value = valid_json();
    let duplicate = value["artifacts"][0].clone();
    value["artifacts"] = json!([duplicate.clone(), duplicate]);
    rejects(value);
}

#[test]
fn rejects_unsupported_targets_renderer_and_unbounded_sizes() {
    for (key, bad) in [
        ("os", json!("linux")),
        ("renderer", json!("forward_plus")),
        ("size_bytes", json!(0)),
        ("size_bytes", json!(4294967297_u64)),
        ("sha256", json!("abc")),
    ] {
        let mut value = valid_json();
        value["artifacts"][0][key] = bad;
        rejects(value);
    }
    let mut value = valid_json();
    value["artifacts"][0]["os"] = json!("windows");
    value["artifacts"][0]["architecture"] = json!("aarch64");
    rejects(value);
}

#[test]
fn rejects_oversized_manifest_before_parsing() {
    let dir = tempfile::tempdir().unwrap();
    let path = dir.path().join("release.json");
    fs::write(&path, vec![b' '; MAX_MANIFEST_BYTES as usize + 1]).unwrap();
    assert!(matches!(Manifest::read(&path), Err(Error::Invalid(_))));
}

#[test]
fn detects_same_length_corruption_and_truncation() {
    let dir = tempfile::tempdir().unwrap();
    let mut manifest = Manifest::read(&fixture()).unwrap();
    manifest.artifacts.truncate(1);
    let artifact = &manifest.artifacts[0];
    fs::write(
        dir.path().join(&artifact.file),
        vec![0; artifact.size_bytes as usize],
    )
    .unwrap();
    assert!(matches!(
        manifest.verify_all(dir.path()),
        Err(Error::Hash(_))
    ));
    fs::write(dir.path().join(&artifact.file), b"x").unwrap();
    assert!(matches!(
        manifest.verify_all(dir.path()),
        Err(Error::Size { .. })
    ));
}

#[test]
fn rejects_directory_as_artifact() {
    let dir = tempfile::tempdir().unwrap();
    let mut manifest = Manifest::read(&fixture()).unwrap();
    manifest.artifacts.truncate(1);
    fs::create_dir(dir.path().join(&manifest.artifacts[0].file)).unwrap();
    assert!(matches!(
        manifest.verify_all(dir.path()),
        Err(Error::UnsafeFile(_))
    ));
}

#[cfg(unix)]
#[test]
fn rejects_symlink_as_artifact() {
    let dir = tempfile::tempdir().unwrap();
    let mut manifest = Manifest::read(&fixture()).unwrap();
    manifest.artifacts.truncate(1);
    let source = fixture()
        .parent()
        .unwrap()
        .join(&manifest.artifacts[0].file);
    std::os::unix::fs::symlink(source, dir.path().join(&manifest.artifacts[0].file)).unwrap();
    assert!(matches!(
        manifest.verify_all(dir.path()),
        Err(Error::UnsafeFile(_))
    ));
}
