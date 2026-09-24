extends Control
const Cover = preload("res://launcher/cover.gd")
# Same tokens as GDK Setup (StudioStyle): navy studio, mint focus, TV-sized type.
const BG := Color("101722")
const PANEL := Color("192331")
const BORDER := Color("2d3b4b")
const INK := Color("f2f5f8")
const MUTED := Color("a0afbf")
const MINT := Color("8ce8be")
const FOOTER := Color("142b28")
var games: Array = []
var cards: Array[Button] = []
var game_scroll: ScrollContainer
var controller: OptionButton
var joycons: OptionButton
var status: Label
var stop_button: Button
var profile_button: OptionButton
var info_button: Button
var refresh_button: Button
var settings_button: Button
var hint_label: Label
var ready_pill: Panel
var worlds_label: Label
var details_layer: Control
var settings_layer: Control
var details_box: Control
var details_title: Label
var details_body: Label
var details_meta: Label
var session := ""
var busy := false
var selected := 0
var catalog_revision := 0
var shelf: Control
var card_w := 598
var card_h := 164
var card_gap := 14
var _phase := ""
var _poll := 0.0
var _requested_at := 0.0
var _request_id := ""
var _cooldown := 0.0
var _focus_tween: Tween
var _overlay_tween: Tween
var display_font: Font

func load_games() -> Array:
	var catalog := OS.get_environment("COUCH_LIBRARY_CATALOG")
	if not catalog.is_empty() and FileAccess.file_exists(catalog):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(catalog))
		if parsed is Array and parsed.size() > 0:
			return parsed
	return JSON.parse_string(FileAccess.get_file_as_string("res://launcher/games.json"))

func _ready() -> void:
	DisplayServer.window_set_title("Giga Couch · Your library")
	games = load_games()
	session = OS.get_environment("COUCH_LIBRARY_SESSION")
	# Library navigation does not join game players or claim motion sensors.
	get_node("/root/Platform").input.set_process_input(false)
	theme = Theme.new()
	theme.default_font_size = 20
	var inter := load("res://launcher/fonts/Inter.ttf")
	if inter:
		theme.default_font = inter
	display_font = load("res://launcher/fonts/SpaceGrotesk.ttf")
	_build()
	cards[0].grab_focus()
	if session.is_empty():
		status.text = "Open with: python3 scripts/library.py"
	_report_ready_after_draw()

func _report_ready_after_draw() -> void:
	var startup := OS.get_environment("COUCH_PLAYER_STARTUP")
	if startup.is_empty() or DisplayServer.get_name() == "headless":
		return
	# Let layout settle and render before dismissing the native loading window.
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	DisplayServer.window_set_title("Giga Couch · Your library")
	var temporary := startup + ".ready"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"phase": "ready"}))
		file.close()
		DirAccess.rename_absolute(temporary, startup)

func mark_at(at: Vector2, size: Vector2, parent: Node = self) -> void:
	var texture := load("res://launcher/mark.png") as Texture2D
	if texture == null:
		return
	var crop := Control.new()
	crop.position = at
	crop.size = size
	crop.custom_minimum_size = size
	crop.clip_contents = true
	crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(crop)
	var view := TextureRect.new()
	view.texture = texture
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crop.add_child(view)

func label_at(text: String, at: Vector2, font_size: int, color := INK, parent: Node = self, display := false) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	if display and display_font:
		label.add_theme_font_override("font", display_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func style(color: Color, border := Color.TRANSPARENT, radius := 16, width := 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.border_color = border
	box.set_border_width_all(width)
	return box

func chrome_button(title: String, primary := false) -> Button:
	var item := Button.new()
	item.text = title
	item.add_theme_font_size_override("font_size", 16)
	if primary:
		item.add_theme_stylebox_override("normal", style(MINT, Color.TRANSPARENT, 9, 0))
		item.add_theme_stylebox_override("hover", style(MINT.lightened(0.08), Color.TRANSPARENT, 9, 0))
		item.add_theme_stylebox_override("pressed", style(MINT.darkened(0.1), Color.TRANSPARENT, 9, 0))
		item.add_theme_stylebox_override("disabled", style(BORDER, Color.TRANSPARENT, 9, 0))
		item.add_theme_stylebox_override("focus", style(MINT, INK, 9, 2))
		item.add_theme_color_override("font_color", BG)
		item.add_theme_color_override("font_hover_color", BG)
		item.add_theme_color_override("font_pressed_color", BG)
		item.add_theme_color_override("font_focus_color", BG)
		item.add_theme_color_override("font_disabled_color", MUTED)
	else:
		item.add_theme_stylebox_override("normal", style(BORDER, Color.TRANSPARENT, 9, 0))
		item.add_theme_stylebox_override("hover", style(BORDER.lightened(0.12), MINT, 9, 1))
		item.add_theme_stylebox_override("pressed", style(PANEL, BORDER, 9, 1))
		item.add_theme_stylebox_override("disabled", style(PANEL, BORDER, 9, 1))
		item.add_theme_stylebox_override("focus", style(BORDER, MINT, 9, 2))
		item.add_theme_color_override("font_color", INK)
		item.add_theme_color_override("font_hover_color", INK)
		item.add_theme_color_override("font_focus_color", INK)
		item.add_theme_color_override("font_disabled_color", MUTED)
	item.mouse_entered.connect(func(): glow(item, true))
	item.mouse_exited.connect(func(): glow(item, false))
	return item

func glow(item: Control, on: bool) -> void:
	if item.has_meta("glow_tween"):
		var old: Tween = item.get_meta("glow_tween")
		if old.is_running():
			old.kill()
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "modulate", Color(1.08, 1.08, 1.08) if on else Color.WHITE, 0.12)
	item.set_meta("glow_tween", tween)

func paint_option(button: OptionButton) -> void:
	button.add_theme_stylebox_override("normal", style(PANEL, BORDER, 9, 1))
	button.add_theme_stylebox_override("hover", style(PANEL.lightened(0.06), MINT, 9, 1))
	button.add_theme_stylebox_override("pressed", style(PANEL, MINT, 9, 1))
	button.add_theme_stylebox_override("disabled", style(PANEL, BORDER, 9, 1))
	button.add_theme_stylebox_override("focus", style(PANEL, MINT, 9, 2))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_font_size_override("font_size", 16)

func pill_at(text: String, at: Vector2, accent: Color, parent: Node = self) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := Color(accent.r, accent.g, accent.b, 0.14)
	panel.add_theme_stylebox_override("panel", style(fill, Color.TRANSPARENT, 12, 0))
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", accent)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 11
	label.offset_right = -11
	panel.add_child(label)
	panel.size = Vector2(maxf(88, text.length() * 8.2 + 24), 26)
	parent.add_child(panel)
	return panel

func _build() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var rail := preload("res://launcher/studio_rail.gd").new()
	rail.position = Vector2.ZERO
	rail.size = Vector2(300, 900)
	add_child(rail)
	mark_at(Vector2(28, 28), Vector2(64, 64), rail)
	var left := 336.0
	label_at("YOUR LIBRARY", Vector2(left, 28), 12, MINT)
	label_at("Tonight, we play.", Vector2(left, 48), 38, INK, self, true)
	label_at("Pick a world. Grab a controller. Make room on the couch.", Vector2(left, 98), 16, MUTED)
	ready_pill = pill_at("%d OF %d READY" % [games.size(), games.size()], Vector2(left, 130), MINT)
	worlds_label = label_at("%02d  WORLDS" % games.size(), Vector2(1288, 134), 13, MUTED)
	game_scroll = ScrollContainer.new()
	game_scroll.position = Vector2(left, 170)
	game_scroll.size = Vector2(1228, 540)
	game_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	game_scroll.follow_focus = true
	game_scroll.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(game_scroll)
	shelf = Control.new()
	game_scroll.add_child(shelf)
	fill_shelf()
	var bar := Panel.new()
	bar.position = Vector2(left, 716)
	bar.size = Vector2(1228, 152)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", style(FOOTER, Color.TRANSPARENT, 12, 0))
	add_child(bar)
	label_at("CONTROLLERS", Vector2(left + 20, 732), 11, MINT)
	controller = OptionButton.new()
	controller.position = Vector2(left + 20, 758)
	controller.size = Vector2(300, 40)
	controller.add_item("Gamepads / keyboard")
	controller.add_item("Wii Remote + gamepads")
	controller.add_item("Other Wii · experimental")
	controller.set_item_disabled(1, OS.get_name() != "macOS")
	controller.select(1 if OS.get_name() == "macOS" else 0)
	paint_option(controller)
	add_child(controller)
	label_at("JOY-CONS", Vector2(left + 340, 732), 11, MINT)
	joycons = OptionButton.new()
	joycons.position = Vector2(left + 340, 758)
	joycons.size = Vector2(200, 40)
	joycons.add_item("Separate controllers")
	joycons.add_item("Paired grip")
	paint_option(joycons)
	add_child(joycons)
	label_at("WHO'S PLAYING", Vector2(left + 560, 732), 11, MINT)
	profile_button = OptionButton.new()
	profile_button.position = Vector2(left + 560, 758)
	profile_button.size = Vector2(160, 40)
	profile_button.add_item("Family")
	profile_button.add_item("Guest")
	profile_button.item_selected.connect(func(index): _send({"action": "profile", "profile": ["family", "guest"][index]}))
	paint_option(profile_button)
	add_child(profile_button)
	status = label_at("Choose something to play.", Vector2(left + 740, 762), 16, INK)
	status.size = Vector2(280, 44)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label = label_at("D-pad + %s / Enter   ·   F11 fullscreen" % confirm_glyph(), Vector2(left + 20, 814), 13, MUTED)
	stop_button = chrome_button("Close game & return", true)
	stop_button.position = Vector2(left + 956, 808)
	stop_button.size = Vector2(248, 42)
	stop_button.visible = false
	stop_button.pressed.connect(func(): _send({"action": "stop"}))
	add_child(stop_button)
	refresh_button = chrome_button("Refresh")
	refresh_button.position = Vector2(1048, 36)
	refresh_button.size = Vector2(110, 40)
	refresh_button.pressed.connect(func(): _send({"action": "refresh"}))
	add_child(refresh_button)
	info_button = chrome_button("Game info")
	info_button.position = Vector2(1166, 36)
	info_button.size = Vector2(120, 40)
	info_button.pressed.connect(open_details)
	add_child(info_button)
	settings_button = chrome_button("Settings")
	settings_button.position = Vector2(1294, 36)
	settings_button.size = Vector2(110, 40)
	settings_button.pressed.connect(open_settings)
	add_child(settings_button)
	var quit_button := chrome_button("Quit library")
	quit_button.position = Vector2(1412, 36)
	quit_button.size = Vector2(152, 40)
	quit_button.pressed.connect(func(): get_tree().quit())
	add_child(quit_button)
	_build_overlays()

func _send(request: Dictionary) -> bool:
	if session.is_empty() or not session.is_absolute_path():
		status.text = "Start the library with: python3 scripts/library.py"
		return false
	var path := session.path_join("request.json")
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file:
		status.text = "Could not reach the library. Close it and reopen."
		return false
	var request_id := str(Time.get_ticks_usec())
	request["request_id"] = request_id
	file.store_string(JSON.stringify(request))
	file.close()
	if DirAccess.rename_absolute(path+".tmp",path) != OK:
		status.text = "Could not send the launch request. Try reopening the library."
		return false
	_request_id = request_id
	return true

func confirm_glyph() -> String:
	var name := Input.get_joy_name(0).to_lower()
	if "playstation" in name or "dualshock" in name or "dualsense" in name:
		return "Cross"
	return "A"

func source_label(game: Dictionary) -> String:
	match str(game.get("source", "sample")):
		"creator":
			return "YOUR GAME"
		"installed":
			return "INSTALLED"
		_:
			return "SAMPLE"

func fill_shelf() -> void:
	for child in shelf.get_children():
		child.queue_free()
	cards.clear()
	var compact := games.size() > 3
	var rows := ceili(games.size() / 2.0) if compact else 1
	shelf.custom_minimum_size = Vector2(1210, rows * card_h + maxi(rows - 1, 0) * card_gap + 12)
	for i in games.size():
		var game: Dictionary = games[i]
		var card := Button.new()
		card.position = Vector2(6 + (i % 2) * (card_w + card_gap), 6 + floori(i / 2.0) * (card_h + card_gap)) if compact else Vector2(6 + i * (card_w + card_gap), 6)
		card.size = Vector2(card_w, card_h)
		card.add_theme_stylebox_override("normal", style(PANEL, BORDER, 16, 1))
		card.add_theme_stylebox_override("hover", style(PANEL.lightened(0.05), MINT.darkened(0.2), 16, 1))
		card.add_theme_stylebox_override("pressed", style(PANEL.lightened(0.08), MINT, 16, 1))
		card.add_theme_stylebox_override("disabled", style(PANEL, BORDER, 16, 1))
		card.add_theme_stylebox_override("focus", style(PANEL, MINT, 16, 2))
		card.pivot_offset = card.size / 2
		card.modulate = Color(0.85, 0.85, 0.85)
		shelf.add_child(card)
		var crop := Control.new()
		crop.position = Vector2(16, 16)
		crop.size = Vector2(176, 132)
		crop.clip_contents = true
		crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(crop)
		var cover := Cover.new()
		cover.game_id = str(game.get("id", ""))
		cover.tint = Color(str(game.get("color", "8ce8be")))
		cover.size = crop.size
		crop.add_child(cover)
		var accent := Color(str(game.get("color", "8ce8be")))
		label_at("%s  ·  %s" % [source_label(game), str(game.get("players", "1–16 players")).to_upper()], Vector2(210, 16), 12, accent, card)
		label_at(str(game.get("title", "Game")), Vector2(208, 38), 24, INK, card, true)
		var description := label_at(str(game.get("description", "")), Vector2(210, 72), 15, MUTED, card)
		description.size = Vector2(368, 40)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var play := "Folder missing" if game.get("missing") else ("Not playable yet" if game.get("playable") == false else "Play  →")
		label_at(play, Vector2(210, 122), 15, MUTED if play != "Play  →" else MINT, card)
		var index := i
		card.pressed.connect(func(): launch_game(index))
		card.focus_entered.connect(func():
			selected = index
			game_scroll.ensure_control_visible.call_deferred(card)
			focus_card(index))
		cards.append(card)
	if ready_pill and ready_pill.get_child_count():
		var label := ready_pill.get_child(0) as Label
		if label:
			var ready := 0
			for game in games:
				if game.get("playable", true) and not game.get("missing"):
					ready += 1
			label.text = "%d OF %d READY" % [ready, games.size()]
	if worlds_label:
		worlds_label.text = "%02d  WORLDS" % games.size()

func focus_card(index: int) -> void:
	if _focus_tween and _focus_tween.is_running():
		_focus_tween.kill()
	_focus_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for i in cards.size():
		var card := cards[i]
		if i == index:
			_focus_tween.tween_property(card, "scale", Vector2(1.04, 1.04), 0.18)
			_focus_tween.tween_property(card, "modulate", Color.WHITE, 0.18)
		else:
			_focus_tween.tween_property(card, "scale", Vector2.ONE, 0.18)
			_focus_tween.tween_property(card, "modulate", Color(0.85, 0.85, 0.85), 0.18)

func launch_game(index: int) -> void:
	if busy or _cooldown > 0 or index < 0 or index >= games.size():
		return
	selected = index
	var game: Dictionary = games[index]
	if game.get("missing"):
		status.text = str(game.get("reason", "This project folder moved. Open it from Creator Hub."))
		return
	if game.get("playable") == false:
		status.text = str(game.get("reason", "This package isn't playable yet."))
		return
	var profile := "guest" if profile_button and profile_button.selected == 1 else "family"
	if _send({"action":"launch","game":game.id,
		"input":["standard","native-wii","sdl-wii"][controller.selected],
		"joycons":"paired" if joycons.selected else "separate",
		"profile": profile}):
		_phase = "requested"
		_requested_at = Time.get_unix_time_from_system()
		status.text = "Opening " + str(game.title) + "…"
		_set_busy(true)

func _set_busy(value: bool) -> void:
	busy = value
	for card in cards:
		card.disabled = value
	controller.disabled = value
	joycons.disabled = value
	if profile_button:
		profile_button.disabled = value
	if refresh_button:
		refresh_button.disabled = value
	if info_button:
		info_button.disabled = value
	if settings_button:
		settings_button.disabled = value
	stop_button.visible = value

func _process(delta: float) -> void:
	if _cooldown > 0:
		_cooldown -= delta
		if _cooldown <= 0:
			_set_busy(false)
			cards[selected].grab_focus()
	_poll += delta
	if _poll < 0.15 or session.is_empty():
		return
	_poll = 0
	var startup := OS.get_environment("COUCH_PLAYER_STARTUP")
	if not startup.is_empty():
		var focus_request := startup.get_base_dir().path_join("focus-library")
		if FileAccess.file_exists(focus_request):
			DirAccess.remove_absolute(focus_request)
			if not busy:
				if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MINIMIZED:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)
				DisplayServer.window_move_to_foreground()
	var path := session.path_join("status.json")
	if not FileAccess.file_exists(path):
		return
	var state = JSON.parse_string(FileAccess.get_file_as_string(path))
	if state is Dictionary:
		apply_status(state)

func apply_status(state: Dictionary) -> void:
	var now := Time.get_unix_time_from_system()
	if now-float(state.get("updated",0)) > 120:
		status.text = "Library connection lost. Close and reopen the library."
		_set_busy(true)
		return
	if not _request_id.is_empty() and state.get("request_id","") != _request_id:
		return
	_request_id = ""
	_requested_at = 0
	var phase: String = state.get("phase","error")
	status.text = str(state.get("message",""))
	if phase in ["starting","running"]:
		_set_busy(true)
	elif busy and _cooldown <= 0 and _phase in ["starting","running","requested"]:
		_cooldown = 0.7
		DisplayServer.window_move_to_foreground()
	elif _cooldown <= 0:
		_set_busy(false)
	_phase = phase
	if hint_label:
		hint_label.text = "D-pad + %s / Enter   ·   F11 fullscreen" % confirm_glyph()
	var revision := int(state.get("catalog_revision", 0))
	if revision > 0 and revision != catalog_revision:
		catalog_revision = revision
		var catalog := OS.get_environment("COUCH_LIBRARY_CATALOG")
		if not catalog.is_empty() and FileAccess.file_exists(catalog):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(catalog))
			if parsed is Array and parsed.size() > 0:
				games = parsed
				fill_shelf()
				if selected < cards.size():
					cards[selected].grab_focus()

func _build_overlays() -> void:
	details_layer = _overlay()
	var detail_box := _overlay_box(details_layer)
	details_box = detail_box.get_parent()
	details_title = label_at("Game", Vector2(0, 0), 32, INK, detail_box, true)
	details_meta = label_at("", Vector2(0, 44), 16, MINT, detail_box)
	details_body = label_at("", Vector2(0, 80), 18, MUTED, detail_box)
	details_body.size = Vector2(640, 80)
	details_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var play := chrome_button("Play", true)
	play.position = Vector2(0, 180)
	play.size = Vector2(200, 44)
	play.pressed.connect(func():
		details_layer.visible = false
		launch_game(selected))
	detail_box.add_child(play)
	var close_details := chrome_button("Back")
	close_details.position = Vector2(220, 180)
	close_details.size = Vector2(160, 44)
	close_details.pressed.connect(func():
		details_layer.visible = false
		if selected < cards.size():
			cards[selected].grab_focus())
	detail_box.add_child(close_details)
	settings_layer = _overlay()
	var settings_box := _overlay_box(settings_layer)
	label_at("Settings", Vector2(0, 0), 32, INK, settings_box, true)
	label_at("Who's playing is Family or Guest. Saves are kept per profile and game under Application Support/GigaCouch/saves.", Vector2(0, 52), 16, MUTED, settings_box).size = Vector2(640, 70)
	label_at("This preview still uses your installed Godot editor as the runtime. A dedicated player-only engine is not bundled yet.", Vector2(0, 128), 16, MUTED, settings_box).size = Vector2(640, 70)
	label_at("F11 toggles fullscreen. Pair controllers with this computer, not the TV.", Vector2(0, 204), 16, MUTED, settings_box).size = Vector2(640, 48)
	var close_settings := chrome_button("Back")
	close_settings.position = Vector2(0, 268)
	close_settings.size = Vector2(160, 44)
	close_settings.pressed.connect(func():
		settings_layer.visible = false
		if selected < cards.size():
			cards[selected].grab_focus())
	settings_box.add_child(close_settings)

func _overlay() -> Control:
	var layer := Control.new()
	layer.visible = false
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = 20
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.08, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	return layer

func _overlay_box(layer: Control) -> Control:
	var box := Control.new()
	box.position = Vector2(420, 180)
	box.size = Vector2(760, 360)
	layer.add_child(box)
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", style(PANEL, MINT, 16, 1))
	box.add_child(panel)
	var inner := Control.new()
	inner.position = Vector2(36, 28)
	inner.size = Vector2(688, 300)
	box.add_child(inner)
	return inner

func open_details() -> void:
	if selected < 0 or selected >= games.size():
		return
	var game: Dictionary = games[selected]
	details_title.text = str(game.get("title", "Game"))
	details_meta.text = "%s · %s" % [source_label(game), str(game.get("players", "1–16 players"))]
	details_body.text = str(game.get("description", ""))
	details_layer.visible = true
	if _overlay_tween and _overlay_tween.is_running():
		_overlay_tween.kill()
	details_layer.modulate = Color(1, 1, 1, 0)
	details_box.position.y = 192
	_overlay_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_overlay_tween.tween_property(details_layer, "modulate:a", 1.0, 0.3)
	_overlay_tween.tween_property(details_box, "position:y", 180.0, 0.3)

func open_settings() -> void:
	settings_layer.visible = true

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _input(event: InputEvent) -> void:
	if busy and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()
