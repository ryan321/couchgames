extends Node3D
## Short, local feedback on real damage events; idle enemies incur no overlay draws.
const FLASH_TIME := 0.18
const BAR_HOLD := 1.15
const BAR_FADE := 0.40
var meshes: Array[MeshInstance3D] = []
var overlay: ShaderMaterial
var bar: MeshInstance3D
var bar_material: ShaderMaterial
var show_health := false
var bar_height := 1.5
var flashing := false
var recoil := 0.0

func configure(body: Node3D, health_bar := false, height := 1.5) -> void:
	show_health = health_bar
	bar_height = height
	for item in body.find_children("*","MeshInstance3D",true,false): meshes.append(item)
	overlay = ShaderMaterial.new()
	overlay.shader = preload("res://examples/gauntlet/shaders/hit_flash.gdshader")

static func health_color(fraction: float) -> Color:
	# Color supports the bar's length; it is never the only indication of remaining health.
	if fraction>0.5: return Color("dec07a").lerp(Color("93c6a7"),(fraction-0.5)*2)
	return Color("d77e76").lerp(Color("dec07a"),fraction*2)

func present(state: Dictionary, now: float) -> void:
	var age := maxf(0,now-float(state.get("hit_at",-100.0)))
	var alive: bool = state.hp>0
	var fraction := clampf(float(state.hp)/maxf(1,float(state.get("max_hp",state.hp))),0,1)
	var color := health_color(fraction) if show_health else Color("daa698")
	recoil = sin(clampf(age/FLASH_TIME,0,1)*PI) if alive else 0.0
	var active := age<FLASH_TIME and alive
	if active!=flashing:
		flashing = active
		for item in meshes: item.material_overlay = overlay if active else null
	if active:
		overlay.set_shader_parameter("hit_color",color)
		overlay.set_shader_parameter("opacity",(0.20 if show_health else 0.11)*(1.0-age/FLASH_TIME))
	var visible_bar := show_health and alive and age<BAR_HOLD+BAR_FADE
	if visible_bar and not bar: make_bar()
	if bar:
		bar.visible = visible_bar
		if visible_bar:
			bar_material.set_shader_parameter("health",fraction)
			bar_material.set_shader_parameter("health_color",color)
			bar_material.set_shader_parameter("fade",1.0-clampf((age-BAR_HOLD)/BAR_FADE,0,1))

func make_bar() -> void:
	bar = MeshInstance3D.new()
	bar.name = "RecentHealth"
	bar.position.y = bar_height
	var quad := QuadMesh.new()
	quad.size = Vector2(0.72,0.075)
	bar.mesh = quad
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar_material = ShaderMaterial.new()
	bar_material.shader = preload("res://examples/gauntlet/shaders/recent_health.gdshader")
	bar.material_override = bar_material
	add_child(bar)
