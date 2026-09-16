extends SceneTree
const Steering = preload("res://examples/pocket_rally/steering.gd")
const Fleet = preload("res://examples/pocket_rally/wii_fleet.gd")
var checks := 0
var failures := 0
var service: Node
var world: Node

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var controls := Steering.new()
	for i in 90:
		controls.update({"acceleration":Vector3(0,0,1),"updated":100.0},0.02)
	expect(not controls.ready,"Repeated stale pose cannot calibrate")
	for i in 65:
		controls.update({"acceleration":Vector3(0,0,1),"updated":101.0+i*0.02},0.02)
	expect(controls.ready,"Steady fresh samples calibrate")
	for pose in [Vector3(0,-0.5,0.866),Vector3(0,0.5,0.866)]:
		for i in 60:
			controls.update({"acceleration":pose,"updated":104.0+i*0.02},0.02)
		expect(controls.value * -signf(pose.y) > 0.95,"Wheel tilt turns toward the lowered end")
	controls.update({},0.02)
	expect(not controls.ready and controls.value == 0,"Missing motion clears steering")
	world = load("res://examples/pocket_rally/rally.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	service = root.get_node("Platform").input
	var motion = root.get_node("Platform").motion
	motion.set_physics_process(false)
	var fleet := Fleet.new()
	fleet.service = service
	fleet.motion = motion
	for slot in 16:
		fleet.accept_packet(slot,packet(slot,1),Time.get_unix_time_from_system())
		world.cars[slot+1].set_physics_process(false)
		if slot in [1,3,15]:
			await process_frame
			world._layout()
			check_layout(slot+1)
	expect(world.cars.size() == 16 and service.players.size() == 16,"Sixteen separate Wii channels join sixteen cars")
	press(222,JOY_BUTTON_A)
	expect(world.cars.size() == 16,"Seventeenth controller cannot join")
	for id in range(1,17):
		expect(world.panes[id].viewport.world_3d == world.get_world_3d(),"Each camera observes the shared race world")
		world.cars[id].calibration.ready = true
		world.cars[id].calibration.neutral = 0
		world.cars[id].calibration.value = 0
	# Fresh native samples calibrate each actual car separately.
	world.cars[1].calibration.reset()
	world.cars[2].calibration.reset()
	for i in 65:
		fleet.accept_packet(0,packet(0,0),Time.get_unix_time_from_system())
		world.cars[1]._physics_process(0.02)
		world.cars[2]._physics_process(0.02)
		await create_timer(0.02).timeout
	expect(world.cars[1].calibration.ready and not world.cars[2].calibration.ready,"Fresh samples calibrate only their actual car")
	world.cars[2].calibration.ready = true
	# Exercise two real CharacterBody3D cars; the remaining cameras stay present.
	var car = world.cars[1]
	var other = world.cars[2]
	var start: Vector3 = car.position
	var other_start: Vector3 = other.position
	for i in 35:
		fleet.accept_packet(0,packet(0,1,[0,-0.5,0.866]),Time.get_unix_time_from_system())
		fleet.accept_packet(1,packet(1,0),Time.get_unix_time_from_system())
		car._physics_process(1.0/60)
		other._physics_process(1.0/60)
		await physics_frame
	expect(car.position.distance_to(start)>0.5 and car.speed>0,"Wii 2 drives the actual car")
	expect(car.rotation.y < -PI/2-0.1,"Right tilt turns the actual car right")
	expect(other.position.distance_to(other_start)<0.15 and other.speed==0,"Other controller remains stopped")
	expect(absf(car.position.y)<0.15,"Car rests on the physical track floor")
	motion.remove_device(1000)
	car._physics_process(0.02)
	expect(not car.driving and car.speed == 0 and not car.calibration.ready,"Lost motion parks only its car and requires recalibration")
	expect(other.calibration.ready,"Another driver's calibration survives missing motion")
	car.toggle_mode()
	car.rescue()
	fleet.accept_packet(0,packet(0,2),Time.get_unix_time_from_system())
	for i in 25:
		car._physics_process(1.0/60)
		await physics_frame
	expect(car.speed < 0 and car.position.x < car.spawn.x,"Wii 1 reverses a stopped car")
	car.rescue()
	car.position = Vector3(31,0.08,0)
	fleet.accept_packet(0,packet(0,1),Time.get_unix_time_from_system())
	for i in 90:
		car._physics_process(1.0/60)
		await physics_frame
	expect(car.position.x < 33.4,"Outer barrier contains a car driving into it")
	car.rescue()
	car.lap_seconds = 20
	for gate in 4:
		world.check_progress(car,track_point(gate*PI/2-0.02),track_point(gate*PI/2+0.02))
	expect(car.laps == 1 and car.best_lap == 20,"Four ordered forward checkpoints score one lap")
	world.check_progress(car,track_point(0.02),track_point(-0.02))
	world.check_progress(car,track_point(PI-0.02),track_point(PI+0.02))
	world.check_progress(car,Vector3.ZERO,Vector3(26,0,1))
	expect(car.next_gate == 0 and car.laps == 1,"Reverse, skipped checkpoints and infield shortcuts cannot score")
	car.next_gate = 3
	car.rescue()
	expect(car.next_gate == 0 and car.laps == 1,"Rescue clears partial lap but keeps completed laps")
	var old_instance: int = car.get_instance_id()
	var replaced := packet(0,1)
	replaced.generation = "replacement"
	fleet.accept_packet(0,replaced,Time.get_unix_time_from_system())
	world.cars[1].set_physics_process(false)
	expect(world.cars[1].get_instance_id() != old_instance and world.cars[1].laps == 0,"Reused native slot creates a fresh car")
	expect(world.cars[2] == other,"Reconnecting one controller preserves other cars")
	fleet.accept_packet(4,null,Time.get_unix_time_from_system())
	expect(not world.cars.has(5) and not world.panes.has(5),"Disconnected device removes its car and camera")
	var stale := packet(5,1)
	stale.updated -= 3
	fleet.accept_packet(5,stale,Time.get_unix_time_from_system())
	expect(not world.cars.has(6),"Expired native channel leaves independently")
	for slot in [4,5]:
		fleet.accept_packet(slot,packet(slot,1),Time.get_unix_time_from_system())
		world.cars[slot+1].set_physics_process(false)
	expect(world.cars.size() == 16,"Rejoining fills freed slots")
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			for count in [16,4,2]:
				for id in world.cars.keys():
					if id > count:
						service.leave(id)
				world._new_race()
				for remaining in world.cars.values():
					remaining.status = "TILT"
					remaining.use_motion = true
				world._process(1.0)
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				expect(root.get_texture().get_image().save_png(argument.trim_prefix("--capture=")+"-%d.png"%count)==OK,"Rendered split-screen capture saved")
	for slot in 16:
		fleet.accept_packet(slot,null,Time.get_unix_time_from_system())
	expect(world.cars.is_empty() and world.panes.has(0),"Empty session restores track preview")
	fleet.free()
	if not failures:
		print("Rally checks passed: %d synthetic controller/camera/physics assertions."%checks)
	quit(1 if failures else 0)

func packet(slot: int, buttons: int, acceleration := [0,0,1]) -> Dictionary:
	return {"generation":"remote-%d"%slot,"buttons":buttons,"acceleration":acceleration,"updated":Time.get_unix_time_from_system()}

func press(device: int, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = true
	service.handle_event(event)

func track_point(angle: float) -> Vector3:
	return Vector3(cos(angle)*26,0,sin(angle)*16.5)

func check_layout(count: int) -> void:
	expect(world.panes.size()==count,"One viewport per player")
	var rects: Array[Rect2] = []
	for pane in world.panes.values():
		var rect := Rect2(pane.panel.position,pane.panel.size)
		expect(rect.size.x>100 and rect.size.y>100,"Each split view has usable dimensions")
		for previous in rects:
			expect(not rect.intersects(previous),"Split views do not overlap")
		rects.append(rect)
	if count == 2:
		expect(is_equal_approx(rects[0].position.y,rects[1].position.y),"Two-player layout is side by side")

func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
