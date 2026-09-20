extends RefCounted
## Local source projects only. Never overwrite an existing project or invoke a shell.

static func create(template: String, parent: String, title: String) -> Dictionary:
	title = title.strip_edges()
	if title.is_empty() or title.length()>80:
		return {"error":"Give your game a name between 1 and 80 characters."}
	var folder := title.to_lower().replace(" ","-")
	var safe := ""
	for character in folder:
		if character in "abcdefghijklmnopqrstuvwxyz0123456789-_": safe += character
	if safe.is_empty(): safe = "my-game"
	if not DirAccess.dir_exists_absolute(parent): return {"error":"Choose an existing folder for your game."}
	var target := parent.path_join(safe)
	if FileAccess.file_exists(target) or DirAccess.dir_exists_absolute(target):
		return {"error":"That project folder already exists. Choose another name or location; no files were replaced."}
	var stage := parent.path_join(".couch-new-"+str(Time.get_ticks_usec()))
	var error := DirAccess.make_dir_absolute(stage)
	if error!=OK: return {"error":"Cannot create a project in this folder. Choose another location."}
	error = copy_tree(template,stage)
	if error==OK:
		var config := ConfigFile.new()
		error = config.load(stage.path_join("project.godot"))
		if error==OK:
			config.set_value("application","config/name",title)
			config.set_value("application","config/use_custom_user_dir",true)
			config.set_value("application","config/custom_user_dir_name","GigaCouch/Projects/"+safe+"-"+str(Time.get_unix_time_from_system()).replace(".","-"))
			error = config.save(stage.path_join("project.godot"))
	if error==OK: error = write_game_file(stage,safe,title)
	if error==OK: ensure_agents(template,stage)
	if error==OK: ensure_docs(template,stage)
	if error==OK: error = DirAccess.rename_absolute(stage,target)
	if error!=OK:
		remove_tree(stage)
		return {"error":"Project creation failed (%s). Your existing projects were preserved."%error_string(error)}
	register(target)
	return {"path":target}

static func write_game_file(project: String, slug: String, title: String) -> Error:
	var game := {}
	var game_path := project.path_join("couch.game.json")
	if FileAccess.file_exists(game_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(game_path))
		if parsed is Dictionary:
			game = parsed
	game["format"] = 1
	game["id"] = slug
	game["title"] = title
	if not (game.get("scene") is String) or not str(game.scene).begins_with("res://"):
		game["scene"] = "res://examples/little_world/world.tscn"
	if not (game.get("players") is String):
		game["players"] = "1–16 players"
	if not (game.get("description") is String):
		game["description"] = "A Giga Couch 3D starter. Join with A / Cross."
	if not (game.get("color") is String):
		game["color"] = "8ce8be"
	var file := FileAccess.open(game_path, FileAccess.WRITE)
	if file == null:
		return ERR_FILE_CANT_WRITE
	file.store_string(JSON.stringify(game, "  ") + "\n")
	file.close()
	return OK

static func ensure_agents(template: String, project: String) -> void:
	var dest := project.path_join("AGENTS.md")
	if FileAccess.file_exists(dest):
		return
	var source := template.path_join("AGENTS.md")
	if FileAccess.file_exists(source):
		DirAccess.copy_absolute(source, dest)

static func ensure_docs(template: String, project: String) -> void:
	var dest := project.path_join("docs")
	if not DirAccess.dir_exists_absolute(dest):
		DirAccess.make_dir_absolute(dest)
	for filename in ["asset_source_guide.md", "terminology.md"]:
		var target := dest.path_join(filename)
		if FileAccess.file_exists(target):
			continue
		var source := template.path_join("docs").path_join(filename)
		if not FileAccess.file_exists(source):
			source = template.get_base_dir().get_base_dir().path_join("docs").path_join(filename)
		if FileAccess.file_exists(source):
			DirAccess.copy_absolute(source, target)

static func registry_path() -> String:
	var override := OS.get_environment("COUCH_CREATOR_PROJECTS")
	if not override.is_empty():
		return override
	var home := OS.get_environment("HOME")
	if OS.get_name() == "macOS":
		return home.path_join("Library/Application Support/GigaCouch/creator-projects.json")
	return home.path_join(".local/share/GigaCouch/creator-projects.json")

static func same_path(left: String, right: String) -> bool:
	return left.simplify_path().trim_suffix("/") == right.simplify_path().trim_suffix("/")

static func register(project: String) -> void:
	project = project.simplify_path()
	if not FileAccess.file_exists(project.path_join("project.godot")):
		return
	var slug := project.get_file()
	var title := project.get_file()
	var game_path := project.path_join("couch.game.json")
	if FileAccess.file_exists(game_path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(game_path))
		if parsed is Dictionary:
			if str(parsed.get("id", "")) != "":
				slug = str(parsed.id)
			if str(parsed.get("title", "")) != "":
				title = str(parsed.title)
	var path := registry_path()
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return
	var projects: Array = []
	if FileAccess.file_exists(path):
		var existing = JSON.parse_string(FileAccess.get_file_as_string(path))
		if existing is Dictionary and existing.get("projects") is Array:
			for row in existing.projects:
				if row is Dictionary and not same_path(str(row.get("path", "")), project):
					projects.append(row)
		else:
			return
	projects.insert(0, {"id": slug, "title": title, "path": project})
	if projects.size() > 32:
		projects.resize(32)
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify({"format": 1, "projects": projects}, "  ") + "\n")
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	DirAccess.rename_absolute(temporary, path)

static func copy_tree(source: String, target: String) -> Error:
	var directory := DirAccess.open(source)
	if directory==null: return ERR_FILE_NOT_FOUND
	for filename in directory.get_files():
		if directory.is_link(filename): return ERR_INVALID_DATA
		var error := DirAccess.copy_absolute(source.path_join(filename),target.path_join(filename))
		if error!=OK: return error
	for folder in directory.get_directories():
		if folder in [".godot",".git"]: continue
		if directory.is_link(folder): return ERR_INVALID_DATA
		var path := target.path_join(folder)
		var error := DirAccess.make_dir_absolute(path)
		if error!=OK: return error
		error = copy_tree(source.path_join(folder),path)
		if error!=OK: return error
	return OK

static func remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory==null: return
	for file in directory.get_files(): DirAccess.remove_absolute(path.path_join(file))
	for folder in directory.get_directories():
		var child := path.path_join(folder)
		if directory.is_link(folder): DirAccess.remove_absolute(child)
		else: remove_tree(child)
	DirAccess.remove_absolute(path)
