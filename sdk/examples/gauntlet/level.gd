extends RefCounted
## An original first dungeon built around the arcade game's cooperative loop.
const WIDTH := 40
const HEIGHT := 20
const TILE := 32.0
const EXIT := Vector2(1200,80)
const CLASSES := [
	{"name":"WARRIOR", "color":"ed775f", "health":1000.0, "speed":100.0, "damage":44.0, "rate":0.40, "magic":95.0},
	{"name":"VALKYRIE", "color":"81c6e2", "health":900.0, "speed":110.0, "damage":32.0, "rate":0.30, "magic":110.0},
	{"name":"WIZARD", "color":"ba9aef", "health":700.0, "speed":105.0, "damage":30.0, "rate":0.30, "magic":220.0},
	{"name":"ELF", "color":"a4d478", "health":750.0, "speed":125.0, "damage":25.0, "rate":0.22, "magic":120.0},
]
static func center(cell: Vector2i) -> Vector2:
	return (Vector2(cell)+Vector2(0.5,0.5))*TILE
static func cell(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x/TILE),floori(at.y/TILE))
static func spawn(id: int) -> Vector2:
	return Vector2(96+((id-1)%4)*64,392+((id-1)/4)*64)
static func walls() -> Dictionary:
	var result := {}
	for y in HEIGHT:
		for x in WIDTH:
			if x==0 or y==0 or x==WIDTH-1 or y==HEIGHT-1:
				result[Vector2i(x,y)] = true
	for y in range(1,19):
		if y not in [14,15]: result[Vector2i(12,y)] = true
		if y not in [5,6]: result[Vector2i(26,y)] = true
	for x in range(13,26):
		if x not in [19,20]: result[Vector2i(x,10)] = true
	# Alcoves and columns leave two-tile passages for a large party.
	for box in [Rect2i(4,4,3,2),Rect2i(8,8,2,2),Rect2i(16,4,2,3),Rect2i(22,14,2,2),Rect2i(30,8,2,3),Rect2i(35,15,2,2)]:
		for y in range(box.position.y,box.end.y):
			for x in range(box.position.x,box.end.x): result[Vector2i(x,y)] = true
	return result
static func doors() -> Dictionary:
	return {Vector2i(12,14):0,Vector2i(12,15):0,Vector2i(26,5):1,Vector2i(26,6):1}
static func generators() -> Array:
	var result: Array = []
	for entry in [[Vector2i(6,2),"ghost"],[Vector2i(19,16),"grunt"],[Vector2i(22,3),"ghost"],[Vector2i(34,12),"demon"]]:
		result.append({"pos":center(entry[0]),"kind":entry[1],"hp":220.0,"max_hp":220.0,"clock":1.8})
	return result
static func pickups() -> Array:
	var result: Array = []
	var groups := {
		"key":[Vector2i(9,13),Vector2i(24,2)],
		"food":[Vector2i(3,10),Vector2i(9,3),Vector2i(15,16),Vector2i(22,12),Vector2i(15,2),Vector2i(29,4),Vector2i(37,13)],
		"potion":[Vector2i(8,16),Vector2i(15,12),Vector2i(23,7),Vector2i(29,16)],
		"gold":[Vector2i(2,2),Vector2i(3,2),Vector2i(9,6),Vector2i(10,6),Vector2i(15,7),Vector2i(16,8),Vector2i(24,17),Vector2i(23,17),Vector2i(29,2),Vector2i(30,2),Vector2i(37,17),Vector2i(38,17)]}
	for kind in groups:
		for at in groups[kind]: result.append({"pos":center(at),"kind":kind})
	return result
