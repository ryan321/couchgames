//! Local developer imports only. No runtime download, launch, or trust certification.

mod migrations;

use couch_manifests::{Manifest, Target, copy_artifact, verify_artifact};
use serde::Serialize;
use sqlx::{Row, SqlitePool, sqlite::SqliteConnectOptions, sqlite::SqlitePoolOptions};
use std::{
    fs::{self, File},
    io::{self, Write},
    path::{Path, PathBuf},
    time::Duration,
};

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error(transparent)]
    Package(#[from] couch_manifests::Error),
    #[error("local filesystem error: {0}")]
    Io(#[from] io::Error),
    #[error("local database error: {0}")]
    Database(#[from] sqlx::Error),
    #[error("local database migration failed: {0}")]
    Migration(#[from] sqlx::migrate::MigrateError),
    #[error("manifest encoding failed: {0}")]
    Json(#[from] serde_json::Error),
    #[error("release ID already exists with different metadata; create a new release ID")]
    ReleaseConflict,
    #[error("installed content is missing or inconsistent: {0}")]
    CorruptInstallation(PathBuf),
    #[error("library directory must not be a symlink or non-directory: {0}")]
    UnsafeDirectory(PathBuf),
}

impl Error {
    pub fn code(&self) -> &'static str {
        match self {
            Self::Package(e) => e.code(),
            Self::Io(_) => "LIBRARY_IO",
            Self::Database(_) | Self::Migration(_) => "LIBRARY_DATABASE",
            Self::Json(_) => "INVALID_MANIFEST",
            Self::ReleaseConflict => "RELEASE_CONFLICT",
            Self::CorruptInstallation(_) => "CORRUPT_INSTALLATION",
            Self::UnsafeDirectory(_) => "UNSAFE_LIBRARY_PATH",
        }
    }
}

#[derive(Debug, Serialize)]
pub struct InstalledRelease {
    pub game_id: String,
    pub release_id: String,
    pub target: String,
    pub title: String,
    pub version: String,
    pub runtime: String,
    pub relative_path: String,
    pub active: bool,
    pub installed_at: String,
}

#[derive(Debug, Serialize)]
pub struct InstallResult {
    pub game_id: String,
    pub release_id: String,
    pub target: Target,
    pub already_installed: bool,
    pub active: bool,
    pub content_path: PathBuf,
    pub trust: &'static str,
}

pub struct Library {
    root: PathBuf,
    pool: SqlitePool,
}

impl Library {
    pub async fn open(root: &Path) -> Result<Self, Error> {
        fs::create_dir_all(root)?;
        let root = root.canonicalize()?;
        for directory in ["data", "staging", "games"] {
            ensure_directory(&root.join(directory))?;
        }
        let database = root.join("data/library.sqlite");
        if let Ok(metadata) = fs::symlink_metadata(&database)
            && (!metadata.is_file() || metadata.file_type().is_symlink())
        {
            return Err(Error::CorruptInstallation(database));
        }
        let options = SqliteConnectOptions::new()
            .filename(database)
            .create_if_missing(true)
            .foreign_keys(true)
            .busy_timeout(Duration::from_secs(10));
        let pool = SqlitePoolOptions::new()
            .max_connections(1)
            .connect_with(options)
            .await?;
        sqlx::migrate::Migrator::new(migrations::EmbeddedMigrations)
            .await?
            .run(&pool)
            .await?;
        Ok(Self { root, pool })
    }

    pub async fn close(self) {
        self.pool.close().await;
    }

    pub async fn list(&self) -> Result<Vec<InstalledRelease>, Error> {
        let rows = sqlx::query(
            "SELECT game_id, release_id, target, title, version, runtime, relative_path, active, installed_at
             FROM installed_releases ORDER BY game_id, target, installed_at, release_id",
        )
        .fetch_all(&self.pool)
        .await?;
        rows.into_iter()
            .map(|row| {
                Ok(InstalledRelease {
                    game_id: row.try_get("game_id")?,
                    release_id: row.try_get("release_id")?,
                    target: row.try_get("target")?,
                    title: row.try_get("title")?,
                    version: row.try_get("version")?,
                    runtime: row.try_get("runtime")?,
                    relative_path: row.try_get("relative_path")?,
                    active: row.try_get("active")?,
                    installed_at: row.try_get("installed_at")?,
                })
            })
            .collect()
    }

    /// Imports selected target bytes. No game code is inspected or executed.
    pub async fn install(
        &self,
        manifest_path: &Path,
        target: Target,
    ) -> Result<InstallResult, Error> {
        let manifest = Manifest::read(manifest_path)?;
        let artifact = manifest.artifact(target)?;
        let source = manifest_path.parent().unwrap_or_else(|| Path::new("."));
        let fingerprint = manifest.fingerprint()?;
        let target_name = target.to_string();

        // Stage before touching active database state. TempDir removes normal failed imports.
        let stage = tempfile::Builder::new()
            .prefix("install-")
            .tempdir_in(self.root.join("staging"))?;
        let mut content = File::create(stage.path().join(&artifact.file))?;
        copy_artifact(source, artifact, &mut content)?;
        content.sync_all()?;
        drop(content);
        let mut metadata = File::create(stage.path().join("release.json"))?;
        metadata.write_all(&serde_json::to_vec_pretty(&manifest)?)?;
        metadata.sync_all()?;
        drop(metadata);

        // Acquire the database write lock before checking or modifying final directories.
        // All cooperating host/CLI importers serialize across filesystem activation and commit.
        let mut tx = self.pool.begin().await?;
        sqlx::query("UPDATE library_lock SET token = token WHERE id = 1")
            .execute(&mut *tx)
            .await?;

        // Release identity is immutable across target variants, not just within one target.
        let conflicting: i64 = sqlx::query_scalar(
            "SELECT count(*) FROM installed_releases
             WHERE game_id = ? AND release_id = ? AND manifest_hash != ?",
        )
        .bind(&manifest.game_id)
        .bind(&manifest.release_id)
        .bind(&fingerprint)
        .fetch_one(&mut *tx)
        .await?;
        if conflicting != 0 {
            return Err(Error::ReleaseConflict);
        }

        let relative = format!(
            "games/g-{}/r-{}/{}",
            manifest.game_id, manifest.release_id, target
        );
        let destination = self.root.join(&relative);
        ensure_directory(&self.root.join(format!("games/g-{}", manifest.game_id)))?;
        ensure_directory(&self.root.join(format!(
            "games/g-{}/r-{}",
            manifest.game_id, manifest.release_id
        )))?;

        let existing = sqlx::query(
            "SELECT active FROM installed_releases WHERE game_id = ? AND release_id = ? AND target = ?",
        )
        .bind(&manifest.game_id)
        .bind(&manifest.release_id)
        .bind(&target_name)
        .fetch_optional(&mut *tx)
        .await?;

        let already_installed = existing.is_some();
        let active = match existing {
            Some(ref row) => row.try_get("active")?,
            None => true,
        };
        match fs::symlink_metadata(&destination) {
            Ok(_) => {
                // A crash after rename and before database commit leaves an orphan.
                // Reuse it only if its manifest and bytes exactly match this request.
                check_directory(&destination)?;
                let installed_manifest = destination.join("release.json");
                let meta = fs::symlink_metadata(&installed_manifest)?;
                if !meta.is_file() || meta.file_type().is_symlink() {
                    return Err(Error::CorruptInstallation(installed_manifest));
                }
                if Manifest::read(&installed_manifest)?.fingerprint()? != fingerprint {
                    return Err(Error::ReleaseConflict);
                }
                verify_artifact(&destination, artifact)?;
            }
            Err(e) if e.kind() == io::ErrorKind::NotFound => {
                if already_installed {
                    return Err(Error::CorruptInstallation(destination));
                }
                fs::rename(stage.path(), &destination)?;
            }
            Err(e) => return Err(e.into()),
        }

        if !already_installed {
            sqlx::query(
                "UPDATE installed_releases SET active = 0 WHERE game_id = ? AND target = ?",
            )
            .bind(&manifest.game_id)
            .bind(&target_name)
            .execute(&mut *tx)
            .await?;
            sqlx::query(
                "INSERT INTO installed_releases
                 (game_id, release_id, target, title, version, runtime, manifest_hash, relative_path, active)
                 VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)",
            )
            .bind(&manifest.game_id)
            .bind(&manifest.release_id)
            .bind(&target_name)
            .bind(&manifest.title)
            .bind(&manifest.version)
            .bind(&manifest.runtime)
            .bind(&fingerprint)
            .bind(&relative)
            .execute(&mut *tx)
            .await?;
        }
        tx.commit().await?;
        Ok(InstallResult {
            game_id: manifest.game_id,
            release_id: manifest.release_id,
            target,
            already_installed,
            active,
            content_path: destination,
            trust: "unsigned_local_import",
        })
    }
}

fn ensure_directory(path: &Path) -> Result<(), Error> {
    match fs::create_dir(path) {
        Ok(()) => Ok(()),
        Err(e) if e.kind() == io::ErrorKind::AlreadyExists => check_directory(path),
        Err(e) => Err(e.into()),
    }
}

fn check_directory(path: &Path) -> Result<(), Error> {
    let metadata = fs::symlink_metadata(path)?;
    if !metadata.is_dir() || metadata.file_type().is_symlink() {
        return Err(Error::UnsafeDirectory(path.into()));
    }
    Ok(())
}
