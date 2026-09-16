extends RefCounted
## Shared original Blender assets. Only exported GLBs ship with the game.
const ROOT := "res://examples/gauntlet/assets/environment/"
const NAMES := ["VaultChest","JadePotion","EmberBrazier","RunicKey","FeastPlatter","CeramicUrn","OakBarrel","FloorGrate","SummoningAltar","WingRelief","DressedStone"]
static var scenes: Dictionary = {}

static func instance(asset: String, size := 1.0) -> Node3D:
	if not scenes.has(asset): scenes[asset] = load(ROOT+asset+".glb")
	var result: Node3D = scenes[asset].instantiate()
	result.scale = Vector3.ONE*size
	return result

static func geometry(asset: String) -> Mesh:
	var model := instance(asset)
	var result: Mesh = model.find_children("*","MeshInstance3D",true,false)[0].mesh
	model.free()
	return result
