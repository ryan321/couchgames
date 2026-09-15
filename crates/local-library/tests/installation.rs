use couch_local_library::{Error, Library};
use couch_manifests::{Manifest, Target};
use std::{fs, path::PathBuf};

const TARGET: Target = Target::MacosAarch64;

fn package() -> (tempfile::TempDir, PathBuf) {
    let dir = tempfile::tempdir().unwrap();
    let source = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../tests/fixtures/package");
    for entry in fs::read_dir(source).unwrap() {
        let entry = entry.unwrap();
        if entry.path().is_file() {
            fs::copy(entry.path(), dir.path().join(entry.file_name())).unwrap();
        }
    }
    let path = dir.path().join("release.json");
    (dir, path)
}

fn new_release(path: &std::path::Path) {
    let mut manifest = Manifest::read(path).unwrap();
    manifest.release_id = "release-002".into();
    manifest.version = "0.2.0".into();
    fs::write(path, serde_json::to_vec(&manifest).unwrap()).unwrap();
}

#[tokio::test]
async fn persists_installation_and_retries_idempotently() {
    let (_package, path) = package();
    let data = tempfile::tempdir().unwrap();
    let library = Library::open(data.path()).await.unwrap();
    let installed = library.install(&path, TARGET).await.unwrap();
    assert!(!installed.already_installed);
    assert!(installed.active);
    assert!(installed.content_path.join("release.json").is_file());
    assert!(!data.path().join("runtimes").exists());
    assert!(
        library
            .install(&path, TARGET)
            .await
            .unwrap()
            .already_installed
    );
    assert_eq!(library.list().await.unwrap().len(), 1);
    library.close().await;
    let reopened = Library::open(data.path()).await.unwrap();
    assert_eq!(reopened.list().await.unwrap()[0].release_id, "release-001");
    reopened.close().await;
}

#[tokio::test]
async fn update_retains_previous_release_and_saves_and_retry_does_not_downgrade() {
    let (_package, path) = package();
    let original = fs::read(&path).unwrap();
    let data = tempfile::tempdir().unwrap();
    let library = Library::open(data.path()).await.unwrap();
    let first = library.install(&path, TARGET).await.unwrap();
    fs::create_dir_all(data.path().join("saves/profile/game")).unwrap();
    fs::write(
        data.path().join("saves/profile/game/save.json"),
        b"important",
    )
    .unwrap();
    new_release(&path);
    library.install(&path, TARGET).await.unwrap();
    fs::write(&path, original).unwrap();
    let retry = library.install(&path, TARGET).await.unwrap();
    assert!(retry.already_installed);
    assert!(!retry.active);
    let releases = library.list().await.unwrap();
    assert_eq!(releases.len(), 2);
    assert_eq!(
        releases.iter().find(|r| r.active).unwrap().release_id,
        "release-002"
    );
    assert!(first.content_path.is_dir());
    assert_eq!(
        fs::read(data.path().join("saves/profile/game/save.json")).unwrap(),
        b"important"
    );
    library.close().await;
}

#[tokio::test]
async fn corrupted_update_cannot_replace_active_release_and_cleans_staging() {
    let (_package, path) = package();
    let data = tempfile::tempdir().unwrap();
    let library = Library::open(data.path()).await.unwrap();
    library.install(&path, TARGET).await.unwrap();
    new_release(&path);
    let manifest = Manifest::read(&path).unwrap();
    let artifact = manifest.artifact(TARGET).unwrap();
    fs::write(
        path.parent().unwrap().join(&artifact.file),
        vec![0; artifact.size_bytes as usize],
    )
    .unwrap();
    assert!(matches!(
        library.install(&path, TARGET).await,
        Err(Error::Package(couch_manifests::Error::Hash(_)))
    ));
    let releases = library.list().await.unwrap();
    assert_eq!(releases.len(), 1);
    assert!(releases[0].active);
    assert_eq!(
        fs::read_dir(data.path().join("staging")).unwrap().count(),
        0
    );
    library.close().await;
}

#[tokio::test]
async fn rejects_mutation_of_an_existing_release_including_other_targets() {
    let (_package, path) = package();
    let data = tempfile::tempdir().unwrap();
    let library = Library::open(data.path()).await.unwrap();
    library.install(&path, TARGET).await.unwrap();
    let mut manifest = Manifest::read(&path).unwrap();
    manifest.title = "Changed metadata".into();
    fs::write(&path, serde_json::to_vec(&manifest).unwrap()).unwrap();
    for target in [TARGET, Target::WindowsX86_64] {
        assert!(matches!(
            library.install(&path, target).await,
            Err(Error::ReleaseConflict)
        ));
    }
    assert_eq!(library.list().await.unwrap().len(), 1);
    library.close().await;
}

#[tokio::test]
async fn database_failure_preserves_active_release_and_retry_recovers_orphan() {
    let (_package, path) = package();
    let data = tempfile::tempdir().unwrap();
    let library = Library::open(data.path()).await.unwrap();
    library.install(&path, TARGET).await.unwrap();
    let db = sqlx::SqlitePool::connect_with(
        sqlx::sqlite::SqliteConnectOptions::new().filename(data.path().join("data/library.sqlite")),
    )
    .await
    .unwrap();
    sqlx::raw_sql("CREATE TRIGGER fail_new_release BEFORE INSERT ON installed_releases BEGIN SELECT RAISE(ABORT, 'simulated commit path failure'); END;")
        .execute(&db).await.unwrap();
    new_release(&path);
    assert!(matches!(
        library.install(&path, TARGET).await,
        Err(Error::Database(_))
    ));
    let old = library.list().await.unwrap();
    assert_eq!(old.len(), 1);
    assert!(old[0].active);
    assert!(
        data.path()
            .join("games/g-example.fixture/r-release-002/macos-aarch64")
            .exists()
    );
    sqlx::raw_sql("DROP TRIGGER fail_new_release")
        .execute(&db)
        .await
        .unwrap();
    library.install(&path, TARGET).await.unwrap();
    let current = library.list().await.unwrap();
    assert_eq!(current.iter().filter(|r| r.active).count(), 1);
    assert_eq!(
        current.iter().find(|r| r.active).unwrap().release_id,
        "release-002"
    );
    db.close().await;
    library.close().await;
}

#[tokio::test]
async fn reports_missing_installed_files_instead_of_silently_reactivating() {
    let (_package, path) = package();
    let data = tempfile::tempdir().unwrap();
    let library = Library::open(data.path()).await.unwrap();
    let first = library.install(&path, TARGET).await.unwrap();
    fs::remove_dir_all(first.content_path).unwrap();
    assert!(matches!(
        library.install(&path, TARGET).await,
        Err(Error::CorruptInstallation(_))
    ));
    library.close().await;
}

#[tokio::test]
async fn concurrent_imports_use_one_immutable_release() {
    let (_package, path) = package();
    let data = tempfile::tempdir().unwrap();
    let first = Library::open(data.path()).await.unwrap();
    let second = Library::open(data.path()).await.unwrap();
    let (a, b) = tokio::join!(first.install(&path, TARGET), second.install(&path, TARGET));
    assert_ne!(a.unwrap().already_installed, b.unwrap().already_installed);
    assert_eq!(first.list().await.unwrap().len(), 1);
    first.close().await;
    second.close().await;
}

#[cfg(unix)]
#[tokio::test]
async fn rejects_symlinked_library_subdirectory() {
    let data = tempfile::tempdir().unwrap();
    let outside = tempfile::tempdir().unwrap();
    std::os::unix::fs::symlink(outside.path(), data.path().join("games")).unwrap();
    assert!(matches!(
        Library::open(data.path()).await,
        Err(Error::UnsafeDirectory(_))
    ));
    assert_eq!(fs::read_dir(outside.path()).unwrap().count(), 0);
}
