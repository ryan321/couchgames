extends Control
const Cover = preload("res://launcher/cover.gd")
const INK := Color("f5efdf")
const MUTED := Color("a5bfbd")
var games: Array = []
var cards: Array[Button] = []
var game_scroll: ScrollContainer
var controller: OptionButton
var joycons: OptionButton
var status: Label
var stop_button: Button
var session := ""
var busy := false
var selected := 0
var _phase := ""
var _poll := 0.0
var _requested_at := 0.0
var _request_id := ""
var _cooldown := 0.0

func _ready() -> void:
	DisplayServer.window_set_title("Giga Couch · Your library")
	games = JSON.parse_string(FileAccess.get_file_as_string("res://launcher/games.json"))
	session = OS.get_environment("COUCH_LIBRARY_SESSION")
	# Library navigation does not join game players or claim motion sensors.
	get_node("/root/Platform").input.set_process_input(false)
	theme = Theme.new()
	theme.default_font_size = 20
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

func label_at(text: String, at: Vector2, font_size: int, color := INK, parent: Node = self) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func style(color: Color, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(18)
	box.border_color = border
	box.set_border_width_all(3)
	return box

func _build() -> void:
	var background := ColorRect.new()
	background.color = Color("163c43")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	label_at("G I G A  C O U C H",Vector2(68,44),22,Color("b2d1c3"))
	label_at("Tonight, we play.",Vector2(65,94),64)
	label_at("Pick a world. Grab a controller. Make room on the couch.",Vector2(68,175),24,MUTED)
	label_at("YOUR GAMES",Vector2(68,250),18,MUTED)
	label_at("%02d  /  READY TO PLAY" % games.size(),Vector2(1280,250),18,MUTED)
	var compact := games.size()>3
	game_scroll = ScrollContainer.new()
	game_scroll.position = Vector2(62,289)
	game_scroll.size = Vector2(1476,440)
	game_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	game_scroll.follow_focus = true
	add_child(game_scroll)
	var shelf := Control.new()
	shelf.custom_minimum_size = Vector2(1454,ceili(games.size()/2.0)*221+10) if compact else Vector2(1454,430)
	game_scroll.add_child(shelf)
	for i in games.size():
		var game: Dictionary = games[i]
		var card := Button.new()
		card.position = Vector2(6+(i%2)*729,6+floori(i/2.0)*221) if compact else Vector2(6+i*489,6)
		card.size = Vector2(710,204) if compact else Vector2(470,420)
		card.add_theme_stylebox_override("normal",style(Color("21494f")))
		card.add_theme_stylebox_override("hover",style(Color("2b5960"),Color("8aafa5")))
		card.add_theme_stylebox_override("pressed",style(Color("34626a")))
		card.add_theme_stylebox_override("disabled",style(Color("21494f")))
		card.add_theme_stylebox_override("focus",style(Color.TRANSPARENT,Color("f6d69c")))
		shelf.add_child(card)
		var crop := Control.new()
		crop.position = Vector2(12,12)
		crop.size = Vector2(252,180) if compact else Vector2(446,240)
		crop.clip_contents = true
		crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(crop)
		var cover := Cover.new()
		cover.game_id = game.id
		cover.tint = Color(game.color)
		cover.size = crop.size
		crop.add_child(cover)
		label_at(game.players.to_upper(),Vector2(284,20) if compact else Vector2(24,270),16,Color(game.color),card)
		label_at(game.title,Vector2(282,53) if compact else Vector2(22,297),30 if compact else 34,INK,card)
		var description := label_at(game.description,Vector2(284,99) if compact else Vector2(24,347),18,MUTED,card)
		description.size = Vector2(400 if compact else 422,50)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label_at("PLAY  →",Vector2(284,161) if compact else Vector2(24,380),18,INK,card)
		card.pressed.connect(func(): launch_game(i))
		card.focus_entered.connect(func():
			selected = i
			game_scroll.ensure_control_visible.call_deferred(card))
		cards.append(card)
	label_at("CONTROLLERS",Vector2(68,749),15,MUTED)
	controller = OptionButton.new()
	controller.position = Vector2(68,777)
	controller.size = Vector2(315,43)
	controller.add_item("Gamepads / keyboard")
	controller.add_item("Wii Remote + gamepads")
	controller.add_item("Other Wii · experimental")
	controller.set_item_disabled(1,OS.get_name() != "macOS")
	controller.select(1 if OS.get_name() == "macOS" else 0)
	add_child(controller)
	label_at("JOY-CONS",Vector2(410,749),15,MUTED)
	joycons = OptionButton.new()
	joycons.position = Vector2(410,777)
	joycons.size = Vector2(235,43)
	joycons.add_item("Separate controllers")
	joycons.add_item("Paired grip")
	add_child(joycons)
	status = label_at("Choose something to play.",Vector2(680,775),20,INK)
	status.size = Vector2(835,70)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label_at("Click a game  ·  Arrows / D-pad + A / Cross / Enter  ·  F11 fullscreen",Vector2(68,852),16,MUTED)
	stop_button = Button.new()
	stop_button.text = "Close game & return"
	stop_button.position = Vector2(1280,842)
	stop_button.size = Vector2(247,40)
	stop_button.visible = false
	stop_button.pressed.connect(func(): _send({"action":"stop"}))
	add_child(stop_button)
	var quit_button := Button.new()
	quit_button.text = "Quit library"
	quit_button.position = Vector2(1355,47)
	quit_button.size = Vector2(170,43)
	quit_button.pressed.connect(func(): get_tree().quit())
	add_child(quit_button)

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

func launch_game(index: int) -> void:
	if busy or _cooldown > 0 or index < 0 or index >= games.size():
		return
	selected = index
	if _send({"action":"launch","game":games[index].id,
		"input":["standard","native-wii","sdl-wii"][controller.selected],
		"joycons":"paired" if joycons.selected else "separate"}):
		_phase = "requested"
		_requested_at = Time.get_unix_time_from_system()
		status.text = "Opening " + games[index].title + "…"
		_set_busy(true)

func _set_busy(value: bool) -> void:
	busy = value
	for card in cards:
		card.disabled = value
	controller.disabled = value
	joycons.disabled = value
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

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _input(event: InputEvent) -> void:
	if busy and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		get_viewport().set_input_as_handled()
