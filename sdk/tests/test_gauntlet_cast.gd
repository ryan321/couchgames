extends SceneTree
const Cast = preload("res://examples/gauntlet/cast_assets.gd")
const Enemy = preload("res://examples/gauntlet/enemy_actor.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	for asset: String in Cast.ARMOR+Cast.WEAPONS+Cast.SHIELDS:
		var model := Cast.instance(asset)
		var meshes := model.find_children("*","MeshInstance3D",true,false)
		expect(not meshes.is_empty(),asset+" contains imported geometry")
		var valid := true
		for mesh: MeshInstance3D in meshes:
			for surface in mesh.mesh.get_surface_count(): valid = valid and mesh.mesh.surface_get_material(surface)!=null
		expect(valid,asset+" retains its materials")
		model.free()
	for asset: String in ["ElfArmor", "WarriorShield", "ValkyrieShield"]:
		var a := Cast.colored_instance(asset,Color.RED)
		var b := Cast.colored_instance(asset,Color.BLUE)
		root.add_child(a)
		root.add_child(b)
		var am := a.find_children("*","MeshInstance3D",true,false)
		var bm := b.find_children("*","MeshInstance3D",true,false)
		var painted := 0
		var isolated := true
		for i in am.size():
			for surface in am[i].mesh.get_surface_count():
				var material: Material = am[i].get_surface_override_material(surface)
				if not material: continue
				painted += 1
				var other: Material = bm[i].get_surface_override_material(surface)
				isolated = isolated and material!=other and material.albedo_color==Color.RED and other.albedo_color==Color.BLUE
		expect(painted>0 and isolated,"Authored armor/shield colors stay independent between players")
		# Match rapid lobby portrait replacement, including immediate instance release.
		a.free()
		b.free()
	for kind in ["ghost","grunt","demon"]:
		var a := Enemy.new()
		var b := Enemy.new()
		a.configure(kind)
		b.configure(kind)
		root.add_child(a)
		root.add_child(b)
		var meshes := a.model.find_children("*","MeshInstance3D",true,false)
		var copies := b.model.find_children("*","MeshInstance3D",true,false)
		var shared := meshes.size()<=8 and meshes.size()==copies.size()
		for i in meshes.size():
			shared = shared and meshes[i].mesh==copies[i].mesh and meshes[i].mesh.get_surface_count()==1
		expect(shared,"Enemy geometry is shared with at most eight single-surface parts")
		expect(a.arms.all(func(arm): return arm!=null),"Both arm pivots survive GLB import")
		var state := {"id":1,"attack_serial":0}
		a.present(state,.1,.1,.1,true)
		expect(a.arms[0].rotation!=b.arms[0].rotation,"Limb motion belongs to each enemy instance")
		var pose := a.arms[0].transform
		a.present(state,.1,.1,.2,false)
		expect(a.arms[0].transform==pose,"Pause freezes creature animation")
		expect(a.swing==0,"Standing or walking cannot trigger an attack swing")
		state.attack_serial = 1
		a.present(state,0,.05,.25,true)
		expect(a.swing>0,"Actual attack events trigger creature attack poses")
		for step in 30: a.present(state,0,.05,.25+step*.05,true)
		expect(a.swing==0 and a.movement<.001,"Stopped creatures settle without repeated attacks")
		if kind!="ghost":
			expect(a.legs.size()==2 and a.legs.all(func(leg): return leg!=null),"Ground creatures retain separate leg pivots")
			expect(a.calves.size()==2 and a.calves[0].get_parent()==a.legs[0],"Knees bend within the leg hierarchy")
			for step in 12: a.present(state,.1,.05,step*.05,true)
			expect(absf(a.calves[0].rotation.x)+absf(a.calves[1].rotation.x)>.01,"Moving enemies articulate their knees")
		if kind=="demon": expect(a.tail!=null and a.tail.rotation.length()>0,"Demon tail has independent follow-through")
		a.queue_free()
		b.queue_free()
	await process_frame
	var view: Node3D = load("res://examples/gauntlet/dungeon_view.gd").new()
	var warrior: Node3D = view.hero_model(0)
	root.add_child(warrior)
	var hero := {"pos":Vector2.ZERO,"face":Vector2.DOWN,"hp":100,"escaped":false,"attack_serial":0,"hit_serial":0,"magic_serial":0}
	warrior.present(hero,.016,true)
	for serial in [1,2]:
		hero.attack_serial = serial
		var previous := Vector3.ZERO
		var leading := 0.0
		for frame in 18:
			warrior.present(hero,.04,true)
			warrior.skeleton.force_update_all_bone_transforms()
			await process_frame
			var axe: Node3D = warrior.weapon.get_child(0)
			var center := axe.to_global(Vector3(.2,.65,0))
			var edge := axe.to_global(Vector3(.38,.65,0))
			var butt := axe.to_global(Vector3(-.03,.65,0))
			# Sample the striking portion after windup, not the recovery/back-swing.
			if frame in [3,4,5]: leading += (center-previous).dot((edge-butt).normalized())
			previous = center
		expect(leading>0,"Warrior's cutting edge leads strike %d, on repeated heavy sweeps"%serial)

	const Swing = preload("res://examples/gauntlet/axe_swing.gd")
	warrior.scale = Vector3.ONE*Swing.MODEL_SCALE
	for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		hero.attack_serial += 1
		hero.attack_face = direction
		hero.face = direction
		hero.attack_started = 0.0
		var matched := true
		var held := true
		var worst_gap := 0.0
		for frame in 37:
			var age := frame*.02
			hero.pos += direction*.4
			warrior.position = Vector3(hero.pos.x/32,0,hero.pos.y/32)
			warrior.present(hero,.02,true,age)
			var simulated := Swing.blade(age,direction)
			var blade: Vector3 = warrior.weapon.to_global(Swing.BLADE_OUTER)
			matched = matched and (Vector2(blade.x,blade.z)*32-hero.pos).distance_to(simulated[1])<.002
			var wrist: Transform3D = warrior.skeleton.get_bone_global_pose(warrior.skeleton.find_bone("hand_r"))
			worst_gap = maxf(worst_gap,warrior.skeleton.to_global(wrist.origin).distance_to(warrior.weapon.to_global(Swing.GRIP)))
			held = held and worst_gap<.055
		expect(matched,"Visible axe path matches the simulated blade throughout a moving swing in direction %s"%direction)
		expect(held,"Warrior keeps his hand around the axe grip through windup, contact and recovery (%s, gap %.3f)"%[direction,worst_gap])
		var paused: Transform3D = warrior.weapon.transform
		warrior.present(hero,.2,false,.4)
		expect(warrior.weapon.transform==paused,"Pause freezes the authored axe pose")
	warrior.free()
	view.free()
	await process_frame
	if failures==0: print("Gauntlet cast checks passed: ",checks," asset/animation assertions.")
	quit(1 if failures else 0)
