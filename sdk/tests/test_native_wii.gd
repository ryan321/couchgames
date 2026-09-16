extends SceneTree

const NativeWii = preload("res://addons/couchgames/native_wii.gd")
const PlayerInput = preload("res://addons/couchgames/player_input.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var service := PlayerInput.new()
	root.add_child(service)
	service.set_process_input(false)
	service.set_physics_process(false)
	var reader := NativeWii.new()
	reader.service = service
	for invalid in [null, {}, {"buttons":"1", "updated":100}, {"buttons":1.5,"updated":100},
		{"buttons":65536,"updated":100}, {"buttons":-1,"updated":100},
		{"buttons":1,"updated":90}, {"buttons":1,"updated":110}]:
		expect(not reader.valid_state(invalid, 100), "Reject malformed or stale native input")
	reader.accept_state({"buttons":1,"updated":100}, 100)
	expect(service.player_for_device(reader.DEVICE) == 1, "Physical 2 bit joins a player")
	reader.accept_state({"buttons":0,"updated":100}, 100)
	reader.accept_state({"buttons":1,"updated":100}, 100)
	expect(service.consume_jump(1), "Second physical 2 press jumps")
	reader.accept_state({"buttons":1,"updated":100}, 100)
	expect(not service.consume_jump(1), "Repeated snapshots do not repeat jumps")
	reader.accept_state({"buttons":0x1000,"updated":100}, 100)
	expect(service.players[1].buttons.get(JOY_BUTTON_START,false),"Wii Plus maps to the standard Start/menu action")
	reader.accept_state({"buttons":0x800,"updated":100}, 100)
	expect(service.movement(1) == Vector2.LEFT, "Sideways D-pad orientation is preserved")
	reader.accept_state({"buttons":0x800,"updated":100}, 103)
	expect(service.players.is_empty(), "Expired reader removes its player and held input")
	reader.accept_state({"buttons":0,"updated":104}, 104)
	expect(service.players.is_empty(), "Reader reconnect waits for a join press")
	reader.accept_state({"buttons":1,"updated":104}, 104)
	expect(service.player_for_device(reader.DEVICE) == 1, "Rejoin reuses the freed slot")
	reader.accept_state(null, 104)
	expect(service.players.is_empty(), "Missing state removes the native player")
	reader.free()
	service.queue_free()
	await process_frame
	if not failures:
		print("Native Wii checks passed: %d synthetic assertions." % checks)
	quit(1 if failures else 0)


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
