extends RefCounted
## One authored axe stroke, shared by the visible weapon and simulation hit sweep.
const WINDUP := 0.14
const STRIKE_END := 0.32
const DURATION := 0.72
const BLADE_INNER := Vector3(0.34,0.50,0)
const BLADE_OUTER := Vector3(0.34,0.79,0)
const MODEL_SCALE := 1.05
const GRIP := Vector3(0,-.09,0)

static func ready_pose() -> Transform3D:
	return Transform3D(Basis.IDENTITY,Vector3(-.32,1.10,.18))

static func strike_pose(angle: float) -> Transform3D:
	var radial := Vector3(sin(angle),0,cos(angle))
	var cutting := Vector3(cos(angle),0,-sin(angle))
	var basis := Basis(cutting,radial,cutting.cross(radial))*Basis.from_scale(Vector3(1,1.17,1))
	return Transform3D(basis,Vector3(-.15,1.17,0)+radial*.35)

static func pose(age: float) -> Transform3D:
	var start := strike_pose(deg_to_rad(-65))
	var finish := strike_pose(deg_to_rad(65))
	if age<0 or age>=DURATION: return ready_pose()
	if age<WINDUP: return ready_pose().interpolate_with(start,smoothstep(0,WINDUP,age))
	if age<=STRIKE_END:
		return strike_pose(lerpf(deg_to_rad(-65),deg_to_rad(65),(age-WINDUP)/(STRIKE_END-WINDUP)))
	return finish.interpolate_with(ready_pose(),smoothstep(STRIKE_END,DURATION,age))

static func blade(age: float, facing: Vector2) -> PackedVector2Array:
	var transform := Transform3D(Basis(Vector3.UP,atan2(facing.x,facing.y)),Vector3.ZERO)*pose(age)
	var a := transform*BLADE_INNER*MODEL_SCALE*32.0
	var b := transform*BLADE_OUTER*MODEL_SCALE*32.0
	return PackedVector2Array([Vector2(a.x,a.z),Vector2(b.x,b.z)])

static func touches(origin: Vector2, facing: Vector2, target: Vector2, radius: float, from_age: float, to_age: float) -> bool:
	if to_age<WINDUP or from_age>STRIKE_END: return false
	var begin := maxf(WINDUP,from_age)
	var end := minf(STRIKE_END,to_age)
	# Subsample the same blade capsule so frame hitches cannot skip an enemy.
	var steps := maxi(1,ceili((end-begin)/0.008))
	for step in steps+1:
		var edge := blade(lerpf(begin,end,float(step)/steps),facing)
		var nearest := Geometry2D.get_closest_point_to_segment(target,origin+edge[0],origin+edge[1])
		if nearest.distance_to(target)<=radius+3.0: return true
	return false
