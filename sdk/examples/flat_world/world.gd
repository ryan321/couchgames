extends Node2D
## 2D couch starter: lobby, then hop around a floor. CSG-free ColorRects only.

const COLORS: Array[Color] = [Color("ed7559"), Color("5ba7db"), Color("d6ab43"), Color("ad84c6"),
	Color("57b99c"), Color("e38eb0"), Color("95a74c"), Color("dd9653")]

var characters: Dictionary = {}
var _input_service: Node
var _lobby: CanvasLayer


func _ready() -> void:
	var platform := get_node("/root/Platform")
	platform.install_shell()
	_lobby = platform.install_lobby()
	_input_service = platform.input
	_input_service.keyboard_enabled = true
	_build_stage()
	_input_service.player_joined.connect(func(id: int):
		if _lobby.started:
			_spawn(id))
	_input_service.player_left.connect(_remove)
	_lobby.match_started.connect(func():
		for id: int in _input_service.players:
			_spawn(id))


func _build_stage() -> void:
	var sky := ColorRect.new()
	sky.color = Color("1a2e38")
	sky.position = Vector2.ZERO
	sky.size = Vector2(1600, 900)
	add_child(sky)
	var floor := StaticBody2D.new()
	floor.position = Vector2(800, 780)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(1600, 80)
	shape.shape = box
	floor.add_child(shape)
	var vis := ColorRect.new()
	vis.color = Color("8ce8be")
	vis.position = Vector2(-800, -40)
	vis.size = Vector2(1600, 80)
	floor.add_child(vis)
	add_child(floor)
	var camera := Camera2D.new()
	camera.position = Vector2(800, 450)
	add_child(camera)
	camera.make_current()


func _spawn(id: int) -> void:
	if characters.has(id):
		return
	var body := CharacterBody2D.new()
	body.set_script(preload("res://examples/flat_world/hopper.gd"))
	body.player_id = id
	body.color = COLORS[(id - 1) % COLORS.size()]
	body.input_service = _input_service
	body.position = Vector2(280 + (id - 1) * 90.0, 640)
	add_child(body)
	characters[id] = body


func _remove(id: int) -> void:
	if not characters.has(id):
		return
	var node: Node = characters[id]
	characters.erase(id)
	node.queue_free()
