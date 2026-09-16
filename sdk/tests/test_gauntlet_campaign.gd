extends SceneTree
## Real collision/key/exit routes; combat pressure is checked separately from puzzle solvability.
const Level = preload("res://examples/gauntlet/level.gd")
const DIRECTIONS := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
var game: Node
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func expect(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func route(target: Vector2) -> Array:
	var source := Level.cell(game.heroes[1].pos)
	var goal := Level.cell(target)
	var frontier: Array[Vector2i] = [source]
	var previous := {source:source}
	var cursor := 0
	while cursor<frontier.size():
		var at := frontier[cursor]
		cursor += 1
		if at==goal:
			var path: Array = []
			while at!=source:
				path.push_front(Level.center(at))
				at = previous[at]
			return path
		for direction in DIRECTIONS:
			var next: Vector2i = at+direction
			if next.x<=0 or next.y<=0 or next.x>=game.map.width-1 or next.y>=game.map.height-1: continue
			if game.walls.has(next) or previous.has(next): continue
			if game.doors.has(next):
				var color: String = game.map.door_colors[game.doors[next]]
				if int(game.keyring.get(color,0))<=0: continue
			previous[next] = at
			frontier.append(next)
	return []

func walk(path: Array) -> bool:
	for target: Vector2 in path:
		for hero: Dictionary in game.heroes.values():
			var guard := 0
			while hero.pos.distance_to(target)>1.0 and guard<120:
				hero.pos = game.slide(hero.pos,(target-hero.pos).limit_length(4),10,true)
				game.collect(hero)
				guard += 1
			if guard>=120: return false
	return true

func solve() -> int:
	var travelled := 0
	var safety := 0
	while game.pickups.any(func(p): return p.kind=="key") and safety<10:
		safety += 1
		var found := false
		for pickup: Dictionary in game.pickups.duplicate():
			if pickup.kind!="key": continue
			var path := route(pickup.pos)
			if path.is_empty(): continue
			travelled += path.size()
			if not walk(path): return -1
			found = true
			break
		if not found: return -1
	var exit_path := route(game.map.exit)
	if exit_path.is_empty() or not walk(exit_path): return -1
	travelled += exit_path.size()
	game.check_finish(0)
	return travelled

func run() -> void:
	game = load("res://examples/gauntlet/dungeon.tscn").instantiate()
	root.add_child(game)
	game.close_on_finish = false
	game.set_process(false)
	game.set_physics_process(false)
	game.dungeon_view.set_process(false)
	game.sound.enabled = false
	game.service.set_process_input(false)
	game.service.set_physics_process(false)
	for count in [1,16]:
		for id: int in game.heroes.keys(): game.leave(id)
		for id in range(1,count+1): game.join(id)
		game.start()
		var first_route := solve()
		expect(first_route>0 and game.phase=="complete","Entire party can solve level one and reach its exit")
		var previous_area: int = game.map.width*game.map.height
		var previous_nests: int = game.generators.size()
		var previous_enemies: int = game.enemies.size()
		var previous_route := first_route
		for chapter in [1,2]:
			var score: int = game.score
			var color: int = game.heroes[1].color_index
			var hero_class: int = game.heroes[1].hero_class
			game._process(3.0)
			expect(game.level_index==chapter-1 and game.phase=="complete","Animated transition holds before advancing")
			game.board._process(0)
			expect(game.board.retry_button.visible and not game.board.retry_button.disabled and not game.board.library_button.visible,"Transition offers a controller/click Continue action")
			game._process(3.1)
			expect(game.level_index==chapter and game.phase=="playing","Exit countdown advances into the next level")
			expect(game.heroes.size()==count and game.escaped_count()==0 and game.heroes[1].color_index==color and game.heroes[1].hero_class==hero_class and game.score==score,"Party identity and treasure survive advancement")
			expect(game.heroes[1].potions>=2 and game.heroes[1].hp>=Level.CLASSES[hero_class].health*0.65,"Next chapter supplies health and potions")
			var area: int = game.map.width*game.map.height
			expect(area>previous_area and game.generators.size()>previous_nests and game.enemies.size()>previous_enemies,"Every later map is larger and starts with more enemies and generators")
			previous_area = area
			previous_nests = game.generators.size()
			previous_enemies = game.enemies.size()
			expect(game.map.door_colors.size()==(3 if chapter==1 else 5),"Later maps introduce three then five colored locks")
			expect(game.dungeon_view.gates.size()==game.map.door_colors.size(),"Each lock has one persistent gate instead of overlapping tile labels")
			var closed_visible := true
			for gate: Node3D in game.dungeon_view.gates.values():
				closed_visible = closed_visible and not gate.is_open and gate.status.text==gate.key_color.capitalize() and gate.leaves.all(func(leaf): return leaf.visible)
			expect(closed_visible,"Closed gates show solid colored leaves and only the color name")
			var spawns_clear := true
			for hero: Dictionary in game.heroes.values(): spawns_clear = spawns_clear and not game.blocked(hero.pos,10)
			expect(spawns_clear,"All sixteen possible spawns fit the new map")
			for pickup: Dictionary in game.pickups:
				expect(not game.blocked(pickup.pos,10),"Pickup has a clear floor cell on chapter %d"%chapter)
			for enemy: Dictionary in game.enemies:
				expect(not game.blocked(enemy.pos,9),"Initial enemy has a clear floor cell")
			for generator: Dictionary in game.generators:
				expect(not game.blocked(generator.pos,10),"Generator has a clear floor cell")
			# Wrong-colored keys neither open gates nor get consumed.
			game.keyring = {"amethyst":1}
			game.keys = 1
			var before: int = game.doors.size()
			game.unlock(0)
			expect(game.doors.size()==before and game.keyring.amethyst==1 and game.keys==1,"Wrong color cannot open or consume a key for a ruby gate")
			game.keys = 0
			game.keyring.clear()
			expect(route(game.map.exit).is_empty(),"Exit cannot bypass the locked route")
			# Ensure the wide camera fits party members at opposite walkable corners.
			game.heroes[1].pos = game.map.exit
			game.dungeon_view.overview = false
			game.dungeon_view.update_camera(1.0/60)
			var screen := Rect2(Vector2.ZERO,Vector2(game.dungeon_view.get_viewport().size))
			var in_view := true
			for hero: Dictionary in game.heroes.values():
				for height in [0.0,2.4]: in_view = in_view and screen.has_point(game.dungeon_view.camera.unproject_position(game.dungeon_view.at3(hero.pos,height)))
			expect(in_view,"Expanded map camera keeps every party member in frame")
			game.heroes[1].pos = Level.spawn(1,chapter)
			var layouts: Dictionary = game.map.door_axes
			expect(layouts.values().has(true) and layouts.values().has(false),"Locked passages enter from both horizontal and vertical directions")
			expect(game.map.visible_cells.size()<area*0.8,"Dungeon footprint is irregular rather than a filled rectangular grid")
			var travelled := solve()
			expect(travelled>previous_route and game.phase=="complete" and game.escaped_count()==count,"Full colored-key collision route reaches exit and grows longer each chapter")
			previous_route = travelled
			expect(game.doors.is_empty() and game.keys==0,"Solving the level consumes exactly the matching keys")
			game.dungeon_view._process(0)
			var open_visible := true
			for gate: Node3D in game.dungeon_view.gates.values():
				open_visible = open_visible and gate.is_open and gate.status.text==gate.key_color.capitalize()
				gate.present(true,0.3)
				open_visible = open_visible and gate.leaves.all(func(leaf): return not leaf.visible)
			expect(open_visible,"Unlocked gates keep only the color name and retract all panels out of the passage")
			print("Campaign route: ",count," players, chapter ",chapter+1,", ",travelled," tiles; collision and keys, combat disabled.")
		game.reset_level()
		expect(game.level_index==0 and game.keyring.is_empty() and game.phase=="lobby","New run returns to the first vault with no stale colored keys")
	game.queue_free()
	await process_frame
	if failures==0: print("Gauntlet campaign checks passed: ",checks," synthetic route/progression assertions.")
	quit(1 if failures else 0)
