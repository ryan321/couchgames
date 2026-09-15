use couch_runtime::{Discovery, Policy, normalize_executable, parse_version, supported};
use std::{path::Path, time::Duration};

#[test]
fn host_policy_agrees_with_sdk_test_vectors() {
    let cases: serde_json::Value =
        serde_json::from_str(include_str!("../../../sdk/tests/runtime_versions.json")).unwrap();
    let policy = Policy::bundled();
    assert_eq!(policy.policy_version, 1);
    for case in cases.as_array().unwrap() {
        let version = parse_version(case["raw"].as_str().unwrap()).unwrap();
        assert_eq!(
            supported(&version, &policy),
            case["supported"].as_bool().unwrap(),
            "{}",
            case["raw"]
        );
    }
}

#[test]
fn rejects_unrecognized_version_output() {
    for value in [
        "",
        "hello",
        "couch 0.1.0",
        "4.7.2",
        "4.7.2.stable",
        "4.7.2.stable.official\nextra",
    ] {
        assert!(parse_version(value).is_err(), "{value}");
    }
}

#[test]
fn accepts_mac_application_path() {
    assert_eq!(
        normalize_executable(Path::new("/Applications/Godot.app")),
        Path::new("/Applications/Godot.app/Contents/MacOS/Godot")
    );
    assert_eq!(
        normalize_executable(Path::new("/tmp/godot")),
        Path::new("/tmp/godot")
    );
}

#[tokio::test]
async fn missing_engine_has_installation_instructions_without_creating_files() {
    let dir = tempfile::tempdir().unwrap();
    let report = Discovery {
        override_path: None,
        candidates: vec![dir.path().join("missing")],
        probe_timeout: Duration::from_millis(100),
    }
    .check()
    .await;
    assert_eq!(report.status, "missing");
    assert!(!report.supported);
    assert!(
        report
            .instructions
            .iter()
            .any(|line| line.contains(&report.policy.download_url))
    );
    assert_eq!(std::fs::read_dir(dir.path()).unwrap().count(), 0);
}

#[cfg(unix)]
mod subprocess {
    use super::*;
    use std::{fs, os::unix::fs::PermissionsExt, path::PathBuf};

    fn executable(dir: &Path, name: &str, body: &str) -> PathBuf {
        let path = dir.join(name);
        fs::write(&path, format!("#!/bin/sh\n{body}\n")).unwrap();
        fs::set_permissions(&path, fs::Permissions::from_mode(0o755)).unwrap();
        path
    }

    fn config(paths: Vec<PathBuf>) -> Discovery {
        Discovery {
            override_path: None,
            candidates: paths,
            probe_timeout: Duration::from_secs(3),
        }
    }

    #[tokio::test]
    async fn skips_old_version_and_reuses_supported_installation() {
        let dir = tempfile::tempdir().unwrap();
        let old = executable(dir.path(), "old", "echo 4.7.1.stable.official.abc");
        let good = executable(dir.path(), "good", "echo 4.7.2.stable.official.abc");
        let report = config(vec![old, good.clone()]).check().await;
        assert_eq!(report.status, "supported");
        assert_eq!(report.executable, Some(good.canonicalize().unwrap()));
        assert_eq!(report.attempts.len(), 2);
    }

    #[tokio::test]
    async fn explicit_missing_path_does_not_silently_fall_back() {
        let dir = tempfile::tempdir().unwrap();
        let good = executable(dir.path(), "good", "echo 4.7.2.stable.official.abc");
        let mut discovery = config(vec![good]);
        discovery.override_path = Some(dir.path().join("missing"));
        let report = discovery.check().await;
        assert_eq!(report.status, "unusable");
        assert_eq!(report.attempts.len(), 1);
        assert!(!report.supported);
    }

    #[tokio::test]
    async fn reports_unsupported_engine_and_its_detected_version() {
        let dir = tempfile::tempdir().unwrap();
        let old = executable(dir.path(), "old", "echo 4.6.1.stable.official.abc");
        let report = config(vec![old]).check().await;
        assert_eq!(report.status, "unsupported");
        assert_eq!(
            report.attempts[0].version.as_ref().unwrap().version,
            "4.6.1"
        );
    }

    #[tokio::test]
    async fn handles_failure_timeout_and_excess_output() {
        let dir = tempfile::tempdir().unwrap();
        for (name, body, reason) in [
            ("failed", "exit 9", "failed"),
            ("slow", "exec sleep 10", "timed out"),
            (
                "verbose",
                "i=0; while [ $i -lt 5000 ]; do printf x; i=$((i+1)); done",
                "exceeded",
            ),
        ] {
            let path = executable(dir.path(), name, body);
            let mut discovery = config(vec![path]);
            if name == "slow" {
                discovery.probe_timeout = Duration::from_millis(50);
            }
            let report = discovery.check().await;
            assert_eq!(report.status, "unusable");
            assert!(
                report.attempts[0].reason.contains(reason),
                "{}",
                report.attempts[0].reason
            );
        }
    }
}
