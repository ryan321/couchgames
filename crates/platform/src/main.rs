use std::{env, path::Path, process::ExitCode};

fn main() -> ExitCode {
    let port = env::var("PORT").unwrap_or_else(|_| "8080".into());
    let bind = env::var("BIND").unwrap_or_else(|_| format!("0.0.0.0:{port}"));
    let data = env::var("DATA_DIR").unwrap_or_else(|_| "/data".into());
    let packages = env::var("PACKAGES_DIR").unwrap_or_else(|_| format!("{data}/packages"));
    let blob = env::var("BLOB_ISLAND").unwrap_or_else(|_| "/app/blob-island".into());
    let public_url = env::var("PUBLIC_URL").ok().or_else(|| {
        env::var("FLY_APP_NAME")
            .ok()
            .map(|name| format!("https://{name}.fly.dev"))
    });
    if Path::new(&blob).join("gigacouch.json").is_file()
        && let Err(error) =
            couch_platform::publish_blob_island(Path::new(&packages), Path::new(&blob))
    {
        eprintln!("could not publish Blob Island: {error}");
        return ExitCode::from(1);
    }
    if let Err(error) = couch_platform::serve_until_stopped(
        Path::new(&data),
        Path::new(&packages),
        &bind,
        public_url.as_deref(),
    ) {
        eprintln!("{error}");
        return ExitCode::from(1);
    }
    ExitCode::SUCCESS
}
