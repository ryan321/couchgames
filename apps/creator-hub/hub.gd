extends Control
const Projects = preload("res://projects.gd")
# Shared studio tokens: navy studio, mint focus.
const BG := Color("101722")
const PANEL := Color("192331")
const BORDER := Color("2d3b4b")
const INK := Color("f2f5f8")
const MUTED := Color("a0afbf")
const MINT := Color("8ce8be")
var kit_root: String
var recent: VBoxContainer
var message: Label
var title_input: LineEdit
var location: LineEdit
var template_kind := "3d-couch"
var dialog: ConfirmationDialog
var picker: FileDialog
var config := ConfigFile.new()
var display_font: Font

func _ready() -> void:
	kit_root = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	config.load("user://projects.cfg")
	theme = Theme.new()
	var inter := load("res://fonts/Inter.ttf")
	if inter:
		theme.default_font = inter
	display_font = load("res://fonts/SpaceGrotesk.ttf")
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,40)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	margin.add_child(column)
	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 12)
	var mark := TextureRect.new()
	mark.texture = load("res://mark.png")
	mark.custom_minimum_size = Vector2(40, 40)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brand.add_child(mark)
	brand.add_child(label("GIGA COUCH     /     CREATOR PREVIEW",13,MINT,true))
	column.add_child(brand)
	column.add_child(label("Your next game starts here.",36,INK,true))
	column.add_child(label("Start with a small world. Make it yours in Godot. Play together.",18,MUTED))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",14)
	column.add_child(actions)
	actions.add_child(button("+  New 3D game",new_project,true))
	actions.add_child(button("+  New 2D game",new_project_2d,true))
	actions.add_child(button("Open existing project",open_project))
	actions.add_child(button("First-game guide",func(): open_kit_doc("index.html")))
	var guides := HBoxContainer.new()
	guides.add_theme_constant_override("separation",14)
	column.add_child(guides)
	guides.add_child(button("How to talk about games",func(): open_kit_doc("terminology.md")))
	guides.add_child(button("Asset sources for your AI",func(): open_kit_doc("asset_source_guide.md")))
	var divider := ColorRect.new()
	divider.color = BORDER
	divider.custom_minimum_size = Vector2(0, 1)
	column.add_child(divider)
	column.add_child(label("RECENT PROJECTS",13,MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	recent = VBoxContainer.new()
	recent.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recent.add_theme_constant_override("separation",12)
	scroll.add_child(recent)
	message = label("",15,MINT)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(message)
	column.add_child(label("3D starter · 1–16 local player slots · Godot "+Engine.get_version_info().string,13,MUTED))
	column.add_child(label("Local development preview. Packaging and private sharing are still being built.",13,MUTED))
	build_dialogs()
	refresh()
	actions.get_child(0).grab_focus()

func label(text: String, size: int, color := INK, display := false) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size",size)
	item.add_theme_color_override("font_color",color)
	if display and display_font:
		item.add_theme_font_override("font", display_font)
	return item

func style(color: Color, border := Color.TRANSPARENT, radius := 10, width := 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.border_color = border
	box.set_border_width_all(width)
	return box

func pop(item: Control, target: Vector2) -> void:
	if item.has_meta("pop_tween"):
		var old: Tween = item.get_meta("pop_tween")
		if old.is_running():
			old.kill()
	item.pivot_offset = item.size * 0.5
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "scale", target, 0.18)
	item.set_meta("pop_tween", tween)

func button(text: String, callback: Callable, primary := false) -> Button:
	var item := Button.new()
	item.text = text
	item.custom_minimum_size = Vector2(0,48)
	item.add_theme_font_size_override("font_size",17)
	if primary:
		item.add_theme_stylebox_override("normal", style(MINT))
		item.add_theme_stylebox_override("hover", style(MINT.lightened(0.08)))
		item.add_theme_stylebox_override("pressed", style(MINT.darkened(0.1)))
		item.add_theme_stylebox_override("disabled", style(BORDER))
		item.add_theme_stylebox_override("focus", style(MINT, INK, 10, 2))
		item.add_theme_color_override("font_color", BG)
		item.add_theme_color_override("font_hover_color", BG)
		item.add_theme_color_override("font_pressed_color", BG)
		item.add_theme_color_override("font_focus_color", BG)
		item.add_theme_color_override("font_disabled_color", MUTED)
	else:
		item.add_theme_stylebox_override("normal", style(PANEL, BORDER, 10, 1))
		item.add_theme_stylebox_override("hover", style(PANEL.lightened(0.06), MINT, 10, 1))
		item.add_theme_stylebox_override("pressed", style(PANEL.darkened(0.06), MINT, 10, 1))
		item.add_theme_stylebox_override("disabled", style(PANEL, BORDER, 10, 1))
		item.add_theme_stylebox_override("focus", style(PANEL, MINT, 10, 2))
		item.add_theme_color_override("font_color", INK)
		item.add_theme_color_override("font_hover_color", INK)
		item.add_theme_color_override("font_focus_color", INK)
		item.add_theme_color_override("font_disabled_color", MUTED)
	item.focus_entered.connect(func(): pop(item, Vector2(1.03, 1.03)))
	item.focus_exited.connect(func(): pop(item, Vector2.ONE))
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
	var note := label("Includes the SDK and an editable Little World starter.\nExisting folders are never replaced.",14,MUTED)
	body.add_child(note)
	dialog.confirmed.connect(create_project)
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.use_native_dialog = true
	add_child(picker)

func new_project() -> void:
	template_kind = "3d-couch"
	title_input.text = ""
	dialog.popup_centered(Vector2i(560,300))
	title_input.grab_focus()

func new_project_2d() -> void:
	template_kind = "2d-couch"
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
	var result := Projects.create(kit_root.path_join("templates").path_join(template_kind),location.text,title_input.text)
	if result.has("error"):
		message.text = result.error
		return
	remember(result.path)
	message.text = "Project created and added to Giga Couch. Reopen Giga Couch to play it on the TV. Agents: open the folder and read AGENTS.md."

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
	Projects.register(path)
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
		recent.add_child(label("No projects yet. Create a game or open one you already own.",18,MUTED))
	for value in paths:
		if not value is String: continue
		var path: String = value
		var card := PanelContainer.new()
		var card_style := style(PANEL, BORDER, 12, 1)
		card_style.content_margin_left = 16
		card_style.content_margin_right = 16
		card_style.content_margin_top = 12
		card_style.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", card_style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",12)
		card.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := label(path.get_file(),20)
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		details.add_child(name_label)
		var path_label := label(path,12,MUTED)
		path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		details.add_child(path_label)
		row.add_child(details)
		row.add_child(button("Open in Godot",func(): launch(path,true)))
		row.add_child(button("Play",func(): launch(path,false),true))
		row.add_child(button("Show folder",func(): OS.shell_show_in_file_manager(path)))
		recent.add_child(card)

func open_kit_doc(filename: String) -> void:
	for folder in [kit_root.path_join("docs"), kit_root.get_base_dir().path_join("docs")]:
		var path: String = folder.path_join(filename)
		if FileAccess.file_exists(path):
			OS.shell_open(path)
			return
	message.text = "That guide is missing from this kit. Reinstall the GDK or open docs in the Giga Couch checkout."

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
