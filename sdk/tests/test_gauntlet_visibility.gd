extends SceneTree
const Sight = preload("res://examples/gauntlet/party_visibility.gd")
const Props = preload("res://examples/gauntlet/environment_assets.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var sight := Sight.new()
	var heroes := {1:{"pos":Vector2(320,320),"hp":100,"escaped":false}}
	sight.update(heroes,"playing",Vector2.ZERO)
	expect(sight.visibility_at(Vector2(10,10))==1,"Hero stands in fully clear sight")
	expect(sight.visibility_at(Vector2(17,10))==1,"Seven tiles around each player are fully clear")
	expect(sight.visibility_at(Vector2(18.5,10))>.4 and sight.visibility_at(Vector2(18.5,10))<.6,"Three-tile edge fades gradually")
	expect(sight.visibility_at(Vector2(21,10))==0,"Distant room details are concealed")
	heroes[1].pos = Vector2(1600,320)
	sight.update(heroes,"playing",Vector2.ZERO)
	expect(sight.visibility_at(Vector2(10,10))==0,"Previous rooms become hidden immediately; no permanent exploration memory")
	heroes[2] = {"pos":Vector2(320,320),"hp":0,"escaped":false}
	sight.update(heroes,"paused",Vector2.ZERO)
	expect(sight.visibility_at(Vector2(10,10))==1 and sight.visibility_at(Vector2(50,10))==1,"Separate bubbles include fallen teammates and remain during pause")
	heroes[2].escaped = true
	sight.update(heroes,"playing",Vector2.ZERO)
	expect(sight.visibility_at(Vector2(10,10))==0,"Escaped players leave no lingering vision")
	heroes.erase(1)
	sight.update(heroes,"playing",Vector2.ZERO)
	expect(sight.visibility_at(Vector2(50,10))==0,"Disconnect removes that player's sight")
	heroes.clear()
	for id in 16: heroes[id+1] = {"pos":Vector2(id*1024,320),"escaped":false,"hp":100}
	sight.update(heroes,"playing",Vector2.ZERO)
	for hero: Dictionary in heroes.values(): expect(sight.visibility_at(hero.pos/32)==1,"Each of sixteen separated players contributes sight")
	sight.update({},"complete",Vector2(160,160))
	expect(sight.visibility_at(Vector2(5,5))==1 and sight.visibility_at(Vector2(30,30))==0,"All-party completion keeps the exit visible without revealing the map")
	sight.update({},"lobby",Vector2.ZERO)
	expect(not sight.active,"Lobby is never covered by gameplay fog")

	for asset: String in Props.NAMES:
		var a := Props.instance(asset)
		var b := Props.instance(asset)
		var meshes := a.find_children("*","MeshInstance3D",true,false)
		var copies := b.find_children("*","MeshInstance3D",true,false)
		expect(meshes.size()==1 and copies.size()==1 and meshes[0].mesh==copies[0].mesh,asset+" uses one shared mesh")
		expect(meshes[0].mesh.get_aabb().size.length()>.1,asset+" has real imported geometry")
		a.free()
		b.free()
	var game: Node = load("res://examples/gauntlet/dungeon.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.sound.enabled = false
	game.controller_voice.enabled = false
	game.heroes[1] = game.make_hero(1,0)
	game.phase = "playing"
	game.dungeon_view._process(0)
	var camera: Camera3D = game.dungeon_view.camera
	var fog: Node3D = game.dungeon_view.party_fog
	var tile: Vector2 = game.heroes[1].pos/32
	var pixel := camera.unproject_position(Vector3(tile.x,0,tile.y))
	expect(fog.floor_point(camera,pixel).distance_to(tile)<.001,"Fog projection follows real orthographic camera coordinates")
	game.dungeon_view.overview = true
	game.dungeon_view.update_camera(1)
	pixel = camera.unproject_position(Vector3(tile.x,0,tile.y))
	expect(fog.floor_point(camera,pixel).distance_to(tile)<.001,"Overview zoom retains correct world-space fog radius")
	expect(game.dungeon_view.visibility.visibility_at(Vector2(100,100))==0,"Overview cannot reveal distant rooms")
	game.heroes[1].pos = Vector2(900,100)
	game.dungeon_view._process(0)
	expect(game.dungeon_view.visibility.visibility_at(tile)==0,"Live dungeon updates sight after player movement")

	game.heroes[1].pos = Vector2(11.5,14.5)*32
	game.enemies = [{"id":9901,"pos":Vector2(13.5,14.5)*32,"kind":"grunt","hp":50.0,"max_hp":50.0,"attack":1.0}]
	game.pickups = [{"kind":"key","key_color":"sapphire","pos":Vector2(14.5,14.5)*32}]
	game.dungeon_view._process(0)
	expect(game.dungeon_view.actors["enemy-9901"].visible,"Nearby enemies stay visible across a closed Ruby gate")
	var pickup_key: String = "pickup-key-%s"%game.pickups[0].pos
	expect(game.dungeon_view.actors[pickup_key].visible,"Nearby key models and labels remain visible through walls and doors")
	game.keyring.ruby = 1
	game.keys = 1
	game.unlock(0)
	game.dungeon_view._process(0)
	expect(game.dungeon_view.actors["enemy-9901"].visible and game.dungeon_view.actors[pickup_key].visible,"Opening the gate leaves nearby visibility unchanged")
	game.heroes[1].pos = Vector2(30,3)*32
	game.dungeon_view._process(0)
	expect(not game.dungeon_view.actors["enemy-9901"].visible and not game.dungeon_view.actors[pickup_key].visible,"Moving away hides enemies and keys outside the current radius")
	game.heroes[1].pos = Vector2(11.5,12.5)*32
	game.enemies[0].pos = Vector2(13.5,12.5)*32
	game.dungeon_view._process(0)
	expect(game.dungeon_view.actors["enemy-9901"].visible,"Nearby enemies across a solid wall remain visible inside the radius")
	game.reset_level()
	game.dungeon_view._process(0)
	expect(not fog.screen.visible,"Returning to lobby removes the overlay")
	game.queue_free()
	await process_frame
	if failures==0: print("Gauntlet visibility checks passed: ",checks," fog/projection/prop assertions.")
	quit(1 if failures else 0)
