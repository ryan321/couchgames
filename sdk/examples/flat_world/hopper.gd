extends CharacterBody2D

const SPEED := 420.0
const GRAVITY := 1800.0
const JUMP := 780.0

var player_id := 1
var color := Color("ed7559")
var input_service: Node
var spawn := Vector2.ZERO


func _ready() -> void:
	spawn = position
	collision_layer = 2
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(48, 64)
	collision.shape = box
	add_child(collision)
	var vis := ColorRect.new()
	vis.color = color
	vis.position = Vector2(-24, -32)
	vis.size = Vector2(48, 64)
	add_child(vis)
	var tag := Label.new()
	tag.text = str(player_id).pad_zeros(2)
	tag.position = Vector2(-20, -58)
	tag.add_theme_font_size_override("font_size", 18)
	tag.add_theme_color_override("font_color", Color("f2f5f8"))
	add_child(tag)


func _physics_process(delta: float) -> void:
	if input_service == null:
		return
	velocity.y += GRAVITY * delta
	var move: Vector2 = input_service.movement(player_id)
	velocity.x = move.x * SPEED
	if is_on_floor() and input_service.consume_jump(player_id):
		velocity.y = -JUMP
	move_and_slide()
	if position.y > 1100:
		position = spawn
		velocity = Vector2.ZERO
