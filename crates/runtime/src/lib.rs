//! Shared host-side discovery. Checks version compatibility, not executable provenance.
use serde::{Deserialize, Serialize};
use std::{
    collections::HashSet,
    path::{Path, PathBuf},
    process::Stdio,
    time::Duration,
};
use tokio::{io::AsyncReadExt, process::Command, time::timeout};

const POLICY: &str = include_str!("../../../sdk/addons/couchgames/runtime_policy.json");
const OUTPUT_LIMIT: u64 = 4096;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Policy {
    pub policy_version: u32,
    pub runtime_id: String,
    pub godot_version: String,
    pub release_status: String,
    pub build: String,
    pub edition: String,
    pub download_url: String,
}

impl Policy {
    pub fn bundled() -> Self {
        serde_json::from_str(POLICY).expect("bundled runtime policy must be valid JSON")
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct DetectedVersion {
    pub raw: String,
    pub version: String,
    pub status: String,
    pub build: String,
    pub edition: String,
}

pub fn parse_version(raw: &str) -> Result<DetectedVersion, String> {
    let raw = raw.trim();
    if raw.is_empty()
        || !raw
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b"._-".contains(&b))
    {
        return Err("Godot returned an unrecognized version string".into());
    }
    let parts: Vec<_> = raw.split('.').collect();
    if parts.len() < 4 || parts[0].parse::<u32>().is_err() || parts[1].parse::<u32>().is_err() {
        return Err("Godot returned an unrecognized version string".into());
    }
    // Godot omits .0 in releases such as 4.7.stable.official.<hash>.
    let (patch, offset) = match parts[2].parse::<u32>() {
        Ok(patch) => (patch, 3),
        Err(_) => (0, 2),
    };
    let status = parts.get(offset).ok_or("missing release status")?;
    let mono = parts.get(offset + 1) == Some(&"mono");
    let build = parts
        .get(offset + 1 + usize::from(mono))
        .ok_or("missing build type")?;
    Ok(DetectedVersion {
        raw: raw.into(),
        version: format!("{}.{}.{patch}", parts[0], parts[1]),
        status: (*status).into(),
        build: (*build).into(),
        edition: if mono { "dotnet" } else { "standard" }.into(),
    })
}

pub fn supported(version: &DetectedVersion, policy: &Policy) -> bool {
    version.version == policy.godot_version
        && version.status == policy.release_status
        && version.build == policy.build
        && version.edition == policy.edition
}

#[derive(Debug, Serialize)]
pub struct Attempt {
    pub executable: PathBuf,
    pub version: Option<DetectedVersion>,
    pub supported: bool,
    pub reason: String,
}

#[derive(Debug, Serialize)]
pub struct Report {
    pub status: &'static str,
    pub supported: bool,
    pub executable: Option<PathBuf>,
    pub policy: Policy,
    pub attempts: Vec<Attempt>,
    pub instructions: Vec<String>,
}

/// Inputs are explicit so tests do not depend on the developer's Godot installation.
pub struct Discovery {
    pub override_path: Option<PathBuf>,
    pub candidates: Vec<PathBuf>,
    pub probe_timeout: Duration,
}

impl Discovery {
    pub fn system(explicit: Option<PathBuf>) -> Self {
        let policy = Policy::bundled();
        let override_path = explicit.or_else(|| std::env::var_os("COUCH_GODOT").map(PathBuf::from));
        let mut candidates = Vec::new();
        if let Some(path) = std::env::var_os("PATH") {
            for dir in std::env::split_paths(&path) {
                for name in [
                    "godot",
                    "godot4",
                    "Godot",
                    "godot.exe",
                    "godot4.exe",
                    "Godot.exe",
                ] {
                    candidates.push(dir.join(name));
                }
                candidates
                    .push(dir.join(format!("Godot_v{}-stable_win64.exe", policy.godot_version)));
            }
        }
        #[cfg(target_os = "macos")]
        {
            add_mac_apps(Path::new("/Applications"), &mut candidates);
            if let Some(base) = directories::BaseDirs::new() {
                add_mac_apps(&base.home_dir().join("Applications"), &mut candidates);
            }
        }
        #[cfg(target_os = "windows")]
        {
            if let Some(base) = std::env::var_os("LOCALAPPDATA") {
                candidates.push(PathBuf::from(base).join("Programs/Godot/Godot.exe"));
            }
            if let Some(base) = std::env::var_os("ProgramFiles") {
                candidates.push(PathBuf::from(base).join("Godot/Godot.exe"));
            }
        }
        Self {
            override_path,
            candidates,
            probe_timeout: Duration::from_secs(15),
        }
    }

    pub async fn check(self) -> Report {
        let policy = Policy::bundled();
        let explicit = self.override_path.is_some();
        let candidates = match self.override_path {
            Some(path) => vec![path],
            None => self.candidates,
        };
        let mut attempts = Vec::new();
        let mut seen = HashSet::new();
        let mut selected = None;
        for path in candidates {
            let executable = normalize_executable(&path);
            if !explicit && !executable.is_file() {
                continue;
            }
            let executable = executable.canonicalize().unwrap_or(executable);
            if !seen.insert(executable.clone()) {
                continue;
            }
            let result = probe(&executable, self.probe_timeout)
                .await
                .and_then(|raw| parse_version(&raw));
            let (version, is_supported, reason) = match result {
                Ok(version) => {
                    let matches = supported(&version, &policy);
                    let reason = if matches {
                        "Version matches the development policy; this is not a signature or sandbox check".into()
                    } else {
                        format!(
                            "Requires Godot {} {} {} ({})",
                            policy.godot_version,
                            policy.release_status,
                            policy.build,
                            policy.edition
                        )
                    };
                    (Some(version), matches, reason)
                }
                Err(reason) => (None, false, reason),
            };
            attempts.push(Attempt {
                executable: executable.clone(),
                version,
                supported: is_supported,
                reason,
            });
            if is_supported {
                selected = Some(executable);
                break;
            }
        }
        let status = if selected.is_some() {
            "supported"
        } else if attempts.is_empty() {
            "missing"
        } else if attempts.iter().any(|a| a.version.is_some()) {
            "unsupported"
        } else {
            "unusable"
        };
        let instructions = installation_instructions(&policy);
        Report {
            status,
            supported: selected.is_some(),
            executable: selected,
            policy,
            attempts,
            instructions,
        }
    }
}

pub fn normalize_executable(path: &Path) -> PathBuf {
    if path.extension().is_some_and(|ext| ext == "app") {
        path.join("Contents/MacOS/Godot")
    } else {
        path.to_path_buf()
    }
}

#[cfg(target_os = "macos")]
fn add_mac_apps(directory: &Path, candidates: &mut Vec<PathBuf>) {
    candidates.push(directory.join("Godot.app"));
    if let Ok(entries) = std::fs::read_dir(directory) {
        let mut apps: Vec<_> = entries
            .filter_map(Result::ok)
            .map(|e| e.path())
            .filter(|path| {
                path.file_name()
                    .is_some_and(|name| name.to_string_lossy().starts_with("Godot"))
                    && path.extension().is_some_and(|ext| ext == "app")
            })
            .collect();
        apps.sort();
        candidates.extend(apps.into_iter().take(32));
    }
}

fn installation_instructions(policy: &Policy) -> Vec<String> {
    vec![
        format!("Download Godot {} standard (not .NET): {}", policy.godot_version, policy.download_url),
        "macOS: extract Godot.app and move it to ~/Applications or /Applications. Open it normally to complete macOS approval if prompted.".into(),
        "Windows: extract the matching archive; set COUCH_GODOT to its Godot executable, or put that executable on PATH.".into(),
        "For a custom location, set COUCH_GODOT or pass --godot /path/to/Godot. A macOS .app path is also accepted.".into(),
        "Run couch doctor --require-godot again. An explicit path overrides auto-detection, including when that path is invalid.".into(),
        "Export templates and .NET are not needed for SDK/editor tests. Nothing is downloaded automatically.".into(),
    ]
}

async fn probe(path: &Path, limit: Duration) -> Result<String, String> {
    let mut child = Command::new(path)
        .args(["--headless", "--version"])
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .kill_on_drop(true)
        .spawn()
        .map_err(|e| format!("Could not run Godot: {e}"))?;
    let stdout = child.stdout.take().ok_or("Godot stdout was unavailable")?;
    let result = timeout(limit, async {
        let mut bytes = Vec::new();
        stdout
            .take(OUTPUT_LIMIT + 1)
            .read_to_end(&mut bytes)
            .await
            .map_err(|e| e.to_string())?;
        if bytes.len() as u64 > OUTPUT_LIMIT {
            return Err("Godot version output exceeded 4 KiB".into());
        }
        let status = child.wait().await.map_err(|e| e.to_string())?;
        if !status.success() {
            return Err(format!(
                "Godot --version failed ({status}); check permissions or OS approval"
            ));
        }
        String::from_utf8(bytes).map_err(|_| "Godot returned non-UTF-8 output".into())
    })
    .await;
    match result {
        Ok(Ok(raw)) => Ok(raw),
        other => {
            let _ = child.kill().await;
            match other {
                Ok(Err(reason)) => Err(reason),
                _ => Err("Godot version check timed out. Open the application once to complete OS startup/approval, then retry; the CLI also accepts --godot-timeout-secs".into()),
            }
        }
    }
}
