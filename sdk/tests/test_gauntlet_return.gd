extends SceneTree
## Real process termination after the final hero escapes; run by test_sdk.py.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://examples/gauntlet/dungeon.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_physics_process(false)
	game.set_process(false)
	game.sound.enabled = false
	game.service.set_process_input(false)
	game.service.set_physics_process(false)
	game.service.set_device_profile(123,"gamepad")
	var event := InputEventJoypadButton.new()
	event.device = 123
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	game.service.handle_event(event)
	game.start()
	game.heroes[1].pos = game.Level.EXIT
	game.check_finish(0.01)
	if game.phase!="complete" or game.escaped_count()!=1:
		push_error("Final hero did not complete the level")
		quit(1)
		return
	# Confirmation is printed only at tree shutdown, not when scheduling a quit.
	game.tree_exiting.connect(func(): print("Gauntlet return checks passed: final escape closes the game process."))
	game._process(6.1)
	await create_timer(0.5).timeout
	push_error("Victory countdown failed to close the game")
	quit(1)
