extends RefCounted
## Shared temporary sight in floor tiles, based only on distance to current players.
const CLEAR_RADIUS := 7.0
const OUTER_RADIUS := 10.0
const MAX_PLAYERS := 16
var centers := PackedVector2Array()
var active := false

func update(heroes: Dictionary, phase: String, exit_position: Vector2) -> void:
	centers.clear()
	active = phase!="lobby"
	for hero: Dictionary in heroes.values():
		if not hero.escaped and centers.size()<MAX_PLAYERS: centers.append(hero.pos/32.0)
	if centers.is_empty() and phase in ["transition","complete"]: centers.append(exit_position/32.0)

func visibility_at(tile: Vector2) -> float:
	if not active: return 1.0
	var nearest := INF
	for center in centers: nearest = minf(nearest,center.distance_to(tile))
	return 1.0-smoothstep(CLEAR_RADIUS,OUTER_RADIUS,nearest)
