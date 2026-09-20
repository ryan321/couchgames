use serde_json::{Value, json};
use std::{
    env, fs,
    io::{self, Write},
    path::{Path, PathBuf},
};

const DEFAULT_SCENE: &str = "res://examples/little_world/world.tscn";
const MAX_TITLE_CHARS: usize = 80;
const MAX_REGISTRY_PROJECTS: usize = 32;
const SKIP_DIR_NAMES: &[&str] = &[".godot", ".git", "__pycache__"];

#[derive(Debug)]
pub struct CliError {
    code: &'static str,
    message: String,
}

impl CliError {
    pub fn new(code: &'static str, message: impl Into<String>) -> Self {
        Self {
            code,
            message: message.into(),
        }
    }

    pub fn code(&self) -> &'static str {
        self.code
    }
}

impl std::fmt::Display for CliError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.write_str(&self.message)
    }
}

impl std::error::Error for CliError {}

#[derive(Debug)]
pub struct Issue {
    pub code: &'static str,
    pub message: String,
}

#[derive(Debug)]
pub struct ProjectReport {
    pub path: PathBuf,
    pub supported: bool,
    pub issues: Vec<Issue>,
}

impl ProjectReport {
    pub fn to_value(&self) -> Value {
        json!({
            "path": path_string(&self.path),
            "supported": self.supported,
            "issues": self.issues.iter().map(|issue| {
                json!({ "code": issue.code, "message": issue.message })
            }).collect::<Vec<_>>(),
        })
    }

    pub fn human(&self) -> String {
        let status = if self.supported {
            "supported"
        } else {
            "unsupported"
        };
        let mut text = format!("Project: {} ({status})", self.path.display());
        for issue in &self.issues {
            text.push_str(&format!("\n{}: {}", issue.code, issue.message));
        }
        text
    }
}

#[derive(Debug)]
pub struct InitResult {
    pub path: PathBuf,
    pub id: String,
    pub title: String,
}

pub fn inspect(path: &Path) -> Result<ProjectReport, CliError> {
    let root = project_root(path)?;
    let mut issues = Vec::new();

    let godot = root.join("project.godot");
    let addon = root.join("addons/couchgames/platform.gd");
    let policy = root.join("addons/couchgames/runtime_policy.json");
    let mut has_autoload = false;

    if !godot.is_file() {
        issues.push(Issue {
            code: "PROJECT_GODOT_MISSING",
            message: "project.godot is missing".into(),
        });
    } else {
        match fs::read_to_string(&godot) {
            Ok(text) => {
                has_autoload =
                    text.contains("Platform=") && text.contains("addons/couchgames/platform.gd");
                if !has_autoload {
                    issues.push(Issue {
                        code: "PLATFORM_AUTOLOAD_MISSING",
                        message: "project.godot must autoload Platform from addons/couchgames/platform.gd"
                            .into(),
                    });
                }
            }
            Err(error) => issues.push(Issue {
                code: "PROJECT_GODOT_MISSING",
                message: format!("could not read project.godot: {error}"),
            }),
        }
    }

    if !addon.is_file() {
        issues.push(Issue {
            code: "PLATFORM_ADDON_MISSING",
            message: "addons/couchgames/platform.gd is missing".into(),
        });
    }
    if !policy.is_file() {
        issues.push(Issue {
            code: "RUNTIME_POLICY_MISSING",
            message: "addons/couchgames/runtime_policy.json is missing".into(),
        });
    }

    inspect_game_json(&root, &mut issues);

    Ok(ProjectReport {
        path: root,
        supported: addon.is_file() && policy.is_file() && has_autoload,
        issues,
    })
}

pub fn init(
    title: &str,
    parent: &Path,
    template: Option<&Path>,
    data_dir: &Path,
) -> Result<InitResult, CliError> {
    let (id, title) = slug_and_title(title)?;
    if !parent.is_dir() {
        return Err(CliError::new(
            "PARENT_MISSING",
            format!(
                "Parent folder does not exist: {}. Pass --parent with an existing directory.",
                parent.display()
            ),
        ));
    }
    let dest = parent.join(&id);
    if dest.exists() {
        return Err(CliError::new(
            "DESTINATION_EXISTS",
            format!(
                "That project folder already exists ({}). Choose another name or location; no files were replaced.",
                dest.display()
            ),
        ));
    }
    let template = resolve_template(template)?;
    if let Err(error) = copy_tree(&template, &dest) {
        let _ = fs::remove_dir_all(&dest);
        return Err(error);
    }
    set_project_name(&dest.join("project.godot"), &title);
    write_game_json(&dest, &id, &title)?;
    let path = fs::canonicalize(&dest).unwrap_or_else(|_| absolute_path(&dest));
    register_project(data_dir, &id, &title, &path)?;
    Ok(InitResult { path, id, title })
}

fn project_root(path: &Path) -> Result<PathBuf, CliError> {
    if !path.exists() {
        return Err(CliError::new(
            "PROJECT_NOT_FOUND",
            format!("Project path not found: {}", path.display()),
        ));
    }
    let root = if path.is_file() {
        if path.file_name().is_some_and(|name| name == "project.godot") {
            path.parent()
                .filter(|parent| !parent.as_os_str().is_empty())
                .unwrap_or_else(|| Path::new("."))
                .to_path_buf()
        } else {
            return Err(CliError::new(
                "PROJECT_NOT_FOUND",
                format!(
                    "Pass a Godot project folder or project.godot file: {}",
                    path.display()
                ),
            ));
        }
    } else if path.is_dir() {
        path.to_path_buf()
    } else {
        return Err(CliError::new(
            "PROJECT_NOT_FOUND",
            format!("Project path not found: {}", path.display()),
        ));
    };
    Ok(fs::canonicalize(&root).unwrap_or_else(|_| absolute_path(&root)))
}

fn inspect_game_json(root: &Path, issues: &mut Vec<Issue>) {
    let path = root.join("couch.game.json");
    if !path.is_file() {
        issues.push(Issue {
            code: "COUCH_GAME_JSON_MISSING",
            message:
                "couch.game.json is missing; Giga Couch will not list this project until it exists"
                    .into(),
        });
        return;
    }
    let text = match fs::read_to_string(&path) {
        Ok(text) => text,
        Err(error) => {
            issues.push(Issue {
                code: "COUCH_GAME_JSON_INVALID",
                message: format!("could not read couch.game.json: {error}"),
            });
            return;
        }
    };
    let value: Value = match serde_json::from_str(&text) {
        Ok(value) => value,
        Err(error) => {
            issues.push(Issue {
                code: "COUCH_GAME_JSON_INVALID",
                message: format!("couch.game.json is not valid JSON: {error}"),
            });
            return;
        }
    };
    let valid = value.get("format").is_some_and(Value::is_number)
        && value.get("id").and_then(Value::as_str).is_some()
        && value.get("title").and_then(Value::as_str).is_some()
        && value
            .get("scene")
            .and_then(Value::as_str)
            .is_some_and(|scene| scene.starts_with("res://"));
    if !valid {
        issues.push(Issue {
            code: "COUCH_GAME_JSON_INVALID",
            message: "couch.game.json must have format (number), id (string), title (string), and scene starting with res://".into(),
        });
    }
}

fn slug_and_title(title: &str) -> Result<(String, String), CliError> {
    let title = title.trim();
    let chars = title.chars().count();
    if !(1..=MAX_TITLE_CHARS).contains(&chars) {
        return Err(CliError::new(
            "INVALID_TITLE",
            "Give your game a name between 1 and 80 characters.",
        ));
    }
    let slug = slugify(title);
    if slug.is_empty() {
        return Err(CliError::new(
            "INVALID_TITLE",
            "The project folder name must include a letter or digit.",
        ));
    }
    Ok((slug, title.to_string()))
}

fn slugify(title: &str) -> String {
    let mut slug = String::new();
    let mut pending_hyphen = false;
    for character in title.chars() {
        let character = character.to_ascii_lowercase();
        if character.is_ascii_alphanumeric() {
            if pending_hyphen && !slug.is_empty() {
                slug.push('-');
            }
            slug.push(character);
            pending_hyphen = false;
        } else if !slug.is_empty() {
            pending_hyphen = true;
        }
    }
    slug
}

fn resolve_template(explicit: Option<&Path>) -> Result<PathBuf, CliError> {
    if let Some(path) = explicit {
        if path.is_dir() {
            return Ok(absolute_path(path));
        }
        return Err(CliError::new(
            "TEMPLATE_MISSING",
            format!(
                "Template not found at {}. Pass --template with an existing project folder.",
                path.display()
            ),
        ));
    }
    if let Ok(gdk) = env::var("COUCH_GDK") {
        let candidate = PathBuf::from(gdk).join("templates/3d-couch");
        if candidate.is_dir() {
            return Ok(candidate);
        }
    }
    if let Ok(exe) = env::current_exe()
        && let Some(kit) = exe.parent().and_then(|bin| bin.parent())
    {
        let candidate = kit.join("templates/3d-couch");
        if candidate.is_dir() {
            return Ok(candidate);
        }
    }
    Err(CliError::new(
        "TEMPLATE_MISSING",
        "No project template found. Pass --template with a project folder to copy.",
    ))
}

fn copy_tree(src: &Path, dest: &Path) -> Result<(), CliError> {
    fs::create_dir_all(dest).map_err(|error| io_err(dest, error))?;
    for entry in fs::read_dir(src).map_err(|error| io_err(src, error))? {
        let entry = entry.map_err(|error| io_err(src, error))?;
        let name = entry.file_name();
        if SKIP_DIR_NAMES.iter().any(|skip| name.as_os_str() == *skip) {
            continue;
        }
        let from = entry.path();
        let to = dest.join(&name);
        let file_type = entry.file_type().map_err(|error| io_err(&from, error))?;
        if file_type.is_dir() {
            copy_tree(&from, &to)?;
        } else if file_type.is_file() {
            fs::copy(&from, &to).map_err(|error| io_err(&from, error))?;
        }
    }
    Ok(())
}

fn set_project_name(path: &Path, title: &str) {
    let Ok(text) = fs::read_to_string(path) else {
        return;
    };
    let escaped = title.replace('\\', "\\\\").replace('"', "\\\"");
    let mut found = false;
    let mut out = String::new();
    for line in text.lines() {
        let trimmed = line.trim_start();
        if !found && trimmed.starts_with("config/name=") {
            let indent_len = line.len() - trimmed.len();
            out.push_str(&line[..indent_len]);
            out.push_str("config/name=\"");
            out.push_str(&escaped);
            out.push_str("\"\n");
            found = true;
        } else {
            out.push_str(line);
            out.push('\n');
        }
    }
    if found {
        let _ = fs::write(path, out);
    }
}

fn write_game_json(project: &Path, id: &str, title: &str) -> Result<(), CliError> {
    let path = project.join("couch.game.json");
    let mut value = match fs::read_to_string(&path) {
        Ok(text) => serde_json::from_str(&text).unwrap_or_else(|_| json!({})),
        Err(_) => json!({}),
    };
    if !value.is_object() {
        value = json!({});
    }
    let scene = value
        .get("scene")
        .and_then(Value::as_str)
        .filter(|scene| scene.starts_with("res://"))
        .unwrap_or(DEFAULT_SCENE)
        .to_string();
    value["format"] = json!(1);
    value["id"] = json!(id);
    value["title"] = json!(title);
    value["scene"] = json!(scene);
    write_pretty_json(&path, &value)
}

fn register_project(data_dir: &Path, id: &str, title: &str, path: &Path) -> Result<(), CliError> {
    let registry_path = data_dir.join("creator-projects.json");
    let mut registry = load_registry(&registry_path);
    let mut projects: Vec<Value> = registry
        .get("projects")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    projects.retain(|row| {
        row.get("path")
            .and_then(Value::as_str)
            .is_none_or(|existing| !same_path(existing, path))
    });
    projects.insert(
        0,
        json!({
            "id": id,
            "title": title,
            "path": path_string(path),
        }),
    );
    projects.truncate(MAX_REGISTRY_PROJECTS);
    registry = json!({ "format": 1, "projects": projects });
    write_pretty_json(&registry_path, &registry)
}

fn load_registry(path: &Path) -> Value {
    let Ok(text) = fs::read_to_string(path) else {
        return json!({ "format": 1, "projects": [] });
    };
    match serde_json::from_str::<Value>(&text) {
        Ok(value) if value.get("projects").and_then(Value::as_array).is_some() => value,
        _ => json!({ "format": 1, "projects": [] }),
    }
}

fn write_pretty_json(path: &Path, value: &Value) -> Result<(), CliError> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).map_err(|error| io_err(parent, error))?;
    }
    let mut text = serde_json::to_string_pretty(value).map_err(|error| {
        CliError::new(
            "PROJECT_IO",
            format!("could not encode JSON for {}: {error}", path.display()),
        )
    })?;
    text.push('\n');
    let tmp = path.with_file_name(format!(
        "{}.tmp",
        path.file_name()
            .unwrap_or_else(|| std::ffi::OsStr::new("creator-projects.json"))
            .to_string_lossy()
    ));
    {
        let mut file = fs::File::create(&tmp).map_err(|error| io_err(&tmp, error))?;
        file.write_all(text.as_bytes())
            .map_err(|error| io_err(&tmp, error))?;
        file.sync_all().map_err(|error| io_err(&tmp, error))?;
    }
    fs::rename(&tmp, path).map_err(|error| {
        let _ = fs::remove_file(&tmp);
        io_err(path, error)
    })?;
    Ok(())
}

fn same_path(existing: &str, path: &Path) -> bool {
    let existing = Path::new(existing);
    if let (Ok(left), Ok(right)) = (fs::canonicalize(existing), fs::canonicalize(path)) {
        return left == right;
    }
    absolute_path(existing) == absolute_path(path)
}

fn absolute_path(path: &Path) -> PathBuf {
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        env::current_dir()
            .map(|cwd| cwd.join(path))
            .unwrap_or_else(|_| path.to_path_buf())
    }
}

fn path_string(path: &Path) -> String {
    path.to_string_lossy().into_owned()
}

fn io_err(path: &Path, source: io::Error) -> CliError {
    CliError::new(
        "PROJECT_IO",
        format!("could not access {}: {source}", path.display()),
    )
}
