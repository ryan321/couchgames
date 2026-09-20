extends CanvasLayer
## Start/Esc pause. F11 stays with the game.

const NAVY := Color("192331")
const PANEL := Color("101722")
const MINT := Color("8ce8be")

var panel: Control
var resume_button: Button
var quit_button: Button


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 128
	name = "PauseOverlay"


func _ready() -> void:
	_build()
	panel.visible = false


func _input(event: InputEvent) -> void:
	if panel == null or not is_instance_valid(panel):
		return
	if event is InputEventKey and event.keycode == KEY_F11:
		return
	if not panel.visible and not _is_toggle(event):
		return
	if _is_toggle(event):
		_set_paused(not get_tree().paused)
		get_viewport().set_input_as_handled()


func _is_toggle(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_ESCAPE
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == JOY_BUTTON_START
	return false


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	panel.visible = paused
	if paused and is_instance_valid(resume_button):
		resume_button.grab_focus()


func _quit() -> void:
	var platform := get_parent()
	if platform == null or not platform.has_method("quit_to_platform"):
		platform = get_node_or_null("/root/Platform")
	if platform:
		platform.quit_to_platform()


func _build() -> void:
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var dimmer := ColorRect.new()
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(PANEL.r, PANEL.g, PANEL.b, 0.78)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(dimmer)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(center)
	var box := PanelContainer.new()
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = NAVY
	box_style.border_color = MINT
	box_style.set_border_width_all(2)
	box_style.set_corner_radius_all(16)
	box_style.set_content_margin_all(28)
	box.add_theme_stylebox_override("panel", box_style)
	center.add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	box.add_child(column)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", MINT)
	column.add_child(title)
	resume_button = _button("Resume")
	resume_button.pressed.connect(func() -> void: _set_paused(false))
	column.add_child(resume_button)
	quit_button = _button("Quit to library")
	quit_button.pressed.connect(_quit)
	column.add_child(quit_button)


func _button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360, 52)
	button.add_theme_font_size_override("font_size", 26)
	button.add_theme_color_override("font_color", MINT)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("142b28")
	normal.set_corner_radius_all(8)
	normal.set_content_margin_all(12)
	button.add_theme_stylebox_override("normal", normal)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = MINT
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("hover", focus)
	return button
