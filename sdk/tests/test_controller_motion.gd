extends SceneTree
const Motion = preload("res://addons/couchgames/controller_motion.gd")
const Profiles = preload("res://addons/couchgames/controller_profiles.gd")
const PlayerInput = preload("res://addons/couchgames/player_input.gd")
const FlightControls = preload("res://examples/cloudbound/flight_controls.gd")
var checks := 0
var failures := 0

class FakeControllers extends RefCounted:
	var devices: Array = []
	var sensors: Dictionary = {}
	var enabled: Dictionary = {}
	var accel: Dictionary = {}
	var changes: Array = []
	func get_connected_joypads() -> Array: return devices
	func has_joy_motion_sensors(device: int) -> bool: return sensors.get(device, false)
	func is_joy_motion_sensors_enabled(device: int) -> bool: return enabled.get(device, false)
	func set_joy_motion_sensors_enabled(device: int, value: bool) -> void:
		enabled[device] = value
		changes.append([device, value])
	func get_joy_accelerometer(device: int) -> Vector3: return accel.get(device, Vector3.ZERO)
	func get_joy_gyroscope(_device: int) -> Vector3: return Vector3.ZERO

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var names := {"Nintendo Switch Pro Controller":"switch_pro", "Joy-Con (L)":"switch_joycon_left",
		"Joy-Con (R)":"switch_joycon_right", "Joy-Con (L/R)":"switch_joycon_pair",
		"Nintendo Switch 2 Pro Controller":"switch2_pro", "Joy-Con 2 (L)":"switch2_joycon_left",
		"Joy-Con 2 (R)":"switch2_joycon_right", "Joy-Con 2 (L/R)":"switch2_joycon_pair"}
	var service := PlayerInput.new()
	root.add_child(service)
	service.set_process_input(false)
	for name: String in names:
		var profile := Profiles.detect(name)
		expect(profile["id"] == names[name], "Recognize " + name)
		service.set_device_profile(150, profile["id"])
		for button in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y]:
			var event := InputEventJoypadButton.new()
			event.device = 150
			event.button_index = button
			event.pressed = true
			service.handle_event(event)
			expect(service.player_for_device(150) == 1, name + " can join with any face button")
			service.leave(1)
	var fake := FakeControllers.new()
	fake.devices = [150,151,152]
	fake.sensors = {150:true,151:true,152:false}
	fake.accel = {150:Vector3(0,-9.80665,0),151:Vector3(0,-9.80665,0)}
	fake.enabled[151] = true # Borrowed sensor: don't turn off another consumer's request.
	var motion := Motion.new()
	motion.backend = fake
	motion.input_service = service
	motion.set_enabled(true)
	motion.poll(100)
	expect(fake.changes == [[150,true]], "Enable only supported, disabled sensors")
	expect(motion.sample_for_device(150,100)["acceleration"].is_equal_approx(Vector3(0,0,1)), "Godot SI units become grip-frame g")
	expect(motion.sample_for_device(152,100).is_empty(), "No fabricated motion for a controller without sensors")
	expect(motion.status_for_device(152) == "unavailable", "Unavailable motion has an explicit status")
	for i in 65:
		motion.poll(100+i*0.02)
	expect(fake.changes.size() == 1, "Don't re-enable sensors every frame")
	expect(not motion.sample_for_device(150,101.28).is_empty(), "A stationary controller stays usable")
	fake.accel[150] = Vector3.ZERO
	motion.poll(102)
	expect(motion.sample_for_device(150,102).is_empty(), "Missing accelerometer data doesn't look calibrated")
	fake.accel[150] = Vector3(INF,0,0)
	motion.poll(102)
	expect(motion.sample_for_device(150,102).is_empty(), "Reject invalid sensor data")
	fake.devices = [151,152]
	motion.poll(103)
	expect(motion.sample_for_device(150,103).is_empty(), "Disconnect clears that device")
	expect(not motion.sample_for_device(151,103).is_empty(), "Disconnect preserves the other device")
	fake.devices.append(150)
	fake.enabled[150] = false
	fake.accel[150] = Vector3(0,-9.80665,0)
	motion.poll(104)
	expect(fake.changes.size() == 2, "Reused device ID gets a fresh sensor request")
	motion.set_enabled(false)
	expect(fake.enabled[150] == false and fake.enabled[151] == true, "Release owned sensors and preserve borrowed sensors")
	expect(motion.sample_for_device(151,104).is_empty(), "Disabling the service clears its polled samples")
	# Normalize driver samples through the real SDK and real flight controller.
	# Godot axes: left / down / away; flat rest is negative Y gravity.
	for pose in [[Vector3(-4.903325,-8.49281,0),Vector2.LEFT],
		[Vector3(4.903325,-8.49281,0),Vector2.RIGHT],
		[Vector3(0,-8.49281,-4.903325),Vector2(0,-1)],
		[Vector3(0,-8.49281,4.903325),Vector2(0,1)]]:
		var controls := FlightControls.new()
		for i in 65:
			motion.submit_engine(150,Vector3(0,-9.80665,0),Vector3.ZERO,110+i*0.02)
			controls.update(motion.sample_for_device(150,110+i*0.02),0.02)
		var steer := Vector2.ZERO
		for i in 60:
			motion.submit_engine(150,pose[0],Vector3.ZERO,112+i*0.02)
			steer = controls.update(motion.sample_for_device(150,112+i*0.02),0.02)
		expect(steer.distance_to(pose[1]) < 0.04, "Driver motion preserves bank and roll-away pitch direction")
	motion.free()
	# Actual game selects this joined player's motion, not the native Wii's device.
	var world = load("res://examples/cloudbound/flight.tscn").instantiate()
	root.add_child(world)
	world.set_physics_process(false)
	var platform := root.get_node("Platform")
	var original_backend: Object = platform.motion.backend
	platform.motion.backend = fake
	platform.motion.set_physics_process(false)
	fake.devices = [150]
	fake.sensors[150] = true
	fake.accel[150] = Vector3(0,-9.80665,0)
	platform.input.set_device_profile(150,"switch_joycon_left")
	var join := InputEventJoypadButton.new()
	join.device = 150
	join.button_index = JOY_BUTTON_A
	join.pressed = true
	platform.input.handle_event(join)
	for i in 65:
		platform.motion.poll(Time.get_unix_time_from_system())
		world._physics_process(0.02)
		await create_timer(0.02).timeout
	expect(world.flying and world._motion_selected, "Non-Wii motion starts flight after calibration")
	fake.accel[150] = Vector3.ZERO
	platform.motion.poll(Time.get_unix_time_from_system())
	world._physics_process(0.02)
	expect(not world.flying, "Losing selected motion pauses instead of silently switching to stick")
	world._toggle_controls()
	world._physics_process(0.02)
	expect(world.flying, "Player can explicitly choose stick fallback")
	platform.input.device_connection_changed(150,false)
	expect(world.pilot == 0 and not world.flying, "Disconnect releases the Switch pilot")
	world.free()
	platform.motion.backend = original_backend
	service.free()
	if not failures:
		print("Controller motion checks passed: %d synthetic assertions." % checks)
	quit(1 if failures else 0)

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
