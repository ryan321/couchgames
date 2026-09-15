//! Provisional package contract. Integrity checks do not certify game safety.

use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{
    collections::HashSet,
    fs::{self, File},
    io::{self, Read, Write},
    path::{Path, PathBuf},
    str::FromStr,
};

pub const MAX_MANIFEST_BYTES: u64 = 64 * 1024;
pub const MAX_ARTIFACT_BYTES: u64 = 4 * 1024 * 1024 * 1024;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("invalid manifest: {0}")]
    Invalid(String),
    #[error("invalid manifest JSON: {0}")]
    Json(#[from] serde_json::Error),
    #[error("could not access {path}: {source}")]
    Io {
        path: PathBuf,
        #[source]
        source: io::Error,
    },
    #[error("artifact {file}: expected {expected} bytes, found {actual}")]
    Size {
        file: String,
        expected: u64,
        actual: u64,
    },
    #[error("SHA-256 mismatch for {0}")]
    Hash(String),
    #[error("artifact must be a regular file, not a symlink: {0}")]
    UnsafeFile(PathBuf),
    #[error("no artifact for target {0}")]
    MissingTarget(Target),
}

impl Error {
    pub fn code(&self) -> &'static str {
        match self {
            Self::Invalid(_) | Self::Json(_) => "INVALID_MANIFEST",
            Self::Io { .. } => "PACKAGE_IO",
            Self::Size { .. } => "ARTIFACT_SIZE_MISMATCH",
            Self::Hash(_) => "ARTIFACT_HASH_MISMATCH",
            Self::UnsafeFile(_) => "UNSAFE_ARTIFACT",
            Self::MissingTarget(_) => "TARGET_NOT_AVAILABLE",
        }
    }
}

fn io_error(path: &Path, source: io::Error) -> Error {
    Error::Io {
        path: path.into(),
        source,
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Os {
    Windows,
    Macos,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Architecture {
    X86_64,
    Aarch64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum Target {
    #[serde(rename = "windows-x86_64")]
    WindowsX86_64,
    #[serde(rename = "macos-x86_64")]
    MacosX86_64,
    #[serde(rename = "macos-aarch64")]
    MacosAarch64,
}

impl Target {
    pub fn current() -> Option<Self> {
        match (std::env::consts::OS, std::env::consts::ARCH) {
            ("windows", "x86_64") => Some(Self::WindowsX86_64),
            ("macos", "x86_64") => Some(Self::MacosX86_64),
            ("macos", "aarch64") => Some(Self::MacosAarch64),
            _ => None,
        }
    }
}

impl std::fmt::Display for Target {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(match self {
            Self::WindowsX86_64 => "windows-x86_64",
            Self::MacosX86_64 => "macos-x86_64",
            Self::MacosAarch64 => "macos-aarch64",
        })
    }
}

impl FromStr for Target {
    type Err = String;

    fn from_str(value: &str) -> Result<Self, Self::Err> {
        match value {
            "windows-x86_64" => Ok(Self::WindowsX86_64),
            "macos-x86_64" => Ok(Self::MacosX86_64),
            "macos-aarch64" => Ok(Self::MacosAarch64),
            _ => Err("target must be windows-x86_64, macos-x86_64, or macos-aarch64".into()),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Players {
    pub min: u8,
    pub max: u8,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Artifact {
    pub os: Os,
    pub architecture: Architecture,
    pub renderer: String,
    pub file: String,
    pub size_bytes: u64,
    pub sha256: String,
}

impl Artifact {
    pub fn target(&self) -> Result<Target, Error> {
        match (self.os, self.architecture) {
            (Os::Windows, Architecture::X86_64) => Ok(Target::WindowsX86_64),
            (Os::Macos, Architecture::X86_64) => Ok(Target::MacosX86_64),
            (Os::Macos, Architecture::Aarch64) => Ok(Target::MacosAarch64),
            _ => Err(Error::Invalid("unsupported OS/architecture pair".into())),
        }
    }

    fn validate(&self) -> Result<(), Error> {
        self.target()?;
        if self.renderer != "gl_compatibility" {
            return Err(Error::Invalid("V1 requires gl_compatibility".into()));
        }
        if !safe_filename(&self.file) {
            return Err(Error::Invalid(format!(
                "artifact filename must be a portable lowercase .pck basename: {}",
                self.file
            )));
        }
        if self.size_bytes == 0 || self.size_bytes > MAX_ARTIFACT_BYTES {
            return Err(Error::Invalid(
                "artifact size must be 1 byte to 4 GiB".into(),
            ));
        }
        if self.sha256.len() != 64
            || !self
                .sha256
                .bytes()
                .all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
        {
            return Err(Error::Invalid(
                "sha256 must be 64 lowercase hex characters".into(),
            ));
        }
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Manifest {
    pub manifest_version: u32,
    pub game_id: String,
    pub title: String,
    pub release_id: String,
    pub version: String,
    pub runtime: String,
    pub sdk: String,
    pub players: Players,
    pub artifacts: Vec<Artifact>,
}

impl Manifest {
    pub fn read(path: &Path) -> Result<Self, Error> {
        let file = File::open(path).map_err(|e| io_error(path, e))?;
        if !file.metadata().map_err(|e| io_error(path, e))?.is_file() {
            return Err(Error::Invalid("manifest must be a regular file".into()));
        }
        let mut bytes = Vec::new();
        file.take(MAX_MANIFEST_BYTES + 1)
            .read_to_end(&mut bytes)
            .map_err(|e| io_error(path, e))?;
        if bytes.len() as u64 > MAX_MANIFEST_BYTES {
            return Err(Error::Invalid("manifest exceeds 64 KiB".into()));
        }
        let manifest: Self = serde_json::from_slice(&bytes)?;
        manifest.validate()?;
        Ok(manifest)
    }

    pub fn validate(&self) -> Result<(), Error> {
        if self.manifest_version != 1 {
            return Err(Error::Invalid(
                "unsupported manifest_version; expected 1".into(),
            ));
        }
        for (name, value) in [("game_id", &self.game_id), ("release_id", &self.release_id)] {
            if !safe_id(value) {
                return Err(Error::Invalid(format!(
                    "{name} must be a portable 1–64 character identifier"
                )));
            }
        }
        if self.title.trim().is_empty()
            || self.title.chars().count() > 120
            || self.title.chars().any(char::is_control)
        {
            return Err(Error::Invalid(
                "title must contain 1–120 printable characters".into(),
            ));
        }
        for (name, value) in [("version", &self.version), ("sdk", &self.sdk)] {
            if value.len() > 64 || semver::Version::parse(value).is_err() {
                return Err(Error::Invalid(format!("{name} must be a semantic version")));
            }
        }
        if self.runtime.is_empty()
            || self.runtime.len() > 3
            || self.runtime.starts_with('0')
            || !self.runtime.bytes().all(|b| b.is_ascii_digit())
        {
            return Err(Error::Invalid("runtime must be an ID from 1 to 999".into()));
        }
        if self.players.min == 0 || self.players.max > 4 || self.players.min > self.players.max {
            return Err(Error::Invalid(
                "players must satisfy 1 <= min <= max <= 4".into(),
            ));
        }
        if self.artifacts.is_empty() || self.artifacts.len() > 3 {
            return Err(Error::Invalid("provide 1–3 target artifacts".into()));
        }
        let mut targets = HashSet::new();
        let mut files = HashSet::new();
        for artifact in &self.artifacts {
            artifact.validate()?;
            if !targets.insert(artifact.target()?) || !files.insert(&artifact.file) {
                return Err(Error::Invalid(
                    "duplicate target or artifact filename".into(),
                ));
            }
        }
        Ok(())
    }

    pub fn artifact(&self, target: Target) -> Result<&Artifact, Error> {
        self.artifacts
            .iter()
            .find(|a| a.target().ok() == Some(target))
            .ok_or(Error::MissingTarget(target))
    }

    /// Local identity comparison, not a distribution signature format.
    pub fn fingerprint(&self) -> Result<String, Error> {
        Ok(format!("{:x}", Sha256::digest(serde_json::to_vec(self)?)))
    }

    pub fn verify_all(&self, package_dir: &Path) -> Result<(), Error> {
        self.validate()?;
        for artifact in &self.artifacts {
            verify_artifact(package_dir, artifact)?;
        }
        Ok(())
    }
}

fn safe_id(value: &str) -> bool {
    let alnum = |b: u8| b.is_ascii_lowercase() || b.is_ascii_digit();
    !value.is_empty()
        && value.len() <= 64
        && alnum(value.as_bytes()[0])
        && alnum(value.as_bytes()[value.len() - 1])
        && value.bytes().all(|b| alnum(b) || b"._-".contains(&b))
}

fn safe_filename(value: &str) -> bool {
    let Some(stem) = value.strip_suffix(".pck") else {
        return false;
    };
    if !safe_id(stem) || value.len() > 68 {
        return false;
    }
    // Windows device basenames are reserved even when followed by extensions.
    let first = stem.split('.').next().unwrap_or("");
    !matches!(first, "con" | "prn" | "aux" | "nul")
        && !(first.len() == 4
            && (first.starts_with("com") || first.starts_with("lpt"))
            && (b'1'..=b'9').contains(&first.as_bytes()[3]))
}

pub fn verify_artifact(package_dir: &Path, artifact: &Artifact) -> Result<(), Error> {
    copy_artifact(package_dir, artifact, &mut io::sink())
}

/// Copies and hashes the same byte stream; a source change cannot bypass verification.
pub fn copy_artifact(
    package_dir: &Path,
    artifact: &Artifact,
    output: &mut impl Write,
) -> Result<(), Error> {
    artifact.validate()?;
    let path = package_dir.join(&artifact.file);
    let metadata = fs::symlink_metadata(&path).map_err(|e| io_error(&path, e))?;
    if !metadata.is_file() || metadata.file_type().is_symlink() {
        return Err(Error::UnsafeFile(path));
    }
    let mut input = File::open(&path).map_err(|e| io_error(&path, e))?;
    let metadata = input.metadata().map_err(|e| io_error(&path, e))?;
    if !metadata.is_file() {
        return Err(Error::UnsafeFile(path));
    }
    if metadata.len() != artifact.size_bytes {
        return Err(Error::Size {
            file: artifact.file.clone(),
            expected: artifact.size_bytes,
            actual: metadata.len(),
        });
    }
    let mut hash = Sha256::new();
    let mut total = 0_u64;
    let mut buffer = [0_u8; 64 * 1024];
    loop {
        let count = input.read(&mut buffer).map_err(|e| io_error(&path, e))?;
        if count == 0 {
            break;
        }
        total += count as u64;
        if total > artifact.size_bytes {
            break;
        }
        hash.update(&buffer[..count]);
        output
            .write_all(&buffer[..count])
            .map_err(|e| io_error(&path, e))?;
    }
    if total != artifact.size_bytes {
        return Err(Error::Size {
            file: artifact.file.clone(),
            expected: artifact.size_bytes,
            actual: total,
        });
    }
    if format!("{:x}", hash.finalize()) != artifact.sha256 {
        return Err(Error::Hash(artifact.file.clone()));
    }
    Ok(())
}
