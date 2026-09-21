extends SceneTree
## Reusable join/ready lobby. Synthetic devices only.

var checks := 0
var failures := 0
const DEVICE := 120


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var platform: Node = root.get_node("Platform")
	platform.input.keyboard_enabled = true
	var lobby: CanvasLayer = platform.install_lobby()
	await process_frame
	await physics_frame
	expect(platform.has_method("install_lobby"), "install_lobby exists")
	expect(lobby.visible, "Lobby starts visible")
	expect(not lobby.started, "Match has not started")
	var started := [false]
	lobby.match_started.connect(func(): started[0] = true)
	var service = platform.input
	press(service, 0, true)
	expect(service.players.size() == 1, "First A joins a player")
	expect(not lobby.all_ready(), "Joined player is not ready yet")
	press(service, 0, true)
	expect(lobby.ready_players.get(1, false) == true, "Second A readies player 1")
	expect(lobby.all_ready(), "Single ready player counts as all ready")
	expect(lobby.started, "lobby.started is true")
	expect(not lobby.visible, "lobby hides")
	expect(started[0], "match_started signal fired")
	if not failures:
		print("SDK lobby checks passed: %d assertions." % checks)
	quit(1 if failures else 0)


func press(service: Node, device: int, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = DEVICE + device
	event.button_index = JOY_BUTTON_A
	event.pressed = down
	service.handle_event(event)
	if down:
		lobby_unhandled(event)

func lobby_unhandled(event: InputEvent) -> void:
	var lobby: Node = root.get_node("Platform/LobbyOverlay")
	lobby._unhandled_input(event)


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
