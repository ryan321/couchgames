extends SceneTree
const Controls = preload("res://examples/cloudbound/flight_controls.gd")
const Motion = preload("res://addons/couchgames/controller_motion.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var motion := Motion.new()
	motion.submit(1000, [0, 0, 1], 100, "factory")
	expect(not motion.sample_for_device(1000, 100.1).is_empty(), "Fresh motion is available")
	expect(motion.sample_for_device(1000, 100.3).is_empty(), "Motion expires quickly")
	expect(motion.sample_for_device(1001, 100.1).is_empty(), "Motion is isolated by device")
	for invalid in [[0, 0], [0, "1", 1], [0, INF, 1], [0, NAN, 1], [9, 0, 1], null]:
		motion.submit(1000, invalid, 100, "approximate")
		expect(motion.sample_for_device(1000, 100).is_empty(), "Invalid acceleration is unavailable")
	motion.free()
	var controls := Controls.new()
	for i in 65:
		controls.update({"acceleration":Vector3(0.04, 0.02, 1), "updated":100.0+i*0.02}, 0.02)
	expect(controls.ready, "Steady near-level pose calibrates")
	var steer := controls.update({"acceleration":Vector3(0.04, 0.02, 1), "updated":102}, 0.1)
	expect(steer.length() < 0.01, "Neutral pose does not drift")
	for i in 30:
		steer = controls.update({"acceleration":Vector3(-0.3, -0.5, 0.81), "updated":103.0+i*0.02}, 0.02)
	expect(steer.x > 0.7 and steer.y > 0.4, "Sideways right end down plus roll toward body steer right and climb")
	for i in 30:
		steer = controls.update({"acceleration":Vector3(0.3, 0.5, 0.81), "updated":104.0+i*0.02}, 0.02)
	expect(steer.x < -0.7 and steer.y < -0.4, "Sideways left end down plus roll away steer left and dive")
	controls.update({}, 0.02)
	expect(not controls.ready and controls.steering == Vector2.ZERO, "Lost samples clear steering and require recalibration")
	for i in 90:
		controls.update({"acceleration":Vector3(0, 0, 1), "updated":110}, 0.02)
	expect(not controls.ready, "Repeated snapshot cannot finish calibration")
	controls.reset()
	for i in 90:
		controls.update({"acceleration":Vector3(0, 1, 0), "updated":120.0+i*0.02}, 0.02)
	expect(not controls.ready, "Vertical end-over-end grip asks for horizontal ends")
	# Isolated physical poses catch sign inversions and crossed steering axes.
	for pose in [
		[Vector3(0, 0.5, 0.866), Vector2.LEFT, "D-pad end lowered banks left"],
		[Vector3(0, -0.5, 0.866), Vector2.RIGHT, "1/2 end lowered banks right"],
		[Vector3(0.5, 0, 0.866), Vector2.DOWN, "Roll away dives"],
		[Vector3(-0.5, 0, 0.866), Vector2.UP, "Roll toward body climbs"],
	]:
		controls.reset()
		for i in 65:
			controls.update({"acceleration":Vector3(0,0,1), "updated":140.0+i*0.02}, 0.02)
		for i in 60:
			steer = controls.update({"acceleration":pose[0], "updated":142.0+i*0.02}, 0.02)
		# Flight steering uses +Y for climbing (opposite the screen's Vector2.UP).
		var expected: Vector2 = pose[1]
		expected.y *= -1
		expect(steer.distance_to(expected) < 0.04, pose[2])
	controls.reset()
	for i in 65:
		controls.update({"acceleration":Vector3(-0.866,0,0.5), "updated":150.0+i*0.02}, 0.02)
	expect(controls.ready, "Comfortably angled sideways grip can calibrate")
	for i in 60:
		steer = controls.update({"acceleration":Vector3(-0.5,0,0.866), "updated":152.0+i*0.02}, 0.02)
	expect(steer.y < -0.9 and absf(steer.x) < 0.01, "Rolling away from angled neutral dives without banking")
	var world = load("res://examples/cloudbound/flight.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	world.set_physics_process(false)
	var service = root.get_node("Platform").input
	var event := InputEventJoypadButton.new()
	event.device = 150
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	service.handle_event(event)
	expect(world.pilot == 1, "SDK join assigns the flight pilot")
	world._physics_process(0.02)
	expect(world.flying and world.distance > 0, "Joined fallback pilot advances the course")
	var y: float = world.plane.position.y
	world.advance_flight(0.2, Vector2(1,1), 22)
	expect(world.plane.position.x > 0 and world.plane.position.y > y, "Flight input moves the actual aircraft")
	world._restart()
	world.rings[0].position = Vector3(0, 10, -0.1)
	world.advance_flight(0.1, Vector2.ZERO, 37)
	expect(world.score == 1 and world.passed == 1, "Boosted crossing scores exactly once")
	world.advance_flight(0.1, Vector2.ZERO, 37)
	expect(world.score == 1 and world.passed == 1, "Already passed ring cannot score twice")
	world.rings[1].position = Vector3(20, 10, -0.1)
	world.advance_flight(0.1, Vector2.ZERO, 22)
	expect(world.score == 1 and world.passed == 2, "Missing a ring does not award a point")
	world.rings[0].position.z = 23.9
	world.advance_flight(0.1, Vector2.ZERO, 22)
	expect(world.rings[0].position.z < -600, "Course recycles passed rings")
	world.advance_flight(5, Vector2(1,1), 22)
	expect(world.plane.position.x <= 25 and world.plane.position.y <= 29, "Flight stays within reachable bounds")
	service.device_connection_changed(150, false)
	expect(world.pilot == 0 and not world.flying, "Disconnected pilot pauses flight")
	world._restart()
	expect(world.score == 0 and world.distance == 0 and world.plane.position == Vector3(0,10,0), "Restart resets the course")
	# Full native button -> SDK player -> motion -> scene path, with synthetic state.
	var reader = root.get_node("Platform").NativeWii.new()
	reader.service = service
	reader.motion_service = root.get_node("Platform").motion
	var now := Time.get_unix_time_from_system()
	reader.accept_state({"buttons":1,"updated":now,"acceleration":[0,0,1]}, now)
	for i in 65:
		reader.accept_state({"buttons":0,"updated":Time.get_unix_time_from_system(),"acceleration":[0,0,1]}, Time.get_unix_time_from_system())
		world._physics_process(0.02)
		await create_timer(0.02).timeout
	expect(world.flying, "Native motion calibration starts the actual game")
	reader.accept_state({"buttons":0,"updated":now-5,"acceleration":[0,0,1]}, now)
	world._physics_process(0.02)
	expect(not world.flying and world.pilot == 0, "Stale native state pauses and releases the pilot")
	reader.free()
	world._restart()
	world._physics_process(0.0)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			world.camera.look_at(world.plane.position + Vector3(0,1,-35))
			await process_frame
			await RenderingServer.frame_post_draw
			expect(root.get_texture().get_image().save_png(argument.trim_prefix("--capture=")) == OK, "Flight screenshot saved")
	if not failures:
		print("Flight checks passed: %d synthetic motion/game assertions." % checks)
	quit(1 if failures else 0)

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
