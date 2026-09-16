extends RefCounted
## Authored, irregular floor plans. Room shapes and bent corridors are independent of lock order.
const NAMES := ["The Ember Vault", "The Sunken Archive", "The Crown Labyrinth"]
const KEY_COLORS := {"gold":Color("ead39d"),"ruby":Color("f17d80"),"sapphire":Color("7db9ef"),"emerald":Color("80d5ab"),"amber":Color("ffc477"),"amethyst":Color("ce9cf0")}
const KEY_MARKS := {"gold":"G","ruby":"R","sapphire":"S","emerald":"E","amber":"A","amethyst":"V"}

static func create(index: int) -> Dictionary:
	var map := {"name":NAMES[index],"width":56 if index==1 else 76,"height":34 if index==1 else 48,
		"exit":point(50,5) if index==1 else point(70,5),"floor":{},"visible_cells":{},
		"walls":{},"doors":{},"door_colors":{},"door_axes":{},"pickups":[],"generators":[],"enemies":[],
		"enemy_scale":1.12 if index==1 else 1.25,"spawn_rate":0.86 if index==1 else 0.74,
		"enemy_cap":28 if index==1 else 40,"columns":[],"torches":[],"emblems":[],"arches":[],
		"stone":Color("415c65") if index==1 else Color("5b5066")}
	if index==1: archive(map)
	else: labyrinth(map)
	# Solid space outside the carved footprint blocks movement but is not a field of visible walls.
	for y in map.height:
		for x in map.width:
			var at := Vector2i(x,y)
			if not map.floor.has(at): map.walls[at] = true
	for at: Vector2i in map.floor:
		for y in range(-1,2):
			for x in range(-1,2): map.visible_cells[at+Vector2i(x,y)] = true
	for generator: Dictionary in map.generators:
		var cell := Vector2i(generator.pos/32)
		map.emblems.append(cell)
		map.torches.append(cell+Vector2i(2,0))
		item(map,cell+Vector2i(1,1),"gold")
		for offset in [Vector2i(-2,0),Vector2i(0,2)]:
			map.enemies.append({"pos":point(cell.x+offset.x,cell.y+offset.y),"kind":generator.kind})
	return map

static func archive(map: Dictionary) -> void:
	# Broad entry with a west alcove; hooked archive; narrow gallery; offset eastern chambers.
	for rect in [Rect2i(2,23,12,9),Rect2i(2,20,5,4),Rect2i(3,3,14,11),Rect2i(14,9,5,7),
		Rect2i(21,24,10,8),Rect2i(26,20,5,5),Rect2i(23,2,9,15),Rect2i(39,22,14,9),
		Rect2i(42,3,10,12),Rect2i(37,8,6,5)]: room(map,rect)
	for cut in [Rect2i(3,3,3,3),Rect2i(23,2,3,3),Rect2i(29,13,3,4),Rect2i(39,22,4,3)]: solid(map,cut)
	corridor(map,[Vector2i(11,23),Vector2i(11,18),Vector2i(9,18),Vector2i(9,12)])
	corridor(map,[Vector2i(13,28),Vector2i(18,28),Vector2i(18,26),Vector2i(21,26)])
	gate(map,Vector2i(16,28),true,"ruby")
	corridor(map,[Vector2i(16,6),Vector2i(20,6),Vector2i(20,10),Vector2i(23,10)])
	gate(map,Vector2i(20,8),false,"sapphire")
	corridor(map,[Vector2i(31,7),Vector2i(35,7),Vector2i(35,10),Vector2i(37,10)])
	gate(map,Vector2i(34,7),true,"emerald")
	corridor(map,[Vector2i(30,28),Vector2i(35,28),Vector2i(35,25),Vector2i(43,25)])
	# Rewarding dead ends lead away from the next gate. No extra keys are needed to explore them.
	corridor(map,[Vector2i(3,23),Vector2i(3,17)])
	room(map,Rect2i(2,16,4,3))
	corridor(map,[Vector2i(29,3),Vector2i(35,3)])
	room(map,Rect2i(34,2,4,3))
	corridor(map,[Vector2i(23,26),Vector2i(23,20),Vector2i(19,20)])
	for at in [Vector2i(46,25),Vector2i(46,8),Vector2i(10,8)]:
		solid(map,Rect2i(at,Vector2i(2,2)))
		map.columns.append(at)
	key(map,15,4,"ruby")
	key(map,29,22,"sapphire")
	key(map,27,3,"emerald")
	for at in [Vector2i(8,11),Vector2i(4,21),Vector2i(27,28),Vector2i(28,8),Vector2i(47,28),Vector2i(46,11)]:
		nest(map,at,"demon" if map.generators.size()%3==2 else "ghost")
	for at in [Vector2i(3,18),Vector2i(7,25),Vector2i(12,19),Vector2i(7,7),Vector2i(15,12),Vector2i(15,5),Vector2i(22,29),Vector2i(29,24),Vector2i(24,11),Vector2i(30,6),Vector2i(42,28),Vector2i(51,28),Vector2i(40,10),Vector2i(50,12)]: item(map,at,"food")
	for at in [Vector2i(4,17),Vector2i(15,10),Vector2i(19,20),Vector2i(29,30),Vector2i(36,3),Vector2i(50,24),Vector2i(49,5)]: item(map,at,"potion")

static func labyrinth(map: Dictionary) -> void:
	# Twelve staggered spaces: long halls, hooked rooms, compact towers and a ring chamber.
	for rect in [Rect2i(2,36,13,10),Rect2i(3,32,6,5),Rect2i(4,20,10,9),Rect2i(11,17,6,7),
		Rect2i(2,3,17,10),Rect2i(14,11,5,4),Rect2i(24,37,12,9),Rect2i(26,33,5,5),
		Rect2i(25,20,8,9),Rect2i(21,22,5,5),Rect2i(27,2,10,13),Rect2i(35,10,6,5),
		Rect2i(46,35,12,9),Rect2i(43,38,4,5),Rect2i(48,4,8,11),Rect2i(54,10,6,6),
		Rect2i(44,23,14,7),Rect2i(65,19,9,14),Rect2i(65,3,8,9),Rect2i(70,10,4,5),Rect2i(64,40,10,6)]: room(map,rect)
	solid(map,Rect2i(65,19,3,3))
	corridor(map,[Vector2i(11,36),Vector2i(11,31),Vector2i(8,31),Vector2i(8,27)])
	corridor(map,[Vector2i(6,20),Vector2i(6,16),Vector2i(11,16),Vector2i(11,11)])
	corridor(map,[Vector2i(14,41),Vector2i(20,41),Vector2i(20,39),Vector2i(24,39)])
	gate(map,Vector2i(18,41),true,"ruby")
	corridor(map,[Vector2i(16,21),Vector2i(19,21),Vector2i(19,24),Vector2i(22,24)])
	# Span the straight approach, with solid wall at both ends before the bend widens into a room.
	gate(map,Vector2i(18,21),true,"sapphire")
	corridor(map,[Vector2i(18,7),Vector2i(23,7),Vector2i(23,11),Vector2i(27,11)])
	gate(map,Vector2i(23,9),false,"emerald")
	corridor(map,[Vector2i(35,40),Vector2i(40,40),Vector2i(40,38),Vector2i(44,38)])
	gate(map,Vector2i(38,40),true,"amber")
	corridor(map,[Vector2i(40,12),Vector2i(44,12),Vector2i(44,7),Vector2i(48,7)])
	gate(map,Vector2i(44,9),false,"amethyst")
	corridor(map,[Vector2i(52,14),Vector2i(52,19),Vector2i(47,19),Vector2i(47,23)])
	corridor(map,[Vector2i(57,26),Vector2i(61,26),Vector2i(61,23),Vector2i(65,23)])
	corridor(map,[Vector2i(70,19),Vector2i(70,16),Vector2i(67,16),Vector2i(67,11)])
	corridor(map,[Vector2i(57,41),Vector2i(61,41),Vector2i(61,43),Vector2i(64,43)])
	# Branching dead ends, including an offset reliquary and a narrow western spur.
	corridor(map,[Vector2i(5,23),Vector2i(2,23),Vector2i(2,29)])
	room(map,Rect2i(1,28,4,3))
	corridor(map,[Vector2i(29,34),Vector2i(29,31),Vector2i(38,31)])
	room(map,Rect2i(36,29,5,4))
	corridor(map,[Vector2i(35,3),Vector2i(43,3)])
	room(map,Rect2i(42,2,4,3))
	corridor(map,[Vector2i(67,40),Vector2i(67,36)])
	room(map,Rect2i(65,35,6,3))
	for rect in [Rect2i(8,7,3,2),Rect2i(31,6,2,2),Rect2i(49,25,3,2)]:
		solid(map,rect)
		map.columns.append(rect.position)
	key(map,16,4,"ruby")
	key(map,33,43,"sapphire")
	key(map,23,24,"emerald")
	key(map,35,3,"amber")
	key(map,54,41,"amethyst")
	for at in [Vector2i(5,34),Vector2i(9,23),Vector2i(6,6),Vector2i(29,40),Vector2i(28,24),Vector2i(32,11),Vector2i(49,39),Vector2i(52,10),Vector2i(54,26),Vector2i(70,27),Vector2i(69,7),Vector2i(68,42)]:
		nest(map,at,["grunt","ghost","demon"][map.generators.size()%3])
	for at in [Vector2i(5,39),Vector2i(12,37),Vector2i(6,24),Vector2i(12,20),Vector2i(7,17),Vector2i(4,10),Vector2i(16,12),Vector2i(16,5),Vector2i(25,42),Vector2i(30,34),Vector2i(32,43),Vector2i(28,26),Vector2i(23,25),Vector2i(29,11),Vector2i(35,4),Vector2i(47,41),Vector2i(54,40),Vector2i(49,7),Vector2i(56,13),Vector2i(46,26),Vector2i(56,28),Vector2i(68,24),Vector2i(71,31),Vector2i(71,10),Vector2i(71,43)]: item(map,at,"food")
	for at in [Vector2i(3,29),Vector2i(16,10),Vector2i(38,30),Vector2i(32,44),Vector2i(28,21),Vector2i(44,3),Vector2i(55,42),Vector2i(55,12),Vector2i(45,27),Vector2i(69,36),Vector2i(71,6)]: item(map,at,"potion")

static func point(x: int, y: int) -> Vector2:
	return (Vector2(x,y)+Vector2.ONE*0.5)*32.0

static func room(map: Dictionary, rect: Rect2i) -> void:
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x): map.floor[Vector2i(x,y)] = true

static func solid(map: Dictionary, rect: Rect2i) -> void:
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x): map.floor.erase(Vector2i(x,y))

static func corridor(map: Dictionary, corners: Array) -> void:
	for index in range(corners.size()-1):
		var at: Vector2i = corners[index]
		var end: Vector2i = corners[index+1]
		var direction := Vector2i(signi(end.x-at.x),signi(end.y-at.y))
		while true:
			room(map,Rect2i(at,Vector2i(2,2)))
			if at==end: break
			at += direction

static func gate(map: Dictionary, at: Vector2i, vertical: bool, color: String) -> void:
	var group: int = map.door_colors.size()
	map.door_colors[group] = color
	map.door_axes[group] = vertical
	map.arches.append({"pos":Vector3(at.x+0.5 if vertical else at.x+1.0,1.8,at.y+1.0 if vertical else at.y+0.5),"vertical":vertical})
	for offset in 2:
		var cell := at+Vector2i(0,offset) if vertical else at+Vector2i(offset,0)
		map.doors[cell] = group

static func item(map: Dictionary, at: Vector2i, kind: String) -> void:
	map.pickups.append({"pos":point(at.x,at.y),"kind":kind})

static func key(map: Dictionary, x: int, y: int, color: String) -> void:
	map.pickups.append({"pos":point(x,y),"kind":"key","key_color":color})

static func nest(map: Dictionary, at: Vector2i, kind: String) -> void:
	var hp := 250.0 if map.width==56 else 280.0
	map.generators.append({"pos":point(at.x,at.y),"kind":kind,"hp":hp,"max_hp":hp,"clock":2.4})
