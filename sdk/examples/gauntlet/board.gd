extends Node2D
const Level = preload("res://examples/gauntlet/level.gd")
const FONT = preload("res://examples/world_1_1/assets/PressStart2P-Regular.ttf")
const ORIGIN := Vector2(160,104)
const GOLD := Color("eacb85")
const CREAM := Color("f2e6c9")
const DIM := Color("9a999f")
var game: Node2D
func text(value: String, at: Vector2, size := 14, color := CREAM) -> void:
	draw_string(FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
func centered(value: String, y: float, size := 14, color := CREAM) -> void:
	text(value,Vector2(800-FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x/2,y),size,color)
func box(rect: Rect2, fill: Color, border := Color("514953")) -> void:
	draw_rect(rect,fill)
	draw_rect(rect,border,false,2)
func pixels(at: Vector2, rect: Rect2, color: Color) -> void:
	draw_rect(Rect2(at+rect.position,rect.size),color)

func _draw() -> void:
	draw_rect(Rect2(0,0,1600,900),Color("12131c"))
	for x in range(0,1600,64): draw_line(Vector2(x,0),Vector2(x,900),Color("191923"))
	text("COUCH GAMES / ARCADE",Vector2(40,29),10,DIM)
	text("GAUNTLET",Vector2(38,72),34,GOLD)
	text("01",Vector2(472,55),26,Color("b6a0ca"))
	text("THE EMBER VAULT",Vector2(558,45),16)
	text("%02d HEROES  /  %d OF 4 GENERATORS" % [game.heroes.size(),game.destroyed()],Vector2(558,71),10,DIM)
	text("GOLD %06d" % game.score,Vector2(1080,42),12,GOLD)
	text("KEYS %02d   %02d:%02d" % [game.keys,int(game.elapsed)/60,int(game.elapsed)%60],Vector2(1080,68),11,DIM)
	draw_rect(Rect2(152,96,1296,656),Color("070a10"))
	draw_rect(Rect2(156,100,1288,648),Color("6e5b53"),false,2)
	draw_set_transform(ORIGIN)
	dungeon()
	draw_set_transform(Vector2.ZERO)
	# Side inscriptions frame the shared board without claiming more screen space.
	text("I",Vector2(74,181),22,GOLD)
	text("IV",Vector2(1490,671),22,GOLD)
	for i in 16:
		var id := i+1
		var at := Vector2(40+(i%8)*190,766+(i/8)*54)
		var occupied: bool = game.heroes.has(id)
		box(Rect2(at,Vector2(180,47)),Color("242330") if occupied else Color("191b25"))
		if occupied:
			var hero: Dictionary = game.heroes[id]
			var stats: Dictionary = Level.CLASSES[hero.hero_class]
			var color := Color(stats.color)
			text("%02d" % id,at+Vector2(8,18),12,color)
			text(stats.name,at+Vector2(39,16),9,color)
			text("DOWN" if hero.hp<=0 else "%03d  M:%d" % [ceili(hero.hp),hero.potions],at+Vector2(39,30),9,CREAM)
			draw_rect(Rect2(at+Vector2(8,37),Vector2(163,3)),Color("11141c"))
			draw_rect(Rect2(at+Vector2(8,37),Vector2(163*hero.hp/stats.health,3)),color)
		else:
			text("%02d  PRESS TO JOIN" % id,at+Vector2(9,27),9,Color("636775"))
	centered("MOVE: STICK / D-PAD    FIRE: A / CROSS / WII 2    MAGIC: X / SQUARE / WII 1    F1: HELP",889,10,DIM)
	if game.message_time>0 and game.phase=="playing":
		box(Rect2(258,713,1084,30),Color("151620"),Color("5b5061"))
		centered(game.message,733,11,GOLD)
	if game.phase in ["lobby","complete","defeat","paused"] or game.help:
		draw_rect(Rect2(160,104,1280,640),Color(0.02,0.025,0.06,0.68))
		panel()

func dungeon() -> void:
	for y in Level.HEIGHT:
		for x in Level.WIDTH:
			var cell := Vector2i(x,y)
			var at := Vector2(x,y)*32
			var shade := (x*17+y*11)%5
			var color := Color("282833").lightened(shade*0.011)
			draw_rect(Rect2(at,Vector2(32,32)),color)
			draw_line(at+Vector2(1,31),at+Vector2(31,31),Color("22232d"))
			if (x*13+y*7)%17==0:
				draw_line(at+Vector2(4,10),at+Vector2(12,12),Color("383642"))
			if game.walls.has(cell):
				draw_rect(Rect2(at+Vector2(0,5),Vector2(32,31)),Color("141822"))
				draw_rect(Rect2(at,Vector2(32,29)),Color("4c4752"))
				draw_rect(Rect2(at+Vector2(2,2),Vector2(28,11)),Color("66606b").darkened(shade*0.025))
				draw_rect(Rect2(at+Vector2(2,16),Vector2(12,10)),Color("57515d"))
				draw_rect(Rect2(at+Vector2(17,16),Vector2(13,10)),Color("5d5661"))
				draw_line(at,at+Vector2(31,0),Color("82737a"))
			elif game.doors.has(cell):
				draw_rect(Rect2(at,Vector2(32,32)),Color("674d34"))
				for bar in 4: draw_rect(Rect2(at+Vector2(bar*8+1,2),Vector2(5,28)),Color("a18450"))
				draw_rect(Rect2(at+Vector2(1,5),Vector2(30,3)),GOLD)
				draw_rect(Rect2(at+Vector2(1,24),Vector2(30,3)),GOLD)
				draw_circle(at+Vector2(16,16),4,Color("201e2b"))
	# Warm pools of torchlight.
	for cell in [Vector2i(1,7),Vector2i(11,11),Vector2i(13,2),Vector2i(25,16),Vector2i(27,10),Vector2i(38,4)]:
		var at := Level.center(cell)
		for ring in range(4,0,-1): draw_circle(at,ring*15,Color(1,0.56,0.19,0.013))
		draw_rect(Rect2(at+Vector2(-3,-1),Vector2(6,13)),Color("6d4732"))
		draw_circle(at+Vector2(0,-5),6+sin(game.clock*7+cell.x),Color("d58440"))
		draw_circle(at+Vector2(0,-7),3,Color("ffe7a0"))
	var open: bool = game.destroyed()==4
	var exit := Level.EXIT
	draw_rect(Rect2(exit-Vector2(47,33),Vector2(94,67)),Color("334444") if open else Color("302c3e"))
	for i in 4: draw_rect(Rect2(exit-Vector2(40-i*4,21-i*6),Vector2(80-i*8,5)),Color("73ad9b") if open else Color("5e526d"))
	text("EXIT",exit+Vector2(-24,27),12,Color("c8f0ba") if open else DIM)
	if open:
		draw_arc(exit,57,0,TAU,48,Color("a5daac"),2)
		if game.exit_time>0: draw_arc(exit,60,-PI/2,-PI/2+TAU*game.exit_time/1.5,48,GOLD,4)
	for pickup: Dictionary in game.pickups: item(pickup)
	for generator: Dictionary in game.generators:
		var at: Vector2 = generator.pos
		draw_circle(at+Vector2(0,7),23,Color("171720"))
		if generator.hp<=0:
			for i in 5: draw_rect(Rect2(at+Vector2(i*7-17,(i%2)*5),Vector2(6,7)),Color("554958"))
			continue
		draw_rect(Rect2(at-Vector2(19,17),Vector2(38,35)),Color("5f465e"))
		draw_rect(Rect2(at-Vector2(15,23),Vector2(30,35)),Color("957485"))
		draw_rect(Rect2(at-Vector2(11,18),Vector2(22,23)),Color("231e32"))
		var glow := Color("d68ae0") if generator.kind=="ghost" else Color("ee956c")
		draw_circle(at-Vector2(0,6),7+sin(game.clock*3)*2,glow.darkened(0.3))
		draw_rect(Rect2(at-Vector2(6,10),Vector2(4,4)),CREAM)
		draw_rect(Rect2(at-Vector2(-3,10),Vector2(4,4)),CREAM)
		draw_rect(Rect2(at+Vector2(-18,22),Vector2(36,3)),Color("14151e"))
		draw_rect(Rect2(at+Vector2(-18,22),Vector2(36*generator.hp/generator.max_hp,3)),glow)
	for enemy: Dictionary in game.enemies: monster(enemy)
	for id: int in game.heroes:
		var hero: Dictionary = game.heroes[id]
		var at: Vector2 = hero.pos
		var color := Color(Level.CLASSES[hero.hero_class].color)
		if hero.hp<=0:
			draw_circle(at,15,Color("272535"))
			draw_line(at-Vector2(8,8),at+Vector2(8,8),color,4)
			draw_line(at+Vector2(-8,8),at+Vector2(8,-8),color,4)
			if hero.revive>0: draw_arc(at,20,-PI/2,-PI/2+TAU*hero.revive/2.5,40,GOLD,3)
		else:
			draw_arc(at+Vector2(0,6),14,0,TAU,24,color.darkened(0.25),2)
			if hero.hurt<=0 or int(game.clock*14)%2==0: character(at,hero.hero_class,hero.face,hero.walk)
		draw_rect(Rect2(at+Vector2(15,-27),Vector2(24,13)),Color("1c1d29"))
		text("%02d" % id,at+Vector2(17,-17),10,color)
	for shot: Dictionary in game.shots:
		var color := Color("ff9b63") if shot.owner==0 else Color(Level.CLASSES[shot.hero_class].color)
		var trail: Vector2 = shot.velocity.normalized()*10
		draw_line(shot.pos-trail,shot.pos,color,4)
		draw_circle(shot.pos,3,CREAM)
	for spark: Dictionary in game.sparks:
		var magic: bool = spark.kind=="magic"
		var radius: float = (1-spark.life/0.65)*200 if magic else (1-spark.life/0.35)*24
		var color: Color = spark.color
		color.a = clampf(spark.life*2,0,1)
		draw_arc(spark.pos,maxf(1,radius),0,TAU,48,color,4 if magic else 2)

func character(at: Vector2, kind: int, face: Vector2, walk := 0.0) -> void:
	var color := Color(Level.CLASSES[kind].color)
	var stride := roundf(sin(walk)*3)
	draw_circle(at+Vector2(1,9),12,Color(0.02,0.03,0.06,0.45))
	pixels(at,Rect2(-7,6+stride,5,8),Color("927661"))
	pixels(at,Rect2(2,6-stride,5,8),Color("927661"))
	pixels(at,Rect2(-8,-8,16,17),color.darkened(0.22))
	pixels(at,Rect2(-7,-7,10,13),color)
	pixels(at,Rect2(-6,-19,12,11),Color("ecc19a"))
	pixels(at,Rect2(-4,-14,2,2),Color("252435"))
	pixels(at,Rect2(3,-14,2,2),Color("252435"))
	pixels(at,Rect2(-8,3,16,3),Color("553d3b"))
	pixels(at,Rect2(-1,3,3,3),GOLD)
	match kind:
		0:
			pixels(at,Rect2(-7,-21,14,6),Color("bbb4b1"))
			pixels(at,Rect2(-11,-24,4,9),CREAM)
			pixels(at,Rect2(7,-24,4,9),CREAM)
		1:
			pixels(at,Rect2(-7,-22,14,6),GOLD)
			pixels(at,Rect2(-10,-23,3,7),CREAM)
			pixels(at,Rect2(7,-23,3,7),CREAM)
			pixels(at,Rect2(-15,-5,8,13),Color("cbd4d9"))
			pixels(at,Rect2(-13,-3,4,9),color)
		2:
			draw_colored_polygon(PackedVector2Array([at+Vector2(-10,-18),at+Vector2(0,-35),at+Vector2(9,-18)]),color)
			pixels(at,Rect2(-5,-10,10,7),CREAM)
		3:
			draw_colored_polygon(PackedVector2Array([at+Vector2(-9,-18),at+Vector2(13,-28),at+Vector2(7,-17)]),color)
			pixels(at,Rect2(-9,-14,3,3),Color("ecc19a"))
			pixels(at,Rect2(7,-14,3,3),Color("ecc19a"))
	var hand := at+face*13
	if kind==3:
		draw_arc(hand,9,face.angle()-PI/2,face.angle()+PI/2,12,GOLD,2)
	elif kind==2:
		draw_line(hand+Vector2(0,8),hand-Vector2(0,12),Color("8d735e"),3)
		draw_circle(hand-Vector2(0,13),4,Color("dcb7ff"))
	else:
		draw_line(hand,hand+face*14,Color("e3ded2"),4)
		if kind==0: draw_circle(hand+face*12,6,Color("b9b3bb"))

func monster(enemy: Dictionary) -> void:
	var at: Vector2 = enemy.pos
	draw_circle(at+Vector2(0,9),10,Color("15151f"))
	if enemy.kind=="ghost":
		at.y += sin(game.clock*5+enemy.id)*2
		draw_circle(at-Vector2(0,5),9,Color("c0b6c8"))
		draw_rect(Rect2(at+Vector2(-9,-5),Vector2(18,14)),Color("c0b6c8"))
		for i in 3: draw_rect(Rect2(at+Vector2(-9+i*7,8),Vector2(4,4)),Color("c0b6c8"))
	else:
		var color := Color("9b9b7a") if enemy.kind=="grunt" else Color("c26960")
		draw_rect(Rect2(at-Vector2(9,10),Vector2(18,22)),color)
		draw_rect(Rect2(at-Vector2(6,16),Vector2(12,9)),color.lightened(0.15))
		if enemy.kind=="demon":
			draw_line(at+Vector2(-7,-13),at+Vector2(-11,-20),GOLD,3)
			draw_line(at+Vector2(7,-13),at+Vector2(11,-20),GOLD,3)
		else: draw_line(at+Vector2(12,6),at+Vector2(16,-10),Color("b8a28a"),5)
	draw_rect(Rect2(at+Vector2(-5,-8),Vector2(3,4)),Color("352436"))
	draw_rect(Rect2(at+Vector2(3,-8),Vector2(3,4)),Color("352436"))

func item(pickup: Dictionary) -> void:
	var at: Vector2 = pickup.pos
	draw_circle(at+Vector2(0,6),10,Color("1c1e27"))
	match pickup.kind:
		"key":
			draw_arc(at+Vector2(-5,-4),5,0,TAU,12,GOLD,3)
			draw_line(at+Vector2(-1,-1),at+Vector2(9,9),GOLD,3)
			draw_line(at+Vector2(8,8),at+Vector2(12,4),GOLD,3)
		"food":
			draw_circle(at,11,Color("b7ad9b"))
			draw_circle(at,8,Color("885740"))
			draw_circle(at+Vector2(-2,-3),6,Color("d2a271"))
			draw_line(at+Vector2(4,4),at+Vector2(10,8),CREAM,3)
		"potion":
			draw_rect(Rect2(at+Vector2(-3,-11),Vector2(6,5)),GOLD)
			draw_circle(at,8,Color("a5c7d3"))
			draw_circle(at+Vector2(0,2),6,Color("a68bd3"))
			draw_rect(Rect2(at+Vector2(-4,-3),Vector2(2,4)),CREAM)
		"gold":
			draw_rect(Rect2(at+Vector2(-10,-6),Vector2(20,14)),Color("8e6439"))
			draw_rect(Rect2(at+Vector2(-10,-8),Vector2(20,5)),GOLD)
			draw_rect(Rect2(at+Vector2(-2,-2),Vector2(4,5)),GOLD)

func panel() -> void:
	box(Rect2(310,182,980,454),Color("1b1d2b"),Color("ad8d64"))
	if game.help:
		centered("HOW TO SURVIVE",236,25,GOLD)
		for i in 7:
			var lines := ["STICK / D-PAD: MOVE AND AIM. HOLD FIRE TO ATTACK.","A / CROSS / WII 2 / SPACE: FIRE", "X / SQUARE / WII 1 / KEYBOARD X: MAGIC", "START / OPTIONS / WII HOME / P: PAUSE", "SHARED KEYS OPEN DOORS. FOOD HEALS THE WHOLE PARTY.","STAND BY A FALLEN HERO FOR 2.5 SECONDS TO REVIVE.","DESTROY 4 GENERATORS, THEN GATHER AT THE EXIT."]
			centered(lines[i],292+i*37,12,CREAM)
		centered("F1 CLOSE HELP   /   F11 FULLSCREEN   /   ESC LIBRARY",597,12,GOLD)
	elif game.phase=="lobby":
		centered("THE EMBER VAULT",238,27,GOLD)
		centered("A GAUNTLET-INSPIRED DUNGEON FOR 1-16 HEROES",272,12,DIM)
		for i in 4:
			var at := Vector2(462+i*225,360)
			draw_set_transform(at,0,Vector2(1.8,1.8))
			character(Vector2.ZERO,i,Vector2.RIGHT)
			draw_set_transform(Vector2.ZERO)
			text(Level.CLASSES[i].name,at+Vector2(-58,45),12,Color(Level.CLASSES[i].color))
			text(["HEAVY AXE","STRONG ARMOR","MIGHTY MAGIC","FAST ARROWS"][i],at+Vector2(-60,70),10,DIM)
		centered("PRESS A / CROSS / WII 2 TO JOIN  ·  ENTER FOR KEYBOARD",469,12)
		centered("X / SQUARE / WII 1: CHANGE CLASS  ·  KEYBOARD: TAB",501,11,DIM)
		centered("SHARED SCREEN. SHARED KEYS. NO FRIENDLY FIRE.",541,11,GOLD)
		centered("START / OPTIONS / WII HOME / ENTER TO BEGIN",593,13)
	elif game.phase=="paused":
		centered("TAKE A BREATHER",306,30,GOLD)
		centered("THE DUNGEON IS PAUSED",374,14,DIM)
		centered("START / OPTIONS / WII HOME / P TO CONTINUE",469,13)
		centered("F1: CONTROLS     ESC: RETURN TO LIBRARY",536,12,DIM)
	else:
		var won: bool = game.phase=="complete"
		centered("LEVEL ONE CLEARED" if won else "THE PARTY HAS FALLEN",289,28,GOLD)
		centered("THE EMBER VAULT IS SILENT. YOUR HEROES WALK FREE." if won else "THE VAULT KEEPS ITS SECRETS. TRY TOGETHER AGAIN.",349,12,DIM)
		centered("GOLD %06d    MONSTERS %03d" % [game.score,game.kills],414,16)
		centered("TIME %02d:%02d    GENERATORS %d/4" % [int(game.elapsed)/60,int(game.elapsed)%60,game.destroyed()],459,14,DIM)
		centered("START / WII HOME / R: PLAY AGAIN",539,13,GOLD)
		centered("ESC: RETURN TO THE LIBRARY",580,12,DIM)
