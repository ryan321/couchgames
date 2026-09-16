extends RefCounted
## Current shared sight, in floor tiles. Walls and closed doors stop rays; no explored history.
const CLEAR_RADIUS := 7.0
const OUTER_RADIUS := 10.0
const MAX_PLAYERS := 16
var centers := PackedVector2Array()
var active := false
var size := Vector2i.ZERO
var walls: Dictionary = {}
var closed_doors: Dictionary = {}
var image: Image
var revision := 0
var last_signature := 0
var fields: Dictionary = {}
var obstacle_signature := 0
const OCTANTS := [Vector4i(1,0,0,1),Vector4i(0,1,1,0),Vector4i(0,-1,1,0),Vector4i(-1,0,0,1),Vector4i(-1,0,0,-1),Vector4i(0,-1,-1,0),Vector4i(0,1,-1,0),Vector4i(1,0,0,-1)]

func configure(map_size: Vector2i, solid_walls: Dictionary) -> void:
	size = map_size
	walls = solid_walls
	image = Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	last_signature = -1
	fields.clear()

func update(heroes: Dictionary, phase: String, exit_position: Vector2, doors: Dictionary = {}) -> void:
	centers.clear()
	active = phase!="lobby"
	closed_doors = doors
	for hero: Dictionary in heroes.values():
		if not hero.escaped and centers.size()<MAX_PLAYERS: centers.append(hero.pos/32.0)
	if centers.is_empty() and phase in ["transition","complete"]: centers.append(exit_position/32.0)
	if size==Vector2i.ZERO: return
	# Occlusion changes at tile boundaries; the radial falloff still follows exact positions.
	var quantized := PackedVector2Array()
	for center in centers: quantized.append(center.floor())
	var obstacles := hash([hash(walls),hash(doors)])
	if obstacles!=obstacle_signature:
		fields.clear()
		obstacle_signature = obstacles
	var signature := hash([quantized,active,obstacles])
	if signature==last_signature: return
	last_signature = signature
	image.fill(Color.BLACK)
	for center in centers:
		var origin := Vector2i(floori(center.x),floori(center.y))
		if not fields.has(origin):
			if fields.size()>=64: fields.clear()
			var mask := Image.create(23,23,false,Image.FORMAT_RGBA8)
			mask.fill(Color.TRANSPARENT)
			for target in field(origin):
				if target.distance_to(Vector2(origin)+Vector2.ONE*.5)<=OUTER_RADIUS+.5:
					var pixel := Vector2i(target)-origin+Vector2i(11,11)
					mask.set_pixel(pixel.x,pixel.y,Color.WHITE)
			fields[origin] = mask
		image.blend_rect(fields[origin],Rect2i(0,0,23,23),origin-Vector2i(11,11))
	revision += 1

func field(origin: Vector2i) -> PackedVector2Array:
	# Scan eight wedges near-to-far. Solid squares add angular shadow intervals;
	# later floor-cell centers inside those intervals cannot see past the blocker.
	var revealed := {}
	var hidden := {}
	if origin.x>=0 and origin.y>=0 and origin.x<size.x and origin.y<size.y: revealed[origin] = true
	for octant: Vector4i in OCTANTS:
		var shadows: Array[Vector2] = []
		for row in range(1,int(OUTER_RADIUS)+2):
			if shadows.size()==1 and shadows[0].x<=0 and shadows[0].y>=1: break
			for column in range(row+1):
				var cell := origin+Vector2i(row*octant.x+column*octant.y,row*octant.z+column*octant.w)
				if cell.x<0 or cell.y<0 or cell.x>=size.x or cell.y>=size.y: continue
				var low := maxf(0,(column-.5)/(row+.5))
				var high := minf(1,(column+.5)/(row-.5))
				var slope := float(column)/row
				var blocked := false
				var solid := opaque(cell)
				for shadow in shadows:
					if (solid and low>=shadow.x and high<=shadow.y) or (not solid and slope>=shadow.x-.000001 and slope<=shadow.y+.000001):
						blocked = true
						break
				if blocked:
					if not solid: hidden[cell] = true
					continue
				revealed[cell] = true
				if solid:
					var merged := Vector2(low,high)
					for index in range(shadows.size()-1,-1,-1):
						if shadows[index].x<=merged.y and shadows[index].y>=merged.x:
							merged = Vector2(minf(merged.x,shadows[index].x),maxf(merged.y,shadows[index].y))
							shadows.remove_at(index)
					shadows.append(merged)
	var result := PackedVector2Array()
	for cell: Vector2i in revealed:
		if hidden.has(cell): continue
		var offset: Vector2i = cell-origin
		# Octants overlap on their boundaries; require a strict supercover ray there.
		if (offset.x==0 or offset.y==0 or absi(offset.x)==absi(offset.y)) and not clear_line(Vector2(origin)+Vector2.ONE*.5,Vector2(cell)+Vector2.ONE*.5): continue
		result.append(Vector2(cell)+Vector2.ONE*.5)
	return result

func opaque(cell: Vector2i) -> bool:
	return cell.x<0 or cell.y<0 or cell.x>=size.x or cell.y>=size.y or walls.has(cell) or closed_doors.has(cell)

func clear_line(origin: Vector2, target: Vector2) -> bool:
	# Grid DDA visits every crossed cell, including both sides of an exact diagonal corner.
	var cell := Vector2i(floori(origin.x),floori(origin.y))
	var finish := Vector2i(floori(target.x),floori(target.y))
	var ray := target-origin
	var step := Vector2i(signf(ray.x),signf(ray.y))
	var increment := Vector2(INF if step.x==0 else absf(1.0/ray.x),INF if step.y==0 else absf(1.0/ray.y))
	var next := Vector2(INF,INF)
	if step.x!=0: next.x = (cell.x+(1 if step.x>0 else 0)-origin.x)/ray.x
	if step.y!=0: next.y = (cell.y+(1 if step.y>0 else 0)-origin.y)/ray.y
	for iteration in 32:
		if cell==finish: return true # The blocking wall/door itself remains readable.
		if is_equal_approx(next.x,next.y):
			if opaque(cell+Vector2i(step.x,0)) or opaque(cell+Vector2i(0,step.y)): return false
			cell += step
			next += increment
		elif next.x<next.y:
			cell.x += step.x
			next.x += increment.x
		else:
			cell.y += step.y
			next.y += increment.y
		if cell!=finish and opaque(cell): return false
	return false

func visibility_at(tile: Vector2) -> float:
	if not active: return 1.0
	if size!=Vector2i.ZERO:
		var cell := Vector2i(floori(tile.x),floori(tile.y))
		if cell.x<0 or cell.y<0 or cell.x>=size.x or cell.y>=size.y: return 0.0
		if image.get_pixel(cell.x,cell.y).r<.5: return 0.0
	var nearest := INF
	for center in centers: nearest = minf(nearest,center.distance_to(tile))
	return 1.0-smoothstep(CLEAR_RADIUS,OUTER_RADIUS,nearest)
