extends Node3D
## LAN last-one-standing brawler. Host simulates; each computer renders its own view.

const World = preload("res://examples/haymaker/world.gd")
const Fighter = preload("res://examples/haymaker/fighter.gd")
const Hud = preload("res://examples/haymaker/hud.gd")
const RING_START := 42.0
const RING_END := 9.0
const SNAPSHOT_EVERY := 3

var platform: Node
var input_service: Node
var session: Node
var hud: Control
var camera: Camera3D
var ring_mesh: MeshInstance3D
var phase := "menu"
var mode := "practice"
var join_address := ""
var banner := ""
var fighters: Dictionary = {}
var loot: Array[Dictionary] = []
var pads: Array[Vector3] = []
var spawns: Array[Vector3] = []
var loot_points: Array[Vector3] = []
var ring_radius := RING_START
var ring_duration := 90.0
var ring_damage := 12.0
var match_time := 0.0
var winner_id := 0
var snapshot_tick := 0
var mouse_look := Vector2.ZERO
var local_paused := false
var look_ready := false
var control_mode := "mouse"
var bots_enabled := true
var drive_local_input := true
var _previous_window_mode := DisplayServer.WINDOW_MODE_MAXIMIZED
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	DisplayServer.window_set_title("Haymaker · Giga Couch")
	platform = get_node("/root/Platform")
	input_service = platform.input
	input_service.keyboard_enabled = true
	session = platform.install_lan_session()
	session.hosted.connect(_on_hosted)
	session.connected.connect(_on_client_connected)
	session.connection_failed.connect(_on_connection_failed)
	session.disconnected.connect(_on_disconnected)
	session.peer_joined.connect(_on_peer_joined)
	session.peer_left.connect(_on_peer_left)
	var built: Dictionary = World.build(self)
	pads = built["pads"]
	spawns = built["spawns"]
	loot_points = built["loot"]
	_make_camera()
	_make_ring()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	hud = Hud.new()
	hud.game = self
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	canvas.add_child(hud)
	hud.show_menu()
	apply_render_quality()
	_parse_user_args()


func _process(delta: float) -> void:
	_update_camera(delta)
	if phase == "waiting":
		hud.refresh_waiting()
	if phase == "playing" and not local_paused:
		hud.queue_redraw()


func _physics_process(delta: float) -> void:
	if phase != "playing":
		return
	if mode == "practice" and local_paused:
		return
	tick(delta)


func tick(delta: float) -> void:
	if phase != "playing":
		return
	match_time += delta
	_collect_local_input()
	if _is_authority():
		_simulate_bots(delta)
		_simulate_fighters(delta)
		_resolve_combat()
		_resolve_world(delta)
		_check_winner()
		snapshot_tick += 1
		if mode == "host" and snapshot_tick >= SNAPSHOT_EVERY:
			snapshot_tick = 0
			rpc_snapshot.rpc(make_snapshot())
	else:
		for fighter: HaymakerFighter in fighters.values():
			fighter.simulate(delta, false)


func _is_authority() -> bool:
	return mode == "practice" or (mode == "host" and session.is_host())


func local_id() -> int:
	if mode == "practice":
		return 1
	return session.unique_id()


func local_fighter() -> HaymakerFighter:
	return fighters.get(local_id()) as HaymakerFighter


func alive_count() -> int:
	var count := 0
	for fighter: HaymakerFighter in fighters.values():
		if fighter.alive:
			count += 1
	return count


func waiting_summary() -> String:
	var peers: int = 1 + session.connected_peers().size()
	if mode == "client":
		return "This screen is ready. Computers in session: %d." % maxi(peers, 1)
	return "%d computer(s) in the session. Start when everyone has joined." % maxi(peers, 1)


func result_title() -> String:
	if winner_id == local_id() and winner_id != 0:
		return "YOU WIN"
	var me := local_fighter()
	if me and not me.alive:
		return "YOU LOSE"
	if winner_id == 0:
		return "DRAW"
	var fighter: HaymakerFighter = fighters.get(winner_id) as HaymakerFighter
	if fighter and fighter.is_bot:
		return "BOT WINS"
	return "P%d WINS" % winner_id


func result_detail() -> String:
	if mode == "client":
		return "A / Cross asks the host for another match."
	return "A / Cross plays again. D-pad or left stick moves."


func start_practice() -> void:
	mode = "practice"
	banner = ""
	_begin_match(621)


func host_lan() -> void:
	mode = "host"
	banner = "Starting host…"
	if session.host_game(session.port) != OK:
		banner = session.last_error
		mode = "practice"
		hud.show_menu()


func join_lan() -> void:
	mode = "client"
	banner = "Connecting…"
	var parsed: Dictionary = session.parse_address(join_address)
	if session.join_game(str(parsed["host"]), int(parsed["port"])) != OK:
		banner = session.last_error
		mode = "practice"
		hud.show_menu()


func request_start() -> void:
	if mode != "host" or not session.is_host():
		return
	var seed := rng.randi()
	_begin_match(seed)
	rpc_start.rpc(seed)


func play_again() -> void:
	if mode == "client":
		rpc_request_rematch.rpc_id(1)
		banner = "Asking the host to start another match…"
		if hud:
			hud.show_results()
		return
	if mode == "host":
		request_start()
		return
	start_practice()


func leave_session() -> void:
	return_to_menu()


func return_to_menu(reason := "") -> void:
	phase = "menu"
	mode = "practice"
	local_paused = false
	get_tree().paused = false
	_clear_fighters()
	loot.clear()
	winner_id = 0
	ring_radius = RING_START
	banner = reason
	hud.show_menu()
	session.close_session()


func resume_local() -> void:
	local_paused = false
	if mode == "practice":
		get_tree().paused = false
	hud.hide_menu()


func quit_game() -> void:
	session.close_session()
	platform.quit_to_platform()


func spawn_test_fighter(id: int, at: Vector3 = Vector3.ZERO, bot := false) -> HaymakerFighter:
	return _spawn_fighter(id, id, bot, at)


func claim_local_device(device: int) -> void:
	if device < 0:
		return
	if input_service.player_for_device(device) != 0:
		return
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	input_service.handle_event(event)


func apply_render_quality() -> void:
	var view := get_viewport()
	view.msaa_3d = Viewport.MSAA_2X
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		view.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		view.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR


@rpc("authority", "call_remote", "reliable")
func rpc_start(seed: int) -> void:
	_begin_match(seed)


@rpc("any_peer", "call_remote", "reliable")
func rpc_input(payload: Dictionary) -> void:
	if not _is_authority():
		return
	var sender := multiplayer.get_remote_sender_id()
	accept_input(sender, payload)


@rpc("authority", "call_remote", "unreliable")
func rpc_snapshot(payload: Dictionary) -> void:
	if _is_authority():
		return
	apply_snapshot(payload)


@rpc("authority", "call_remote", "reliable")
func rpc_end(winner: int) -> void:
	_finish(winner)


@rpc("any_peer", "call_remote", "reliable")
func rpc_request_rematch() -> void:
	if mode != "host" or phase != "results":
		return
	request_start()


func accept_input(peer: int, payload: Dictionary) -> bool:
	var fighter: HaymakerFighter = fighters.get(peer) as HaymakerFighter
	if fighter == null or fighter.peer_id != peer or fighter.is_bot:
		return false
	_apply_input(fighter, payload)
	return true


func make_snapshot() -> Dictionary:
	var packed: Array = []
	for fighter: HaymakerFighter in fighters.values():
		packed.append(fighter.snapshot())
	return {
		"phase": phase,
		"time": match_time,
		"ring": ring_radius,
		"winner": winner_id,
		"fighters": packed,
		"loot": loot.duplicate(true),
	}


func apply_snapshot(payload: Dictionary) -> void:
	ring_radius = float(payload.get("ring", ring_radius))
	match_time = float(payload.get("time", match_time))
	winner_id = int(payload.get("winner", winner_id))
	loot.clear()
	for item in payload.get("loot", []):
		if item is Dictionary:
			loot.append(item)
	var seen: Dictionary = {}
	for data in payload.get("fighters", []):
		if not (data is Dictionary):
			continue
		var id := int(data.get("id", 0))
		if id == 0:
			continue
		seen[id] = true
		var fighter: HaymakerFighter = fighters.get(id)
		if fighter == null:
			fighter = _spawn_fighter(id, int(data.get("peer", id)), bool(data.get("bot", false)), Vector3.ZERO)
		fighter.apply_snapshot(data)
	var remove: Array[int] = []
	for id: int in fighters.keys():
		if not seen.has(id):
			remove.append(id)
	for id in remove:
		fighters[id].queue_free()
		fighters.erase(id)
	_scale_ring()
	if str(payload.get("phase", phase)) == "results" and phase != "results":
		_finish(winner_id)


func hit_targets(attacker: HaymakerFighter, heavy: bool) -> Array[HaymakerFighter]:
	var radius := 2.9 if heavy else 2.35
	var origin: Vector3 = attacker.global_position + Vector3(0, 0.9, 0) + attacker.facing() * 1.35
	var hits: Array[HaymakerFighter] = []
	for fighter: HaymakerFighter in fighters.values():
		if fighter == attacker or not fighter.alive:
			continue
		var to: Vector3 = fighter.global_position + Vector3(0, 0.9, 0) - origin
		if to.length() <= radius:
			hits.append(fighter)
	var amount: float = attacker.heavy_damage() if heavy else attacker.punch_damage()
	for fighter in hits:
		fighter.take_hit(amount, fighter.global_position - attacker.global_position)
		_strike_flash(fighter.global_position + Vector3(0, 1.1, 0))
	return hits


func _begin_match(seed: int) -> void:
	rng.seed = seed
	phase = "playing"
	local_paused = false
	get_tree().paused = false
	match_time = 0.0
	winner_id = 0
	ring_radius = RING_START
	snapshot_tick = 0
	_clear_fighters()
	_place_loot()
	if mode == "practice":
		_spawn_fighter(1, 1, false, spawns[0])
		for i in 3:
			_spawn_fighter(101 + i, 101 + i, true, spawns[i + 1])
	elif mode == "host":
		_spawn_fighter(1, 1, false, spawns[0])
		var index := 1
		for peer_id in session.connected_peers():
			_spawn_fighter(peer_id, peer_id, false, spawns[index % spawns.size()])
			index += 1
	_scale_ring()
	hud.hide_menu()
	look_ready = false


func _finish(winner: int) -> void:
	if phase == "results":
		return
	phase = "results"
	winner_id = winner
	hud.show_results()


func _spawn_fighter(id: int, peer: int, bot: bool, at: Vector3) -> HaymakerFighter:
	if fighters.has(id):
		return fighters[id]
	var fighter: HaymakerFighter = Fighter.new()
	fighter.setup(id, peer, bot)
	add_child(fighter)
	fighter.global_position = at + Vector3(0, 0.2, 0)
	var toward := -at
	toward.y = 0
	if toward.length() > 0.1:
		fighter.look_yaw = atan2(-toward.x, -toward.z)
	fighters[id] = fighter
	return fighter


func _clear_fighters() -> void:
	for fighter: HaymakerFighter in fighters.values():
		fighter.queue_free()
	fighters.clear()


func _place_loot() -> void:
	loot.clear()
	var kinds: Array[String] = ["health", "armor", "bat", "health", "armor", "bat", "health", "armor"]
	for i in loot_points.size():
		loot.append({
			"id": i + 1,
			"kind": kinds[i % kinds.size()],
			"pos": [loot_points[i].x, loot_points[i].y, loot_points[i].z],
			"taken": false,
		})


func _collect_local_input() -> void:
	if not drive_local_input:
		return
	var fighter := local_fighter()
	if fighter == null or not fighter.alive or local_paused:
		return
	_ensure_local_join()
	var payload := _read_local_payload(fighter)
	_apply_input(fighter, payload)
	if mode == "client" and session.status == "connected":
		rpc_input.rpc_id(1, payload)


func _read_local_payload(fighter: HaymakerFighter) -> Dictionary:
	var player_id := _local_input_id()
	var move := Vector2.ZERO
	if player_id != 0:
		move = input_service.movement(player_id)
	var jump := Input.is_physical_key_pressed(KEY_SPACE) or _held(player_id, JOY_BUTTON_RIGHT_SHOULDER)
	var punch := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or _held(player_id, JOY_BUTTON_A) \
		or _held(player_id, JOY_BUTTON_X) or _trigger(player_id, JOY_AXIS_TRIGGER_RIGHT)
	var heavy := Input.is_physical_key_pressed(KEY_F) or _held(player_id, JOY_BUTTON_Y) \
		or _trigger(player_id, JOY_AXIS_TRIGGER_LEFT)
	var dodge := Input.is_physical_key_pressed(KEY_SHIFT) or _held(player_id, JOY_BUTTON_LEFT_SHOULDER) \
		or _held(player_id, JOY_BUTTON_B)
	_apply_look(fighter, player_id)
	return {
		"dir": [move.x, move.y],
		"yaw": fighter.look_yaw,
		"jump": jump,
		"punch": punch,
		"heavy": heavy,
		"dodge": dodge,
	}


func _apply_look(fighter: HaymakerFighter, player_id: int) -> void:
	if mouse_look.length() > 0.0:
		fighter.look_yaw -= mouse_look.x
		mouse_look = Vector2.ZERO
		control_mode = "mouse"
	var device := -1
	if player_id != 0 and input_service.players.has(player_id):
		device = int(input_service.players[player_id]["device"])
	if device < 0:
		return
	var raw := Vector2(Input.get_joy_axis(device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y))
	if not look_ready:
		if raw.length() <= 0.22:
			look_ready = true
		return
	var filtered := Vector2(_look_axis(raw.x), _look_axis(raw.y))
	if filtered == Vector2.ZERO:
		return
	fighter.look_yaw -= filtered.x * 0.07
	control_mode = "controller"


func _look_axis(value: float) -> float:
	if absf(value) <= 0.22:
		return 0.0
	return signf(value) * clampf((absf(value) - 0.22) / 0.78, 0.0, 1.0)


func _held(player_id: int, button: int) -> bool:
	if player_id == 0 or not input_service.players.has(player_id):
		return false
	var buttons: Dictionary = input_service.players[player_id]["buttons"]
	return bool(buttons.get(button, false))


func _trigger(player_id: int, axis: int) -> bool:
	if player_id == 0 or not input_service.players.has(player_id):
		return false
	var device: int = int(input_service.players[player_id]["device"])
	if device < 0:
		return false
	return Input.get_joy_axis(device, axis) > 0.45


func _local_input_id() -> int:
	var keyboard_id := 0
	for id in input_service.players:
		var device: int = int(input_service.players[id]["device"])
		if device != input_service.KEYBOARD_DEVICE:
			return int(id)
		keyboard_id = int(id)
	return keyboard_id


func _ensure_local_join() -> void:
	if not input_service.players.is_empty():
		return
	var pads: Array = Input.get_connected_joypads()
	if pads.size() > 0:
		claim_local_device(int(pads[0]))
		if not input_service.players.is_empty():
			return
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	input_service.handle_event(event)


func _apply_input(fighter: HaymakerFighter, payload: Dictionary) -> void:
	var dir: Array = payload.get("dir", [0, 0])
	fighter.input_dir = Vector2(float(dir[0]), float(dir[1])).limit_length()
	fighter.look_yaw = float(payload.get("yaw", fighter.look_yaw))
	fighter.input_jump = bool(payload.get("jump", false))
	fighter.input_punch = bool(payload.get("punch", false))
	fighter.input_heavy = bool(payload.get("heavy", false))
	fighter.input_dodge = bool(payload.get("dodge", false))


func _simulate_bots(delta: float) -> void:
	if not bots_enabled:
		return
	for fighter: HaymakerFighter in fighters.values():
		if not fighter.is_bot or not fighter.alive:
			continue
		var target := _nearest_alive(fighter)
		if target == null:
			fighter.input_dir = Vector2.ZERO
			continue
		var to: Vector3 = target.global_position - fighter.global_position
		to.y = 0
		fighter.look_yaw = atan2(-to.x, -to.z)
		var distance := to.length()
		fighter.input_dir = Vector2(0, -1) if distance > 1.6 else Vector2.ZERO
		fighter.input_punch = distance < 2.1
		fighter.input_heavy = distance < 1.7 and fighter.health < 55.0
		fighter.input_dodge = fighter.health < 30.0 and distance < 2.4
		fighter.input_jump = distance > 8.0 and rng.randf() < delta * 0.4


func _nearest_alive(from: HaymakerFighter) -> HaymakerFighter:
	var best: HaymakerFighter = null
	var best_distance := 9999.0
	for fighter: HaymakerFighter in fighters.values():
		if fighter == from or not fighter.alive:
			continue
		var distance: float = from.global_position.distance_to(fighter.global_position)
		if distance < best_distance:
			best_distance = distance
			best = fighter
	return best


func _simulate_fighters(delta: float) -> void:
	for fighter: HaymakerFighter in fighters.values():
		fighter.simulate(delta, true)


func _resolve_combat() -> void:
	for fighter: HaymakerFighter in fighters.values():
		if not fighter.alive:
			continue
		var edges: Dictionary = fighter.consume_edges()
		if edges["dodge"] and fighter.dodge_left <= 0.0:
			fighter.begin_dodge()
		if edges["heavy"] and fighter.heavy_left <= 0.0:
			fighter.begin_punch(true)
			hit_targets(fighter, true)
		elif edges["punch"] and fighter.punch_left <= 0.0:
			fighter.begin_punch(false)
			hit_targets(fighter, false)


func _resolve_world(delta: float) -> void:
	var shrink_t := clampf(match_time / ring_duration, 0.0, 1.0)
	ring_radius = lerpf(RING_START, RING_END, shrink_t)
	_scale_ring()
	for fighter: HaymakerFighter in fighters.values():
		if not fighter.alive:
			continue
		var flat := Vector2(fighter.global_position.x, fighter.global_position.z)
		if flat.length() > ring_radius:
			fighter.take_hit(ring_damage * delta, -Vector3(fighter.global_position.x, 0, fighter.global_position.z))
		for pad in pads:
			if Vector2(fighter.global_position.x - pad.x, fighter.global_position.z - pad.z).length() < 1.4 and fighter.is_on_floor():
				fighter.velocity.y = 13.5
		if fighter.global_position.y < -6.0:
			fighter.take_hit(40.0, Vector3.ZERO)
			fighter.global_position = _spawn_for(fighter.fighter_id)
			fighter.velocity = Vector3.ZERO
		_try_loot(fighter)


func _try_loot(fighter: HaymakerFighter) -> void:
	for item in loot:
		if item["taken"]:
			continue
		var pos: Array = item["pos"]
		var at := Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
		if fighter.global_position.distance_to(at) > 1.4:
			continue
		item["taken"] = true
		match str(item["kind"]):
			"health":
				fighter.heal(35.0)
			"armor":
				fighter.add_armor(40.0)
			"bat":
				fighter.give_bat()


func _check_winner() -> void:
	if phase != "playing":
		return
	if match_time < 0.4:
		return
	var living: Array[int] = []
	for fighter: HaymakerFighter in fighters.values():
		if fighter.alive:
			living.append(fighter.fighter_id)
	var me := local_fighter()
	if mode == "practice" and me and not me.alive:
		var practice_winner := living[0] if living.size() == 1 else 0
		_finish(practice_winner)
		return
	if living.size() > 1:
		return
	var winner := living[0] if living.size() == 1 else 0
	_finish(winner)
	if mode == "host":
		rpc_end.rpc(winner)


func _spawn_for(id: int) -> Vector3:
	if spawns.is_empty():
		return Vector3(0, 0.4, 0)
	return spawns[(id - 1) % spawns.size()] + Vector3(0, 0.3, 0)


func _make_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 62
	camera.near = 0.08
	camera.position = Vector3(14, 10, 18)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true


func _update_camera(delta: float) -> void:
	var fighter := local_fighter()
	var target := Vector3.ZERO
	var yaw := match_time * 0.12
	if fighter:
		target = fighter.global_position + Vector3(0, 1.15, 0)
		yaw = fighter.look_yaw
	var offset := Vector3(0, 1.85, 4.8)
	offset = offset.rotated(Vector3.UP, yaw)
	var desired := target + offset
	if fighter == null:
		desired = Vector3(sin(match_time * 0.18) * 22.0, 14.0, cos(match_time * 0.18) * 22.0)
		target = Vector3.ZERO
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-delta * 8.0))
	if camera.global_position.distance_to(target) > 0.2:
		camera.look_at(target)


func _make_ring() -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = 1
	shape.bottom_radius = 1
	shape.height = 8
	shape.radial_segments = 64
	shape.cap_top = false
	shape.cap_bottom = false
	ring_mesh = MeshInstance3D.new()
	ring_mesh.mesh = shape
	var mat := ShaderMaterial.new()
	mat.shader = load("res://examples/haymaker/shaders/ring.gdshader")
	ring_mesh.material_override = mat
	ring_mesh.position.y = 4
	add_child(ring_mesh)
	_scale_ring()


func _scale_ring() -> void:
	if ring_mesh:
		ring_mesh.scale = Vector3(ring_radius, 1, ring_radius)


func _on_hosted() -> void:
	phase = "waiting"
	banner = ""
	hud.show_waiting()
	_ensure_local_join()


func _on_client_connected() -> void:
	phase = "waiting"
	banner = ""
	hud.show_waiting()
	_ensure_local_join()


func _on_connection_failed(reason: String) -> void:
	mode = "practice"
	phase = "menu"
	banner = reason
	hud.show_menu()


func _on_disconnected(reason: String) -> void:
	if phase == "menu":
		return
	return_to_menu(reason)


func _on_peer_joined(_peer_id: int) -> void:
	if phase == "waiting":
		hud.refresh_waiting()


func _on_peer_left(peer_id: int) -> void:
	if _is_authority() and fighters.has(peer_id):
		var fighter: HaymakerFighter = fighters[peer_id]
		fighter.take_hit(1000.0, Vector3.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		mouse_look += event.relative * 0.008
		control_mode = "mouse"
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		_toggle_fullscreen()
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_pause()
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		_toggle_pause()


func _toggle_pause() -> void:
	if phase == "playing" and not local_paused:
		local_paused = true
		if mode == "practice":
			get_tree().paused = true
		hud.process_mode = Node.PROCESS_MODE_ALWAYS
		hud.show_pause()
	elif local_paused:
		resume_local()


func _toggle_fullscreen() -> void:
	var window_mode := DisplayServer.window_get_mode()
	if window_mode in [DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]:
		DisplayServer.window_set_mode(_previous_window_mode)
	else:
		_previous_window_mode = window_mode
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _strike_flash(at: Vector3) -> void:
	var spark := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.22
	ball.height = 0.44
	spark.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("fff4c2")
	mat.emission_enabled = true
	mat.emission = Color("ffe28a")
	mat.emission_energy_multiplier = 4.0
	spark.material_override = mat
	spark.position = at
	add_child(spark)
	get_tree().create_timer(0.12).timeout.connect(func():
		if is_instance_valid(spark):
			spark.queue_free())


func _parse_user_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--practice":
			call_deferred("start_practice")
		elif argument == "--host":
			call_deferred("host_lan")
		elif argument.begins_with("--join="):
			join_address = argument.trim_prefix("--join=")
			call_deferred("join_lan")
		elif argument.begins_with("--port="):
			session.port = int(argument.trim_prefix("--port="))
