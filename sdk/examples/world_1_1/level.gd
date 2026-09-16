extends RefCounted
## Tile coordinates transcribed from Rick N. Bruns' NES World 1-1 map.
const WIDTH := 3584
const GAPS := [[69,71],[86,89],[153,155]]
const PIPES := [[28,2],[38,3],[46,4],[57,4],[163,2],[179,2]]
const GOOMBAS := [[352,208],[640,208],[816,208],[840,208],[1280,80],[1312,80],
	[1552,208],[1576,208],[1824,208],[1848,208],[1984,208],[2008,208],
	[2048,208],[2072,208],[2784,208],[2808,208]]
const DECOR := [Rect2(3072,173,80,35),Rect2(184,192,64,16),Rect2(256,189,48,19),
	Rect2(376,192,32,16),Rect2(664,192,48,16),Rect2(136,48,32,24),
	Rect2(312,32,32,24),Rect2(440,48,64,24),Rect2(584,32,48,24)]

static func blocks() -> Dictionary:
	var result := {}
	for x in [20,22,24,77,79,100,118,129,130,168,169,171]:
		result[Vector2i(x,9)] = {"kind":"brick","content":"","left":0,"bump":0.0}
	for x in range(80,88):
		result[Vector2i(x,5)] = {"kind":"brick","content":"","left":0,"bump":0.0}
	for x in [91,92,93,121,122,123,128,131]:
		result[Vector2i(x,5)] = {"kind":"brick","content":"","left":0,"bump":0.0}
	for at in [Vector2i(16,9),Vector2i(23,9),Vector2i(22,5),Vector2i(94,5),
		Vector2i(106,9),Vector2i(109,9),Vector2i(112,9),Vector2i(129,5),Vector2i(130,5),Vector2i(170,9)]:
		result[at] = {"kind":"question","content":"coin","left":1,"bump":0.0}
	for at in [Vector2i(21,9),Vector2i(78,9),Vector2i(109,5)]:
		result[at] = {"kind":"question","content":"power","left":1,"bump":0.0}
	result[Vector2i(94,9)] = {"kind":"brick","content":"coin","left":10,"bump":0.0}
	result[Vector2i(101,9)] = {"kind":"brick","content":"star","left":1,"bump":0.0}
	result[Vector2i(64,8)] = {"kind":"hidden","content":"life","left":1,"bump":0.0}
	return result

static func solids(underground := false) -> Dictionary:
	var result := {}
	if underground:
		for x in 17:
			for y in [13,14]: result[Vector2i(x,y)] = "underground"
		for y in range(2,13): result[Vector2i(0,y)] = "brick_dark"
		for x in range(4,11):
			result[Vector2i(x,2)] = "brick_dark"
			for y in range(10,13): result[Vector2i(x,y)] = "brick_dark"
		for x in [15,16]:
			for y in range(2,13): result[Vector2i(x,y)] = "pipe_dark"
		for x in [13,14]:
			for y in [11,12]: result[Vector2i(x,y)] = "pipe_dark"
		return result
	for x in 224:
		var gap := false
		for bounds in GAPS:
			if x>=bounds[0] and x<bounds[1]: gap = true
		if not gap:
			for y in [13,14]: result[Vector2i(x,y)] = "ground"
	for pipe in PIPES:
		for x in range(pipe[0],pipe[0]+2):
			for y in range(13-pipe[1],13): result[Vector2i(x,y)] = "pipe"
	for start in [134,148]:
		for i in 4:
			for y in range(12-i,13): result[Vector2i(start+i,y)] = "step"
	for start in [140,155]:
		for i in 4:
			for y in range(9+i,13): result[Vector2i(start+i,y)] = "step"
	for y in range(9,13): result[Vector2i(152,y)] = "step"
	for i in 9:
		for y in range(12-mini(i,7),13): result[Vector2i(181+i,y)] = "step"
	result[Vector2i(198,12)] = "step"
	return result
