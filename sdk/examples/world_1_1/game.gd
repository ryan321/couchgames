extends Control
const Level = preload("res://examples/world_1_1/level.gd")
const Board = preload("res://examples/world_1_1/board.gd")
const Sound = preload("res://examples/world_1_1/audio.gd")
const JUMP_SPEED := 305.0
const RUN_JUMP_SPEED := 330.0
const JUMP_RELEASE_SPEED := 180.0
var service: Node
var sound: Node
var board: Node2D
var screen: TextureRect
var viewport: SubViewport
var pilot := 0
var phase := "waiting"
var resume_phase := "playing"
var mario: Dictionary
var tiles: Dictionary
var blocks: Dictionary
var enemies: Array[Dictionary] = []
var items: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var shots: Array[Dictionary] = []
var room_coins: Array[Vector2] = []
var underground := false
var camera_x := 0.0
var checkpoint := 0.0
var power := 0
var score := 0
var coins := 0
var lives := 3
var time_left := 400.0
var elapsed := 0.0
var phase_time := 0.0
var invincible := 0.0
var star := 0.0
var freeze := 0.0
var facing := 1.0
var crouching := false
var flag_y := 48.0
var warp_target := ""
var last_jump := false
var last_run := false
var last_pause := false
var help := false

func _ready() -> void:
	DisplayServer.window_set_title("Super Mario Bros. · World 1-1 recreation")
	service = get_node("/root/Platform").input
	service.keyboard_enabled = true
	# B is run/fire in this game, so the general B-to-leave timer is suspended.
	service.set_physics_process(false)
	service.player_joined.connect(_joined)
	service.player_left.connect(_left)
	sound = Sound.new()
	add_child(sound)
	var backdrop := ColorRect.new()
	backdrop.color = Color.BLACK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	viewport = SubViewport.new()
	viewport.size = Vector2i(256,240)
	viewport.disable_3d = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	board = Board.new()
	board.game = self
	viewport.add_child(board)
	screen = TextureRect.new()
	screen.texture = viewport.get_texture()
	screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	screen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(screen)
	resized.connect(_fit)
	_fit()
	reset_run()
	phase = "waiting"
	for id in service.players.keys(): _joined(id)

func _fit() -> void:
	if not is_instance_valid(screen): return
	var height := minf(size.y,size.x*0.75)
	screen.size = Vector2(height*4/3,height)
	screen.position = (size-screen.size)/2

func body(at: Vector2, dimensions: Vector2) -> Dictionary:
	return {"p":at,"v":Vector2.ZERO,"size":dimensions,"ground":false,"side":false}

func reset_run() -> void:
	score = 0
	coins = 0
	lives = 3
	checkpoint = 0
	reset_level()

func reset_level() -> void:
	underground = false
	tiles = Level.solids()
	blocks = Level.blocks()
	mario = body(Vector2(40 if checkpoint==0 else checkpoint,208),Vector2(12,16))
	mario.ground = true
	power = 0
	star = 0
	invincible = 0
	freeze = 0
	facing = 1
	crouching = false
	time_left = 400
	camera_x = maxf(0,mario.p.x-128)
	flag_y = 48
	items.clear()
	effects.clear()
	shots.clear()
	room_coins.clear()
	enemies.clear()
	for at in Level.GOOMBAS:
		var enemy := body(Vector2(at[0]+8,at[1]),Vector2(14,16))
		enemy.merge({"kind":"goomba","active":false,"mode":"walk","timer":0.0,"ignore":0.0})
		enemy.v.x = -30
		enemies.append(enemy)
	var koopa := body(Vector2(1720,208),Vector2(14,24))
	koopa.merge({"kind":"koopa","active":false,"mode":"walk","timer":0.0,"ignore":0.0})
	koopa.v.x = -30
	enemies.append(koopa)
	phase = "playing"
	phase_time = 0
	last_jump = true
	last_run = false

func _joined(id: int) -> void:
	if pilot:
		service.leave(id)
		return
	pilot = id
	if phase == "waiting": phase = "playing"
	elif phase == "disconnected": phase = resume_phase
	last_jump = true
	last_run = false

func _left(id: int) -> void:
	if id != pilot: return
	pilot = 0
	resume_phase = phase
	phase = "disconnected"
	mario.v.x = 0

func _physics_process(delta: float) -> void:
	elapsed += delta
	board.queue_redraw()
	if not pilot or not service.players.has(pilot): return
	var state: Dictionary = service.players[pilot]
	var buttons: Dictionary = state.buttons
	var keys: Dictionary = state.keys
	var wii: bool = state.profile.id == "wii_remote"
	var jump: bool = buttons.get(JOY_BUTTON_Y if wii else JOY_BUTTON_A,false) or keys.get(KEY_SPACE,false) or keys.get(KEY_Z,false)
	var run: bool = buttons.get(JOY_BUTTON_X if wii else JOY_BUTTON_B,false) or buttons.get(JOY_BUTTON_X,false) or keys.get(KEY_SHIFT,false) or keys.get(KEY_X,false)
	var pause: bool = buttons.get(JOY_BUTTON_GUIDE,false) or buttons.get(JOY_BUTTON_START,false) or keys.get(KEY_P,false)
	if pause and not last_pause:
		if phase == "playing": phase = "paused"
		elif phase == "paused": phase = "playing"
	last_pause = pause
	if wii and buttons.get(JOY_BUTTON_BACK,false):
		service.leave(pilot)
		return
	var direction: Vector2 = service.movement(pilot)
	advance(delta,direction.x,jump,run,direction.y>0.5)

func advance(delta: float, axis: float, jump: bool, run: bool, down: bool) -> void:
	phase_time += delta
	if phase in ["paused","waiting","disconnected"]:
		last_jump = jump
		last_run = run
		return
	if phase in ["complete","game_over"]:
		if jump and not last_jump: reset_run()
		last_jump = jump
		return
	if phase == "dead":
		if phase_time>0.35:
			mario.v.y += 850*delta
			mario.p += mario.v*delta
		if phase_time>2.2:
			if lives>0: reset_level()
			else: phase = "game_over"
		return
	if phase == "warp":
		mario.p.y += (24 if warp_target=="underground" else -24)*delta
		if phase_time>0.7:
			if warp_target=="underground": enter_room()
			else: exit_room()
		return
	if phase in ["flag","castle"]:
		_finish(delta)
		return
	if freeze>0:
		freeze -= delta
		return
	invincible = maxf(0,invincible-delta)
	star = maxf(0,star-delta)
	time_left -= delta*2.5
	if time_left<=0:
		die()
		return
	crouching = down and power>0 and mario.ground
	var target_height := 16.0 if power==0 or crouching else 32.0
	if target_height>mario.size.y:
		var standing := Rect2(mario.p-Vector2(6,target_height),Vector2(12,target_height))
		if not colliders(standing,false).is_empty(): target_height = mario.size.y
	mario.size.y = target_height
	var target_speed := axis*(150 if run else 90)
	if crouching: target_speed = 0
	mario.v.x = move_toward(mario.v.x,target_speed,delta*(550 if axis else 700))
	if absf(axis)>0.1 and not crouching: facing = signf(axis)
	if jump and not last_jump and mario.ground:
		mario.v.y = -RUN_JUMP_SPEED if absf(mario.v.x)>95 else -JUMP_SPEED
		mario.ground = false
		sound.effect("jump")
	if not jump and mario.v.y < -JUMP_RELEASE_SPEED: mario.v.y = -JUMP_RELEASE_SPEED
	if run and not last_run and power==2 and shots.size()<2:
		var shot := body(mario.p+Vector2(facing*9,-12),Vector2(6,6))
		shot.v = Vector2(facing*210,90)
		shot["life"] = 3.0
		shots.append(shot)
		sound.effect("fire")
	last_jump = jump
	last_run = run
	var before: Vector2 = mario.p
	mario.v.y = minf(mario.v.y+delta*(550 if jump and mario.v.y<0 else 1100),250)
	move_body(mario,delta,true)
	mario.p.x = maxf(camera_x+6,mario.p.x)
	if mario.p.y>265:
		die()
		return
	if not underground:
		camera_x = clampf(maxf(camera_x,mario.p.x-112),0,3072)
		if mario.p.x>1280: checkpoint = 1280
		if down and mario.ground and mario.p.x>=919 and mario.p.x<=937 and absf(mario.p.y-144)<1:
			phase = "warp"
			warp_target = "underground"
			phase_time = 0
			mario.v = Vector2.ZERO
		if mario.p.x>=3170 and mario.p.y<208:
			phase = "flag"
			phase_time = 0
			mario.p.x = 3171
			mario.v = Vector2.ZERO
			score += 5000 if mario.p.y<65 else (2000 if mario.p.y<105 else (800 if mario.p.y<145 else 100))
			sound.effect("win")
	else:
		for coin in room_coins.duplicate():
			if rect(mario).intersects(Rect2(coin,Vector2(10,14))):
				room_coins.erase(coin)
				award_coin(coin)
		if mario.p.x>=201 and mario.p.y>=207:
			phase = "warp"
			warp_target = "outside"
			phase_time = 0
	_tick_enemies(delta,before)
	_tick_items(delta)
	_tick_shots(delta)
	for tile in blocks:
		blocks[tile].bump = maxf(0,blocks[tile].bump-delta)
	for effect in effects.duplicate():
		effect.life -= delta
		effect.p += effect.v*delta
		if effect.kind=="debris": effect.v.y += 500*delta
		if effect.life<=0: effects.erase(effect)

func rect(entity: Dictionary) -> Rect2:
	return Rect2(entity.p-Vector2(entity.size.x/2,entity.size.y),entity.size)

func colliders(area: Rect2, hidden: bool) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for x in range(floori(area.position.x/16),floori(area.end.x/16)+1):
		for y in range(floori(area.position.y/16),floori(area.end.y/16)+1):
			var tile := Vector2i(x,y)
			if tiles.has(tile) or (not underground and blocks.has(tile) and (blocks[tile].kind!="hidden" or hidden)):
				if area.intersects(Rect2(Vector2(tile)*16,Vector2(16,16))): result.append(tile)
	return result

func move_body(entity: Dictionary, delta: float, player := false) -> void:
	entity.side = false
	entity.ground = false
	var steps := maxi(1,ceili(delta*120))
	var dt := delta/steps
	for i in steps:
		entity.p.x += entity.v.x*dt
		for tile in colliders(rect(entity),false):
			if entity.v.x>0: entity.p.x = tile.x*16-entity.size.x/2
			elif entity.v.x<0: entity.p.x = tile.x*16+16+entity.size.x/2
			entity.side = true
			if player: entity.v.x = 0
		var old_top: float = entity.p.y-entity.size.y
		var vertical_speed: float = entity.v.y
		entity.p.y += vertical_speed*dt
		for tile in colliders(rect(entity),player and entity.v.y<0):
			if vertical_speed>=0:
				entity.p.y = tile.y*16
				entity.ground = true
				entity.v.y = 0
				break
			elif old_top >= tile.y*16+15.9:
				entity.p.y = tile.y*16+16+entity.size.y
				entity.v.y = 0
				if player and blocks.has(tile): hit_block(tile)
				break
	entity.ground = entity.v.y>=0 and not colliders(Rect2(entity.p-Vector2(entity.size.x/2-0.1,0),Vector2(entity.size.x-0.2,0.2)),false).is_empty()

func hit_block(tile: Vector2i) -> void:
	if not blocks.has(tile): return
	var block: Dictionary = blocks[tile]
	if block.kind=="used" or block.bump>0: return
	block.bump = 0.2
	var at := Vector2(tile)*16
	if block.left>0:
		block.left -= 1
		if block.content=="coin": award_coin(at,true)
		else:
			var kind: String = block.content
			if kind=="power": kind = "mushroom" if power==0 else "flower"
			var item := body(at+Vector2(8,16),Vector2(14,16))
			item.merge({"kind":kind,"emerge":0.65,"base":at.y+16})
			item.v.x = 60 if kind in ["mushroom","life","star"] else 0
			items.append(item)
			sound.effect("power")
		if block.left==0: block.kind = "used"
	elif block.kind=="brick" and power>0:
		blocks.erase(tile)
		score += 50
		for offset in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
			effects.append({"kind":"debris","p":at+Vector2(8,8),"v":Vector2(offset.x*65,-150+offset.y*35),"life":0.65})
		sound.effect("bump")
	else: sound.effect("bump")
	for enemy in enemies:
		if enemy.mode in ["walk","shell"] and absf(enemy.p.y-at.y)<3 and absf(enemy.p.x-at.x-8)<18:
			defeat(enemy)

func award_coin(at: Vector2, popped := false) -> void:
	coins += 1
	score += 200
	if coins>=100:
		coins -= 100
		lives += 1
		sound.effect("life")
	else: sound.effect("coin")
	effects.append({"kind":"coin" if popped else "points","text":"200","p":at,"v":Vector2(0,-45),"life":0.6})

func _tick_items(delta: float) -> void:
	for item in items.duplicate():
		if item.emerge>0:
			item.emerge = maxf(0,item.emerge-delta)
			item.p.y = item.base-16*(1-item.emerge/0.65)
			continue
		item.v.y = minf(item.v.y+700*delta,220)
		move_body(item,delta)
		if item.side: item.v.x *= -1
		if item.kind=="star" and item.ground: item.v.y = -180
		if rect(mario).intersects(rect(item)):
			collect(item.kind)
			items.erase(item)
		elif item.p.y>260 or item.p.x<camera_x-24: items.erase(item)

func collect(kind: String) -> void:
	if kind=="life":
		lives += 1
		sound.effect("life")
		return
	if kind=="star": star = 10
	elif kind=="flower": power = 2
	elif kind=="mushroom" and power==0: power = 1
	score += 1000
	freeze = 0.35
	sound.effect("power")

func _tick_enemies(delta: float, before: Vector2) -> void:
	if underground: return
	for enemy in enemies.duplicate():
		if not enemy.active and enemy.p.x<camera_x+272: enemy.active = true
		if not enemy.active: continue
		enemy.ignore = maxf(0,enemy.ignore-delta)
		if enemy.mode in ["flat","dead"]:
			enemy.timer -= delta
			if enemy.mode=="dead":
				enemy.v.y += 700*delta
				enemy.p += enemy.v*delta
			if enemy.timer<=0: enemies.erase(enemy)
			continue
		if enemy.mode=="shell" and is_zero_approx(enemy.v.x):
			enemy.timer += delta
			if enemy.timer>10:
				enemy.mode = "walk"
				enemy.size.y = 24
				enemy.v.x = -30
		enemy.v.y = minf(enemy.v.y+900*delta,230)
		move_body(enemy,delta)
		if enemy.side: enemy.v.x *= -1
		if enemy.p.y>260 or enemy.p.x<camera_x-32:
			enemies.erase(enemy)
			continue
		if not rect(mario).intersects(rect(enemy)) or enemy.ignore>0: continue
		if star>0:
			defeat(enemy)
		elif mario.v.y>0 and before.y<=rect(enemy).position.y+6:
			mario.p.y = rect(enemy).position.y
			mario.v.y = -180 if last_jump else -130
			score += 100
			sound.effect("stomp")
			if enemy.kind=="goomba":
				enemy.mode = "flat"
				enemy.timer = 0.35
			else:
				enemy.mode = "shell"
				enemy.v.x = 0
				enemy.size.y = 14
				enemy.timer = 0
				enemy.ignore = 0.2
		elif enemy.mode=="shell" and is_zero_approx(enemy.v.x):
			enemy.v.x = 240 if mario.p.x<enemy.p.x else -240
			enemy.ignore = 0.25
		else: hurt()
	for i in enemies.size():
		var a := enemies[i]
		if not a.active or a.mode not in ["walk","shell"]: continue
		for j in range(i+1,enemies.size()):
			var b := enemies[j]
			if not b.active or b.mode not in ["walk","shell"] or not rect(a).intersects(rect(b)): continue
			if a.mode=="shell" and absf(a.v.x)>100: defeat(b)
			elif b.mode=="shell" and absf(b.v.x)>100: defeat(a)
			else:
				a.v.x = -absf(a.v.x) if a.p.x<b.p.x else absf(a.v.x)
				b.v.x = absf(b.v.x) if a.p.x<b.p.x else -absf(b.v.x)

func defeat(enemy: Dictionary) -> void:
	if enemy.mode=="dead": return
	enemy.mode = "dead"
	enemy.timer = 0.8
	enemy.v = Vector2(facing*45,-150)
	score += 100 if enemy.kind=="goomba" else 200
	sound.effect("stomp")

func _tick_shots(delta: float) -> void:
	for shot in shots.duplicate():
		shot.life -= delta
		shot.v.y += 800*delta
		move_body(shot,delta)
		if shot.ground: shot.v.y = -135
		if shot.side or shot.life<=0 or shot.p.y>250:
			shots.erase(shot)
			continue
		for enemy in enemies:
			if enemy.mode in ["walk","shell"] and rect(shot).intersects(rect(enemy)):
				defeat(enemy)
				shots.erase(shot)
				break

func hurt() -> void:
	if invincible>0 or star>0 or phase!="playing": return
	if power>0:
		power = 0
		mario.size.y = 16
		invincible = 2
		freeze = 0.35
		sound.effect("power")
	else: die()

func die() -> void:
	if phase=="dead": return
	phase = "dead"
	phase_time = 0
	lives -= 1
	mario.v = Vector2(0,-230)
	sound.effect("death")

func enter_room() -> void:
	underground = true
	tiles = Level.solids(true)
	mario.p = Vector2(40,48)
	mario.v = Vector2.ZERO
	camera_x = 0
	items.clear()
	shots.clear()
	room_coins.clear()
	for x in range(5,10): room_coins.append(Vector2(x*16+3,80))
	for y in [112,144]:
		for x in range(4,11): room_coins.append(Vector2(x*16+3,y))
	phase = "playing"

func exit_room() -> void:
	underground = false
	tiles = Level.solids()
	mario.p = Vector2(2624,176)
	mario.v = Vector2.ZERO
	mario.ground = true
	camera_x = 2496
	phase = "playing"
	items.clear()
	shots.clear()

func _finish(delta: float) -> void:
	if phase=="flag":
		mario.p.y = move_toward(mario.p.y,192,80*delta)
		flag_y = move_toward(flag_y,176,100*delta)
		if mario.p.y>=192 and flag_y>=176:
			phase = "castle"
			phase_time = 0
			mario.p.x = 3186
			facing = 1
	else:
		if mario.p.x<3280:
			mario.v = Vector2(65,120)
			move_body(mario,delta,true)
		else:
			var count := minf(time_left,delta*150)
			time_left -= count
			score += roundi(count*50)
			if time_left<=0: phase = "complete"

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode==KEY_ESCAPE: get_tree().quit()
	elif event.keycode==KEY_R: reset_run()
	elif event.keycode==KEY_F1: help = not help
	elif event.keycode==KEY_F11:
		var full := DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
