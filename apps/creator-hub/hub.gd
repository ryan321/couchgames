extends Control
const Projects = preload("res://projects.gd")
var kit_root: String
var recent: VBoxContainer
var message: Label
var title_input: LineEdit
var location: LineEdit
var dialog: ConfirmationDialog
var picker: FileDialog
var config := ConfigFile.new()

func _ready() -> void:
	kit_root = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	config.load("user://projects.cfg")
	var background := ColorRect.new()
	background.color = Color("101d28")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,40)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	margin.add_child(column)
	column.add_child(label("GIGA COUCH     /     CREATOR PREVIEW",13,Color("8bd8bb")))
	column.add_child(label("Your next game starts here.",36))
	column.add_child(label("Start with a small world. Make it yours in Godot. Play together.",18,Color("acbac7")))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",14)
	column.add_child(actions)
	actions.add_child(button("+  New 3D game",new_project))
	actions.add_child(button("Open existing project",open_project))
	actions.add_child(button("First-game guide",func(): OS.shell_open(kit_root.path_join("docs/index.html"))))
	column.add_child(HSeparator.new())
	column.add_child(label("RECENT PROJECTS",13,Color("acbac7")))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	recent = VBoxContainer.new()
	recent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recent.add_theme_constant_override("separation",12)
	scroll.add_child(recent)
	message = label("",15,Color("8bd8bb"))
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	column.add_child(label("3D starter · 1–16 local player slots · Godot "+Engine.get_version_info().string,13,Color("acbac7")))
	column.add_child(label("Local development preview. Packaging and private sharing are still being built.",13,Color("acbac7")))
	build_dialogs()
	refresh()
	actions.get_child(0).grab_focus()

func label(text: String, size: int, color := Color("f1f5f7")) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",color)
	return item

func button(text: String, callback: Callable) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size = Vector2(0,48)
	item.add_theme_font_size_override("font_size",17)
	item.pressed.connect(callback)
	return item

func build_dialogs() -> void:
	dialog = ConfirmationDialog.new()
	dialog.title = "Create a 3D game"
	dialog.ok_button_text = "Create project"
	add_child(dialog)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation",12)
	dialog.add_child(body)
	body.add_child(label("Game name",16))
	title_input = LineEdit.new()
	title_input.placeholder_text = "My first game"
	body.add_child(title_input)
	body.add_child(label("Create inside this folder",16))
	location = LineEdit.new()
	location.text = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	body.add_child(location)
	body.add_child(button("Choose folder…",choose_folder))
	var note := label("Includes the SDK and an editable Little World starter.\nExisting folders are never replaced.",14)
	body.add_child(note)
	dialog.confirmed.connect(create_project)
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.use_native_dialog = true
	add_child(picker)

func new_project() -> void:
	title_input.text = ""
	dialog.popup_centered(Vector2i(560,300))
	title_input.grab_focus()

func choose_folder() -> void:
	picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	picker.clear_filters()
	if not picker.dir_selected.is_connected(folder_selected): picker.dir_selected.connect(folder_selected)
	picker.popup_centered_ratio(.7)

func folder_selected(path: String) -> void: location.text = path

func create_project() -> void:
	var result := Projects.create(kit_root.path_join("templates/3d-couch"),location.text,title_input.text)
	if result.has("error"):
		message.text = result.error
		return
	remember(result.path)
	message.text = "Project created. Open it in Godot to edit, or play it now."

func open_project() -> void:
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.clear_filters()
	picker.add_filter("project.godot","Godot project")
	if not picker.file_selected.is_connected(project_selected): picker.file_selected.connect(project_selected)
	picker.popup_centered_ratio(.7)

func project_selected(path: String) -> void:
	if path.get_file()!="project.godot":
		message.text = "Choose a project.godot file."
		return
	remember(path.get_base_dir())

func remember(path: String) -> void:
	var paths: Array = config.get_value("projects","recent",[])
	paths.erase(path)
	paths.push_front(path)
	if paths.size()>12: paths.resize(12)
	config.set_value("projects","recent",paths)
	var error := config.save("user://projects.cfg")
	refresh()
	if error!=OK: message.text = "Project is available, but the recent-project list could not be saved."

func refresh() -> void:
	for child in recent.get_children(): recent.remove_child(child); child.queue_free()
	var paths: Array = config.get_value("projects","recent",[])
	if paths.is_empty():
		recent.add_child(label("No projects yet. Create a game or open one you already own.",18,Color("acbac7")))
	for value in paths:
		if not value is String: continue
		var path: String = value
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := label(path.get_file(),20)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		details.add_child(name_label)
		var path_label := label(path,12,Color("acbac7"))
		path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		details.add_child(path_label)
		row.add_child(details)
		row.add_child(button("Open in Godot",func(): launch(path,true)))
		row.add_child(button("Play",func(): launch(path,false)))
		recent.add_child(row)

func launch(path: String, editor: bool) -> void:
	if not FileAccess.file_exists(path.path_join("project.godot")):
		message.text = "This project was moved or removed. Open it from its new location."
		return
	# Editor mode performs the first import. Source play is available after that import.
	if not editor and not DirAccess.dir_exists_absolute(path.path_join(".godot")):
		message.text = "Open this new project in Godot once to import its resources, then press Play."
		return
	var args := PackedStringArray(["--path",path])
	if editor: args.append("--editor")
	var pid := OS.create_process(OS.get_executable_path(),args)
	message.text = "Opened in Godot." if pid>0 else "Godot could not start. Reopen setup and check the selected editor."
