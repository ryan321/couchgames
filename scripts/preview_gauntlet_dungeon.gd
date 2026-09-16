extends SceneTree
## Render real game art and current party visibility; no gameplay/controller qualification.
var game: Node
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	game = load("res://examples/gauntlet/dungeon.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.set_physics_process(false)
	game.service.set_physics_process(false)
	game.sound.enabled = false
	game.sound.music_enabled = false
	game.controller_voice.enabled = false
	game.close_on_finish = false
	for kind in 4:
		game.heroes[kind+1] = game.make_hero(kind+1,kind)
		game.heroes[kind+1].pos = Vector2(128+kind*45,470)
		game.heroes[kind+1].face = Vector2.DOWN
	game.phase = "playing"
	game.sync_display()
	game.dungeon_view._process(0)
	game.dungeon_view.update_camera(1)
	await capture("dungeon_party")
	var original := {}
	for id: int in game.heroes:
		original[id] = game.heroes[id].pos
		game.heroes[id].pos = Vector2(9+id*.55,14.5)*32
	game.dungeon_view.update_camera(1)
	await capture("dungeon_closed_gate")
	game.keyring.ruby = 1
	game.keys = 1
	game.unlock(0)
	game.dungeon_view.gates[0].present(true,1)
	await capture("dungeon_open_gate")
	for id: int in game.heroes: game.heroes[id].pos = original[id]
	game.load_map()
	game.dungeon_view.rebuild()
	game.dungeon_view.overview = true
	game.heroes[3].pos = Vector2(1000,280)
	game.heroes[4].pos = Vector2(1040,320)
	game.dungeon_view.update_camera(1)
	await capture("dungeon_split_party")
	game.level_index = 2
	game.load_map()
	game.dungeon_view.rebuild()
	game.heroes.clear()
	for id in 16:
		game.heroes[id+1] = game.make_hero(id+1,id%4)
		game.heroes[id+1].pos = game.map.enemies[id%game.map.enemies.size()].pos+Vector2(id%3*12,0)
	game.dungeon_view.update_camera(1)
	await capture("dungeon_sixteen")
	game.queue_free()
	await process_frame
	quit()
func capture(name: String) -> void:
	game.sync_display()
	game.message_time = 0
	for frame in 12:
		game.phase = "playing"
		game.dungeon_view._process(0)
		game.board.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../art/gauntlet/"+name+".png")
	print("Saved ",path,": ",root.get_texture().get_image().save_png(path))
