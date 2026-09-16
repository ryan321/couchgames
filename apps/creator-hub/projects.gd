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
			config.set_value("application","config/custom_user_dir_name","CouchGames/Projects/"+safe+"-"+str(Time.get_unix_time_from_system()).replace(".","-"))
			error = config.save(stage.path_join("project.godot"))
	if error==OK: error = DirAccess.rename_absolute(stage,target)
	if error!=OK:
		remove_tree(stage)
		return {"error":"Project creation failed (%s). Your existing projects were preserved."%error_string(error)}
	return {"path":target}

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
