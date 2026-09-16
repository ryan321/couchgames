extends RefCounted
## Match the hand to the authored weapon trajectory while locomotion continues below it.
const Swing = preload("res://examples/gauntlet/axe_swing.gd")
var serial := 0
var age := 100.0
var facing := Vector2.DOWN

func advance(hero: Dictionary, delta: float, playing: bool, now: float) -> void:
	if not playing: return
	if hero.get("attack_serial",0)!=serial:
		serial = hero.attack_serial
		age = 0.0
		facing = hero.get("attack_face",hero.face)
	else: age += delta
	if now>=0: age = now-float(hero.get("attack_started",-100.0))
	if hero.hp<=0 or hero.escaped: age = 100.0

func present(actor: Node3D) -> void:
	var direction: Vector2 = facing if age<Swing.DURATION else Vector2(sin(actor.outfit.rotation.y),cos(actor.outfit.rotation.y))
	actor.weapon.transform = Transform3D(Basis(Vector3.UP,atan2(direction.x,direction.y)),Vector3.ZERO)*Swing.pose(age)
	var rig: Skeleton3D = actor.skeleton
	var target := rig.to_local(actor.weapon.to_global(Swing.GRIP))
	var upper := rig.find_bone("upperarm_r")
	var lower := rig.find_bone("lowerarm_r")
	var hand := rig.find_bone("hand_r")
	var a := rig.get_bone_global_rest(upper)
	var b := rig.get_bone_global_rest(lower)
	var c := rig.get_bone_global_rest(hand)
	var shoulder := rig.get_bone_global_pose(upper).origin
	var first := a.origin.distance_to(b.origin)
	var second := b.origin.distance_to(c.origin)
	var aim := (target-shoulder).normalized()
	var distance := clampf(shoulder.distance_to(target),.01,first+second-.001)
	var along := (first*first-second*second+distance*distance)/(2*distance)
	var pole := Vector3(-1,-.5,-.15)
	var bend := (pole-aim*pole.dot(aim)).normalized()
	var elbow := shoulder+aim*along+bend*sqrt(maxf(0,first*first-along*along))
	var upper_basis := Basis(Quaternion((b.origin-a.origin).normalized(),(elbow-shoulder).normalized()))*a.basis
	var lower_basis := Basis(Quaternion((c.origin-b.origin).normalized(),(target-elbow).normalized()))*b.basis
	var parent := rig.get_bone_global_pose(rig.get_bone_parent(upper)).basis
	rig.set_bone_pose_rotation(upper,(parent.inverse()*upper_basis).get_rotation_quaternion())
	rig.set_bone_pose_rotation(lower,(upper_basis.inverse()*lower_basis).get_rotation_quaternion())
	var grip: Basis = (rig.global_basis.inverse()*actor.weapon.global_basis).orthonormalized()
	rig.set_bone_pose_rotation(hand,(lower_basis.inverse()*grip).orthonormalized().get_rotation_quaternion())
	rig.force_update_all_bone_transforms()
