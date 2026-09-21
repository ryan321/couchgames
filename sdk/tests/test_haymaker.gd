extends SceneTree
## Haymaker practice rules and loopback LAN session. Not a two-computer playtest.

const LanSession = preload("res://addons/couchgames/lan_session.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func run() -> void:
	var platform: Node = root.get_node("Platform")
	var session: Node = platform.install_lan_session()
	expect(platform.has_method("install_lan_session"), "install_lan_session exists")
	expect(session == platform.install_lan_session(), "install_lan_session is idempotent")
	var parsed: Dictionary = session.parse_address("192.168.1.12:24568")
	expect(str(parsed["host"]) == "192.168.1.12" and int(parsed["port"]) == 24568, "Address parser keeps host and port")
	expect(int(session.parse_address("10.0.0.4")["port"]) == 24567, "Address without port uses the default")
	var ranked: PackedStringArray = LanSession.collect_lan_addresses([
		{"name": "lo0", "addresses": PackedStringArray(["127.0.0.1", "::1"])},
		{"name": "awdl0", "addresses": PackedStringArray(["169.254.12.4"])},
		{"name": "en0", "addresses": PackedStringArray(["fe80::1", "192.168.1.44"])},
		{"name": "en1", "addresses": PackedStringArray(["10.0.0.9"])},
	])
	expect(ranked.size() >= 1 and ranked[0] == "192.168.1.44", "Wi-Fi 192.168 wins over loopback")
	expect("127.0.0.1" not in ranked and "fe80::1" not in ranked, "Loopback and IPv6 stay off the join card")
	expect("10.0.0.9" in ranked, "A secondary private address is still listed")

	var game = load("res://examples/haymaker/arena.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.set_process(false)
	await physics_frame
	expect(game.phase == "menu" and game.hud.menu.visible, "Game starts on the host/join menu")
	expect(game.camera.current, "This computer has its own camera")
	expect(game.join_address == "", "Join field does not default to loopback")
	expect(game.hud.choices.size() >= 1 and game.hud.choice_index == 0, "Practice is the highlighted menu action")
	game.bots_enabled = false
	game.drive_local_input = false
	var confirm := InputEventJoypadButton.new()
	confirm.pressed = true
	confirm.button_index = JOY_BUTTON_A
	confirm.device = 4
	game.hud._unhandled_input(confirm)
	expect(game.phase == "playing", "A / Cross starts the highlighted Practice action")
	game.return_to_menu()
	expect(game.phase == "menu", "Returning from a pad-started practice restores the menu")

	game.bots_enabled = false
	game.drive_local_input = false
	game.start_practice()
	expect(game.phase == "playing" and game.fighters.size() == 4, "Practice starts with the local fighter and three bots")
	var player: CharacterBody3D = game.local_fighter()
	expect(player != null and player.fighter_id == 1 and not player.is_bot, "Practice local fighter is player 1")
	for i in 18:
		await physics_frame
		game.tick(1.0 / 60.0)
	expect(player.is_on_floor(), "Local fighter settles on the lot")

	var grounded: float = player.position.y
	player.input_jump = true
	game.tick(1.0 / 60.0)
	expect(player.velocity.y > 0.0 and player.position.y >= grounded, "Jump lifts the fighter")
	for i in 50:
		await physics_frame
		player.input_jump = false
		game.tick(1.0 / 60.0)
	expect(player.is_on_floor(), "Fighter lands after jumping")

	player.look_yaw = 0.0
	var before: Vector3 = player.position
	player.input_dir = Vector2(0, -1)
	for i in 10:
		await physics_frame
		game.tick(1.0 / 60.0)
	player.input_dir = Vector2.ZERO
	expect(player.position.z < before.z - 0.25, "Forward input moves the physics body")

	var dummy: CharacterBody3D = game.spawn_test_fighter(2, player.global_position + Vector3(0, 0, -1.3))
	await physics_frame
	player.look_yaw = 0.0
	player.input_punch = true
	player.punch_left = 0.0
	var punched: Array = game.hit_targets(player, false)
	player.begin_punch(false)
	expect(punched.has(dummy) and dummy.health < 100.0, "Punch damages a fighter in range")
	var after_punch: float = dummy.health
	player.input_punch = true
	game.tick(1.0 / 60.0)
	expect(dummy.health == after_punch, "Punch cooldown prevents a second immediate hit")

	dummy.health = 100.0
	dummy.alive = true
	dummy.invuln_left = 0.0
	dummy.global_position = player.global_position + Vector3(0, 0, -1.3)
	player.look_yaw = 0.0
	player.input_heavy = true
	player.heavy_left = 0.0
	var heavy_hits: Array = game.hit_targets(player, true)
	expect(heavy_hits.has(dummy) and dummy.health < after_punch, "Heavy hits harder than a jab")

	dummy.health = 80.0
	dummy.invuln_left = 0.0
	dummy.begin_dodge()
	dummy.take_hit(30.0, Vector3.FORWARD)
	expect(dummy.health == 80.0 and dummy.dodge_left > 0.0, "Dodge grants brief invulnerability")

	player.health = 50.0
	player.armor = 0.0
	player.global_position = Vector3(float(game.loot[0]["pos"][0]), 0.4, float(game.loot[0]["pos"][2]))
	game._try_loot(player)
	expect(game.loot[0]["taken"] == true, "Walking onto loot claims it")
	expect(player.health > 50.0 or player.armor > 0.0 or player.weapon == "bat", "Loot grants health, armor, or a bat")

	player.give_bat()
	expect(player.punch_damage() > 16.0, "Bat raises punch damage")

	player.health = 80.0
	player.alive = true
	player.invuln_left = 0.0
	player.global_position = Vector3(40, 0.4, 0)
	game.match_time = game.ring_duration
	game._resolve_world(1.0)
	expect(player.health < 80.0, "The shrinking ring damages fighters outside it")

	player.input_dir = Vector2.ZERO
	expect(game.accept_input(2, {"dir": [1, 0], "yaw": 0.4, "jump": false, "punch": false, "heavy": false, "dodge": false}),
		"Host accepts input from the owning peer")
	expect(dummy.input_dir.x > 0.5, "Owning peer steers its fighter")
	expect(is_zero_approx(player.input_dir.x), "A client cannot steer the host's fighter")
	expect(not game.accept_input(99, {"dir": [0, -1], "yaw": 0.0, "jump": false, "punch": false, "heavy": false, "dodge": false}),
		"Unknown peers cannot inject input")

	player.health = 80.0
	player.alive = true
	player.invuln_left = 0.0
	for fighter: CharacterBody3D in game.fighters.values():
		if fighter.fighter_id != 1:
			fighter.invuln_left = 0.0
			fighter.take_hit(1000.0, Vector3.ZERO)
	game.phase = "playing"
	game.match_time = 1.0
	game._check_winner()
	expect(game.phase == "results" and game.winner_id == 1, "Last living fighter wins")
	expect(game.hud.menu.visible and game.hud.choices.size() >= 1, "Win/lose screen shows controller actions")
	expect(game.hud.choices[0].text.begins_with("PLAY AGAIN"), "Play again is the highlighted result action")
	var rematch := InputEventJoypadButton.new()
	rematch.pressed = true
	rematch.button_index = JOY_BUTTON_A
	rematch.device = 4
	game.hud._unhandled_input(rematch)
	expect(game.phase == "playing" and game.local_fighter() != null and game.local_fighter().alive, "A / Cross starts another practice match")

	game.phase = "playing"
	game.match_time = 1.0
	player = game.local_fighter()
	player.invuln_left = 0.0
	player.take_hit(1000.0, Vector3.ZERO)
	game._check_winner()
	expect(game.phase == "results" and game.result_title() == "YOU LOSE", "Dying in practice opens the lose screen")
	expect(game.hud.choices[0].text.begins_with("PLAY AGAIN"), "Play again stays highlighted after a loss")

	game.return_to_menu()
	expect(game.phase == "menu" and game.fighters.is_empty(), "Results return to the session menu")

	game.queue_free()
	await process_frame
	await _test_loopback()
	if not failures:
		print("Haymaker checks passed: %d LAN/brawler assertions." % checks)
	quit(1 if failures else 0)


func _test_loopback() -> void:
	var port := 25000 + int(Time.get_ticks_usec() % 800)
	var host_root := Node.new()
	var client_root := Node.new()
	root.add_child(host_root)
	root.add_child(client_root)
	var host_api := MultiplayerAPI.create_default_interface()
	var client_api := MultiplayerAPI.create_default_interface()
	set_multiplayer(host_api, host_root.get_path())
	set_multiplayer(client_api, client_root.get_path())
	var host: Node = LanSession.new()
	var client: Node = LanSession.new()
	host_root.add_child(host)
	client_root.add_child(client)
	var hosted := [false]
	var joined := [false]
	host.hosted.connect(func(): hosted[0] = true)
	client.connected.connect(func(): joined[0] = true)
	expect(host.host_game(port) == OK, "Host binds a loopback port")
	expect(client.join_game("127.0.0.1", port) == OK, "Client starts connecting")
	for i in 180:
		await process_frame
		if hosted[0] and joined[0] and host.connected_peers().size() == 1:
			break
	expect(hosted[0] and host.is_host(), "Host session reports hosting")
	expect(joined[0], "Client reaches the host on 127.0.0.1")
	expect(host.connected_peers().size() == 1, "Host lists the connected client")
	expect(client.unique_id() != 1 and client.unique_id() != 0, "Client receives a non-host peer id")
	client.close_session()
	host.close_session()
	host_root.queue_free()
	client_root.queue_free()
