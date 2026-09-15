use anyhow::{Context, Result};
use clap::{Parser, Subcommand};
use couch_local_library::Library;
use couch_manifests::{Manifest, Target};
use serde_json::{Value, json};
use std::path::{Path, PathBuf};

#[derive(Parser)]
#[command(
    name = "couch",
    version,
    about = "Couch Games local package tools (no engine required)"
)]
struct Cli {
    /// Print one JSON result envelope, including operational errors.
    #[arg(long, global = true)]
    json: bool,
    /// Override the per-user application data directory.
    #[arg(long, global = true)]
    data_dir: Option<PathBuf>,
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Show local configuration. Does not install tools or create files.
    Doctor,
    /// Check manifest and every declared artifact's size and SHA-256.
    Validate { manifest: PathBuf },
    /// Import unsigned local content. Does not install a runtime or run a game.
    Install {
        manifest: PathBuf,
        /// Defaults to this computer's OS/architecture.
        #[arg(long)]
        target: Option<Target>,
    },
    /// List all installed releases, including inactive previous versions.
    Library,
}

#[tokio::main(flavor = "current_thread")]
async fn main() {
    let cli = Cli::parse();
    match run(&cli).await {
        Ok((value, human)) => {
            if cli.json {
                println!("{}", json!({ "ok": true, "data": value }));
            } else {
                println!("{human}");
            }
        }
        Err(error) => {
            let code = if let Some(e) = error.downcast_ref::<couch_manifests::Error>() {
                e.code()
            } else if let Some(e) = error.downcast_ref::<couch_local_library::Error>() {
                e.code()
            } else {
                "COMMAND_FAILED"
            };
            if cli.json {
                println!(
                    "{}",
                    json!({
                        "ok": false,
                        "error": { "code": code, "message": format!("{error:#}") }
                    })
                );
            } else {
                eprintln!("{code}: {error:#}");
            }
            std::process::exit(1);
        }
    }
}

fn data_dir(cli: &Cli) -> Result<PathBuf> {
    if let Some(path) = &cli.data_dir {
        return Ok(path.clone());
    }
    directories::ProjectDirs::from("", "", "CouchGames")
        .map(|dirs| dirs.data_local_dir().to_path_buf())
        .context("could not determine application directory; pass --data-dir")
}

async fn run(cli: &Cli) -> Result<(Value, String)> {
    match &cli.command {
        Command::Doctor => {
            let root = data_dir(cli)?;
            let value = json!({
                "version": env!("CARGO_PKG_VERSION"),
                "data_dir": root,
                "host_target": Target::current(),
                "runtime_management": "not_implemented",
                "game_launch": "not_implemented",
                "godot_required_for_current_commands": false,
                "automatic_downloads": false
            });
            Ok((
                value,
                format!(
                    "Couch Games {}\nData directory: {}\nPackage and library commands require no Godot.\nRuntime management and game launch are not implemented. No tools are downloaded.",
                    env!("CARGO_PKG_VERSION"),
                    root.display()
                ),
            ))
        }
        Command::Validate { manifest } => {
            let package = Manifest::read(manifest)?;
            package.verify_all(manifest.parent().unwrap_or_else(|| Path::new(".")))?;
            let value = json!({
                "game_id": package.game_id,
                "release_id": package.release_id,
                "artifacts_verified": package.artifacts.len(),
                "scope": "metadata_and_content_integrity",
                "playability_verified": false,
                "signature_verified": false
            });
            Ok((
                value,
                format!(
                    "Validated {} / {} ({} artifacts).\nMetadata and content integrity only; playability and signatures are not verified.",
                    package.game_id,
                    package.release_id,
                    package.artifacts.len()
                ),
            ))
        }
        Command::Install { manifest, target } => {
            let selected = target
                .or_else(Target::current)
                .context("unsupported host target; pass --target for a content-only import")?;
            // Fail invalid manifests before initializing an on-disk library.
            Manifest::read(manifest)?.artifact(selected)?;
            let library = Library::open(&data_dir(cli)?).await?;
            let outcome = library.install(manifest, selected).await;
            library.close().await;
            let result = outcome?;
            let human = format!(
                "{} {} / {} for {}.\nUnsigned local content only. No runtime was installed and no game was run.",
                if result.already_installed {
                    "Already installed"
                } else {
                    "Installed"
                },
                result.game_id,
                result.release_id,
                result.target
            );
            Ok((serde_json::to_value(result)?, human))
        }
        Command::Library => {
            let library = Library::open(&data_dir(cli)?).await?;
            let outcome = library.list().await;
            library.close().await;
            let releases = outcome?;
            let human = if releases.is_empty() {
                "No games installed.".into()
            } else {
                releases
                    .iter()
                    .map(|r| {
                        format!(
                            "{} {} / {} [{}] — {}",
                            if r.active { "*" } else { " " },
                            r.game_id,
                            r.release_id,
                            r.target,
                            r.title
                        )
                    })
                    .collect::<Vec<_>>()
                    .join("\n")
            };
            Ok((json!({ "releases": releases }), human))
        }
    }
}
