extends Control
## Couch-first menu: A / Cross confirms the highlighted action.

const NAVY := Color("192331")
const MINT := Color("8ce8be")
const INK := Color("f2f5f8")
const MUTED := Color("a0afbf")
const PANEL := Color("101722")

var game: Node3D
var menu: VBoxContainer
var join_field: LineEdit
var status_label: Label
var address_label: Label
var font: Font = ThemeDB.fallback_font
var paused_local := false
var choices: Array[Button] = []
var choice_index := 0
var _stick_ready := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	add_child(menu)
	resized.connect(_layout)
	_layout()


func _process(_delta: float) -> void:
	if not menu.visible:
		return
	var axis := 0.0
	for device in Input.get_connected_joypads():
		axis = Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		if absf(axis) > 0.55:
			break
	if absf(axis) <= 0.45:
		_stick_ready = true
		return
	if not _stick_ready:
		return
	_stick_ready = false
	_move_choice(1 if axis > 0.0 else -1)


func _layout() -> void:
	if menu == null:
		return
	menu.position = Vector2(size.x * 0.08, size.y * 0.22)
	menu.size = Vector2(minf(560, size.x * 0.46), 0)
	queue_redraw()


func show_menu() -> void:
	paused_local = false
	_clear_menu()
	_title("HAYMAKER")
	_note("A colorful last-one-standing brawl. Host on one computer; every other player brings a screen.")
	address_label = _note(_address_blurb())
	_button("PRACTICE  →", game.start_practice, true)
	_button("HOST LAN MATCH", game.host_lan)
	join_field = LineEdit.new()
	join_field.placeholder_text = "Other computer's LAN address"
	join_field.text = game.join_address
	join_field.custom_minimum_size.y = 48
	join_field.focus_mode = Control.FOCUS_CLICK
	join_field.add_theme_font_size_override("font_size", 18)
	join_field.add_theme_color_override("font_color", INK)
	join_field.add_theme_color_override("font_placeholder_color", MUTED)
	join_field.add_theme_stylebox_override("normal", _style(NAVY, Color("2d3b4b")))
	join_field.add_theme_stylebox_override("focus", _style(NAVY, MINT))
	join_field.text_changed.connect(func(value: String): game.join_address = value)
	menu.add_child(join_field)
	_button("JOIN LAN MATCH", game.join_lan)
	_button("RETURN TO LIBRARY", game.quit_game)
	status_label = _note(game.banner)
	_note("A / Cross confirms. D-pad or left stick moves.")
	menu.visible = true
	_select(0)
	_layout()


func show_waiting() -> void:
	paused_local = false
	_clear_menu()
	_title("WAITING ROOM")
	address_label = _note(_waiting_address())
	status_label = _note(game.waiting_summary())
	if game.mode == "host":
		_button("START MATCH  →", game.request_start, true)
	_button("LEAVE SESSION", game.leave_session)
	_note("A / Cross confirms.")
	menu.visible = true
	_select(0)
	_layout()


func show_pause() -> void:
	paused_local = true
	_clear_menu()
	_title("PAUSED")
	_note("Only this screen is paused. The rest of the match keeps running on the host.")
	_button("RESUME  →", game.resume_local, true)
	_button("LEAVE MATCH", game.leave_session)
	_button("RETURN TO LIBRARY", game.quit_game)
	menu.visible = true
	_select(0)
	_layout()


func show_results() -> void:
	paused_local = false
	_clear_menu()
	_title(game.result_title())
	_note(game.result_detail())
	_button("PLAY AGAIN  →", game.play_again, true)
	_button("BACK TO MENU", game.return_to_menu)
	_button("RETURN TO LIBRARY", game.quit_game)
	_note("A / Cross plays again. D-pad or left stick moves.")
	menu.visible = true
	_select(0)
	_layout()


func hide_menu() -> void:
	paused_local = false
	menu.visible = false
	_clear_menu()
	queue_redraw()


func refresh_waiting() -> void:
	if game.phase == "waiting" and status_label:
		status_label.text = game.waiting_summary()
	if game.phase == "waiting" and address_label:
		address_label.text = _waiting_address()


func _address_blurb() -> String:
	var addresses: PackedStringArray = game.session.local_addresses()
	if addresses.is_empty():
		return "No LAN address yet. Connect this computer to Wi-Fi, then reopen Haymaker."
	return "This computer: %s   ·   others join that address on port %d" % [", ".join(addresses), game.session.port]


func _waiting_address() -> String:
	if game.mode == "client":
		return "Connected to the host. Waiting for the match to start."
	var addresses: PackedStringArray = game.session.local_addresses()
	if addresses.is_empty():
		return "No LAN IPv4 address found. Other computers cannot join until this machine has a 192.168 / 10.x Wi-Fi address."
	return "Others join  %s:%d" % [addresses[0], game.session.port]


func _clear_menu() -> void:
	for child in menu.get_children():
		menu.remove_child(child)
		child.queue_free()
	join_field = null
	status_label = null
	address_label = null
	choices.clear()
	choice_index = 0


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
	node.focus_mode = Control.FOCUS_ALL
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
	var index := choices.size()
	node.pressed.connect(action)
	node.focus_entered.connect(func(): choice_index = index)
	menu.add_child(node)
	choices.append(node)
	return node


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	return style


func _move_choice(step: int) -> void:
	if choices.is_empty():
		return
	_select(posmod(choice_index + step, choices.size()))


func _select(index: int) -> void:
	if choices.is_empty():
		return
	choice_index = clampi(index, 0, choices.size() - 1)
	choices[choice_index].grab_focus()


func _activate_choice() -> void:
	if choice_index < 0 or choice_index >= choices.size():
		return
	choices[choice_index].pressed.emit()


func _input(event: InputEvent) -> void:
	if _handle_menu_event(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	_handle_menu_event(event)


func _handle_menu_event(event: InputEvent) -> bool:
	if paused_local:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			game.resume_local()
			return true
		if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
			game.resume_local()
			return true
	if not menu.visible:
		return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_UP, KEY_W]:
			_move_choice(-1)
			return true
		if event.keycode in [KEY_DOWN, KEY_S]:
			_move_choice(1)
			return true
		if event.keycode in [KEY_ENTER, KEY_SPACE]:
			_activate_choice()
			return true
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_UP:
			_move_choice(-1)
			return true
		if event.button_index == JOY_BUTTON_DPAD_DOWN:
			_move_choice(1)
			return true
		if event.button_index in [JOY_BUTTON_A, JOY_BUTTON_X]:
			if game.has_method("claim_local_device"):
				game.claim_local_device(event.device)
			_activate_choice()
			return true
	return false


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
	draw_string(font, Vector2(48, size.y - 80), "A strike combo   ·   Y grab / slam   ·   LT dash   ·   RT block",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)
	draw_string(font, Vector2(48, size.y - 58), "B dodge   ·   RB jump   ·   dash+A dropkick   ·   jump+A elbow drop",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 16, MUTED)
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
