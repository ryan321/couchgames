extends Control
## Menu and match HUD. Address entry is the LAN prototype; discovery comes later.

const NAVY := Color("192331")
const MINT := Color("8ce8be")
const INK := Color("f2f5f8")
const MUTED := Color("a0afbf")
const PANEL := Color("101722")

var game: Node3D
var menu: VBoxContainer
var join_field: LineEdit
var status_label: Label
var font: Font = ThemeDB.fallback_font
var paused_local := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	add_child(menu)
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	if menu == null:
		return
	menu.position = Vector2(size.x * 0.08, size.y * 0.28)
	menu.size = Vector2(minf(520, size.x * 0.42), 0)
	queue_redraw()


func show_menu() -> void:
	paused_local = false
	_clear_menu()
	_title("HAYMAKER")
	_note("A colorful last-one-standing brawl. Host on one computer; every other player brings their own screen.")
	var first := _button("PRACTICE  →", game.start_practice, true)
	_button("HOST LAN MATCH", game.host_lan)
	join_field = LineEdit.new()
	join_field.placeholder_text = "Host address (192.168.x.x)"
	join_field.text = game.join_address
	join_field.custom_minimum_size.y = 48
	join_field.add_theme_font_size_override("font_size", 18)
	join_field.add_theme_color_override("font_color", INK)
	join_field.add_theme_color_override("font_placeholder_color", MUTED)
	var field_style := _style(NAVY, BORDER_COLOR())
	join_field.add_theme_stylebox_override("normal", field_style)
	join_field.add_theme_stylebox_override("focus", _style(NAVY, MINT))
	join_field.text_changed.connect(func(value: String): game.join_address = value)
	menu.add_child(join_field)
	_button("JOIN LAN MATCH", game.join_lan)
	_button("RETURN TO LIBRARY", game.quit_game)
	status_label = _note(game.banner)
	menu.visible = true
	first.grab_focus()
	_layout()


func show_waiting() -> void:
	paused_local = false
	_clear_menu()
	_title("WAITING ROOM")
	var addresses: PackedStringArray = game.session.local_addresses()
	var host_line := "This computer is the host. Others join %s:%d" % [
		addresses[0] if addresses.size() else "this computer", game.session.port]
	if game.mode == "client":
		host_line = "Connected to the host. Waiting for the match to start."
	_note(host_line)
	status_label = _note(game.waiting_summary())
	if game.mode == "host":
		_button("START MATCH  →", game.request_start, true)
	_button("LEAVE SESSION", game.leave_session)
	menu.visible = true
	_layout()


func show_pause() -> void:
	paused_local = true
	_clear_menu()
	_title("PAUSED")
	_note("Only this screen is paused. The rest of the match keeps running on the host.")
	var first := _button("RESUME  →", game.resume_local, true)
	_button("LEAVE MATCH", game.leave_session)
	_button("RETURN TO LIBRARY", game.quit_game)
	menu.visible = true
	first.grab_focus()
	_layout()


func show_results() -> void:
	paused_local = false
	_clear_menu()
	_title(game.result_title())
	_note(game.result_detail())
	var first := _button("BACK TO MENU  →", game.return_to_menu, true)
	_button("RETURN TO LIBRARY", game.quit_game)
	menu.visible = true
	first.grab_focus()
	_layout()


func hide_menu() -> void:
	paused_local = false
	menu.visible = false
	_clear_menu()
	queue_redraw()


func refresh_waiting() -> void:
	if game.phase == "waiting" and status_label:
		status_label.text = game.waiting_summary()


func _clear_menu() -> void:
	for child in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	join_field = null
	status_label = null


func _title(text: String) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", 40)
	node.add_theme_color_override("font_color", INK)
	menu.add_child(node)
	return node


func _note(text: String) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", 16)
	node.add_theme_color_override("font_color", MUTED)
	menu.add_child(node)
	return node


func _button(text: String, action: Callable, primary := false) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 54
	node.add_theme_font_size_override("font_size", 20)
	for color_state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		node.add_theme_color_override(color_state, PANEL if primary else INK)
	for state in ["normal", "hover", "focus", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = MINT if primary else NAVY
		if state in ["hover", "focus"]:
			style.bg_color = style.bg_color.lightened(0.08)
			style.set_border_width_all(2)
			style.border_color = INK if primary else MINT
		style.set_corner_radius_all(10)
		node.add_theme_stylebox_override(state, style)
	node.pressed.connect(action)
	menu.add_child(node)
	return node


func BORDER_COLOR() -> Color:
	return Color("2d3b4b")


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	return style


func _unhandled_input(event: InputEvent) -> void:
	if not paused_local:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		game.resume_local()
		get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		game.resume_local()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if game == null:
		return
	if game.phase == "playing" and not paused_local:
		_draw_play()
	elif game.phase in ["menu", "waiting", "results"] or paused_local:
		draw_rect(Rect2(Vector2.ZERO, size), Color(PANEL.r, PANEL.g, PANEL.b, 0.55))


func _draw_play() -> void:
	var local: CharacterBody3D = game.local_fighter()
	if local == null:
		return
	draw_string(font, Vector2(48, 48), "HAYMAKER", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK)
	draw_string(font, Vector2(48, 78), "%d standing  ·  ring %.0fm" % [game.alive_count(), game.ring_radius],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)
	_bar(Vector2(48, 100), local.health / 100.0, Color("e36b6b"))
	_bar(Vector2(48, 122), local.armor / 80.0, Color("6ec8d3"))
	var weapon := "Fists"
	if local.weapon == "bat":
		weapon = "Bat  %.0fs" % local.weapon_left
	draw_string(font, Vector2(48, 158), weapon, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MINT)
	if not local.alive:
		draw_string(font, Vector2(size.x * 0.5 - 80, size.y * 0.45), "YOU'RE OUT", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color("ffcf8b"))


func _bar(at: Vector2, amount: float, color: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = NAVY
	box.set_corner_radius_all(6)
	draw_style_box(box, Rect2(at, Vector2(280, 16)))
	if amount > 0.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = color
		fill.set_corner_radius_all(6)
		draw_style_box(fill, Rect2(at, Vector2(280.0 * clampf(amount, 0.0, 1.0), 16)))
