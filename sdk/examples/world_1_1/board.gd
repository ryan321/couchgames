extends Node2D
const ASSETS := "res://examples/world_1_1/assets/"
var game: Control
var textures: Dictionary = {}
var font: FontFile
var map: Texture2D
var offset := Vector2.ZERO

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	font = load(ASSETS+"PressStart2P-Regular.ttf")
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	map = load(ASSETS+"World1-1.png")
	var sources: Array = JSON.parse_string(FileAccess.get_file_as_string(ASSETS+"sources.json"))
	for source in sources:
		for name in source.get("frames",[]): textures[name] = load(ASSETS+name)

func tex(name: String, at: Vector2, flip := false, dimensions := Vector2.ZERO, color := Color.WHITE) -> void:
	var texture: Texture2D = textures.get(name)
	if not texture: return
	var target := texture.get_size() if dimensions==Vector2.ZERO else dimensions
	draw_set_transform(at.floor()+Vector2(target.x/2,0)-offset,0,Vector2(-1 if flip else 1,1))
	draw_texture_rect(texture,Rect2(Vector2(-target.x/2,0),target),false,color)
	draw_set_transform(-offset)

func atlas(source: Rect2, at: Vector2) -> void:
	draw_texture_rect_region(map,Rect2(at,source.size),source)

func text(value: String, at: Vector2, color := Color.WHITE) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,8,color)

func _draw() -> void:
	if not game or not game.mario: return
	offset = Vector2(floorf(game.camera_x),0)
	draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(0,0,256,240),Color.BLACK if game.underground else Color("5c94fc"))
	draw_set_transform(-offset)
	if not game.underground:
		for page in 5:
			for region in game.Level.DECOR:
				var at: Vector2 = Vector2(fposmod(region.position.x,768)+page*768,region.position.y)
				if at.x+region.size.x>=offset.x and at.x<=offset.x+256: atlas(region,at)
		atlas(Rect2(3232,128,80,80),Vector2(3232,128))
		draw_rect(Rect2(3174,46,2,146),Color("80d010"))
		draw_circle(Vector2(3175,43),3,Color("80d010"))
		tex("FlagFromPole.png",Vector2(3159,game.flag_y))
		if game.phase=="complete": tex("FlagOnCastle.png",Vector2(3267,113))
	for at: Vector2i in game.tiles:
		if at.x*16<offset.x-16 or at.x*16>offset.x+256: continue
		var kind: String = game.tiles[at]
		if kind=="ground": atlas(Rect2(0,208,16,16),Vector2(at)*16)
		elif kind=="step": atlas(Rect2(2144,192,16,16),Vector2(at)*16)
		elif kind=="brick_dark": tex("BrickBlockDark.png",Vector2(at)*16)
		elif kind=="underground": atlas(Rect2(2368,448,16,16),Vector2(at)*16)
	for item in game.items:
		var names := {"mushroom":"MagicMushroom.png","life":"1upMushroom.png",
			"flower":"FireFlower_%d.png"%(int(game.elapsed*8)%4),"star":"Starman_%d.png"%(int(game.elapsed*10)%4)}
		tex(names[item.kind],item.p-Vector2(8,16))
	if not game.underground:
		for at: Vector2i in game.blocks:
			if at.x*16<offset.x-16 or at.x*16>offset.x+256: continue
			var block: Dictionary = game.blocks[at]
			if block.kind=="hidden": continue
			var name := "BrickBlockBrown.png"
			if block.kind=="question": name = "QuestionBlock_%d.png"%(int(game.elapsed*8)%6)
			elif block.kind=="used": name = "EmptyBlock.png"
			var bounce := sin(block.bump/0.2*PI)*4
			tex(name,Vector2(at)*16-Vector2(0,bounce))
	for enemy in game.enemies:
		if game.underground or not enemy.active or enemy.p.x<offset.x-24 or enemy.p.x>offset.x+280: continue
		var name: String
		var dimensions := Vector2.ZERO
		if enemy.mode=="shell": name = "KoopaTroopaShellGreen.png"
		elif enemy.kind=="koopa": name = "KoopaTroopaGreen_%d.png"%(int(game.elapsed*5)%2)
		else:
			name = "LittleGoomba_%d.png"%(int(game.elapsed*6)%2)
			if enemy.mode=="flat": dimensions = Vector2(16,7)
		var height: float = textures[name].get_height() if dimensions==Vector2.ZERO else dimensions.y
		tex(name,enemy.p-Vector2(8,height),enemy.v.x>0,dimensions)
	for coin in game.room_coins:
		tex("CoinForBlackBG_%d.png"%(int(game.elapsed*8)%6),coin)
	_draw_mario()
	# Pipes cover Mario during the entry/exit animation.
	if game.underground:
		atlas(Rect2(2576,272,64,176),Vector2(208,32))
	else:
		for pipe in game.Level.PIPES:
			var at := Vector2(pipe[0]*16,(13-pipe[1])*16)
			atlas(Rect2(448,176,32,16),at)
			for row in range(1,pipe[1]): atlas(Rect2(448,192,32,16),at+Vector2(0,row*16))
	for shot in game.shots:
		tex("FireBall_%d.png"%(int(game.elapsed*12)%4),shot.p-Vector2(4,8))
	for effect in game.effects:
		if effect.kind=="coin": tex("CoinForBlueBG_%d.png"%(int(game.elapsed*15)%6),effect.p)
		elif effect.kind=="debris":
			draw_texture_rect_region(textures["BrickBlockBrown.png"],Rect2(effect.p,Vector2(8,8)),Rect2(0,0,8,8))
		else: text(effect.text,effect.p)
	offset = Vector2.ZERO
	draw_set_transform(Vector2.ZERO)
	text("MARIO",Vector2(16,24))
	text("%06d"%game.score,Vector2(16,32))
	tex("CoinForBlueBG_%d.png"%(int(game.elapsed*8)%6),Vector2(88,24),false,Vector2(5,7))
	text("x%02d"%game.coins,Vector2(96,32))
	text("WORLD",Vector2(144,24))
	text("1-1",Vector2(152,32))
	text("TIME",Vector2(208,24))
	text("%03d"%maxi(0,ceili(game.time_left)),Vector2(216,32))
	if game.phase in ["waiting","disconnected","paused","game_over","complete"] or game.help:
		draw_rect(Rect2(16,72,224,100),Color(0,0,0,0.88))
		var heading := "WORLD 1-1"
		if game.phase=="disconnected": heading = "CONTROLLER LOST"
		elif game.phase=="paused": heading = "PAUSED"
		elif game.phase=="game_over": heading = "GAME OVER"
		elif game.phase=="complete": heading = "COURSE CLEAR!"
		text(heading,Vector2(128-heading.length()*4,92))
		if game.phase in ["complete","game_over"]:
			text("JUMP TO PLAY AGAIN",Vector2(56,116))
		else:
			text("2 / A / ENTER TO JOIN",Vector2(40,110))
			text("WII: D-PAD  2 JUMP  1 RUN",Vector2(32,129))
			text("KEYS: ARROWS  Z/X OR",Vector2(48,143))
			text("SPACE/SHIFT JUMP/RUN",Vector2(48,155))
		text("ESC: LIBRARY  F1: HELP",Vector2(40,190))
		text("LIVES x%d"%game.lives,Vector2(96,205))

func _draw_mario() -> void:
	if game.phase=="castle" and game.mario.p.x>=3280 or game.phase=="complete": return
	if game.invincible>0 and int(game.elapsed*12)%2: return
	var prefix := "Mario" if game.power==0 else ("SuperMario" if game.power==1 else "FieryMario")
	var name := prefix+"Standing.png"
	if game.phase=="dead" or not game.mario.ground: name = prefix+"Jumping.png"
	elif game.crouching and game.power>0: name = prefix+"Crouching.png"
	elif game.mario.v.x*game.facing < -5: name = prefix+"Skidding.png"
	elif absf(game.mario.v.x)>5: name = prefix+"_%d.png"%(int(game.elapsed*maxf(6,absf(game.mario.v.x)/7))%3)
	var texture: Texture2D = textures[name]
	var color := Color.WHITE
	if game.star>0: color = [Color.WHITE,Color("a0ff70"),Color("ffb0b0")][int(game.elapsed*10)%3]
	tex(name,game.mario.p-Vector2(texture.get_width()/2.0,texture.get_height()),game.facing<0,Vector2.ZERO,color)
