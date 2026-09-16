extends Node3D
## Low gate leaves keep the lock color readable from either corridor orientation.
const Campaign = preload("res://examples/gauntlet/campaign.gd")
var cells: Array = []
var leaves: Array[Node3D] = []
var status: Label3D
var opening := 0.0
var is_open := false
var key_color := "gold"

func configure(view: Node3D, group_cells: Array, color: String, vertical: bool) -> void:
	cells = group_cells
	key_color = color
	var midpoint := Vector2.ZERO
	for cell: Vector2i in cells: midpoint += view.Level.center(cell)
	position = view.at3(midpoint/cells.size())
	if not vertical: rotation.y = PI/2
	var tint: Color = Campaign.KEY_COLORS[color]
	# Thin edge inlays preserve the color while leaving ordinary floor visible through an open gate.
	for edge in [-1,1]:
		view.box(self,Vector3(edge*0.43,0.065,0),Vector3(0.07,0.035,2.0),tint.darkened(0.15))
	for side in [-1,1]:
		view.box(self,Vector3(0,0.36,side*1.05),Vector3(0.42,0.65,0.24),Color("485862"))
		var cap: MeshInstance3D = view.box(self,Vector3(0,0.71,side*1.05),Vector3(0.45,0.10,0.28),tint)
		cap.material_override = view.material(tint,0,0.35)
		var leaf := Node3D.new()
		add_child(leaf)
		leaf.position.z = side*0.46
		leaves.append(leaf)
		view.box(leaf,Vector3(0,0.36,0),Vector3(0.30,0.58,0.90),Color("283742"))
		var panel: MeshInstance3D = view.box(leaf,Vector3(0,0.40,0),Vector3(0.34,0.42,0.78),tint)
		panel.material_override = view.material(tint,0,0.30)
		view.box(leaf,Vector3(0,0.69,0),Vector3(0.38,0.09,0.91),tint.lightened(0.18))
		for seam in [-1,1]:
			view.box(leaf,Vector3(0,0.745,seam*0.24),Vector3(0.38,0.015,0.025),Color("283742"))
	status = Label3D.new()
	status.name = "GateState"
	status.position.y = 1.20
	status.font_size = 32
	status.pixel_size = 0.009
	status.outline_size = 9
	status.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status.modulate = tint.lightened(0.12)
	add_child(status)
	present(false,0)

func present(unlocked: bool, delta: float) -> void:
	is_open = unlocked
	opening = move_toward(opening,1.0 if unlocked else 0.0,maxf(0,delta)*4.5)
	for i in leaves.size():
		leaves[i].position.z = (-1.0 if i==0 else 1.0)*(0.46+opening*0.78)
		leaves[i].scale.y = 1.0-opening*0.80
		leaves[i].visible = opening<1.0
	status.text = key_color.capitalize()
