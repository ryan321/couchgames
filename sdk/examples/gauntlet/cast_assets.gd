extends RefCounted
## Authored Blender assets. Imported meshes/materials stay shared; identity colors are local.
const ROOT := "res://examples/gauntlet/assets/cast/"
const ARMOR := ["WarriorArmor","ValkyrieArmor","WizardDetails","ElfArmor"]
const WEAPONS := ["WarriorAxe","ValkyrieSword","WizardStaff","ElfBow"]
const SHIELDS := ["WarriorShield","ValkyrieShield"]
const CREATURES := {"ghost":"Wraith","grunt":"Raider","demon":"EmberDemon"}
static var scenes: Dictionary = {}
# Immutable palette variants also outlive queued renderer teardown when portraits are replaced.
static var color_materials: Dictionary = {}

static func instance(asset: String) -> Node3D:
	if not scenes.has(asset): scenes[asset] = load(ROOT+asset+".glb")
	var result: Node3D = scenes[asset].instantiate()
	result.name = asset
	return result

static func armor(kind: int, color: Color) -> Node3D:
	return colored_instance(ARMOR[kind],color)

static func colored_instance(asset: String, color: Color) -> Node3D:
	var result := instance(asset)
	for mesh: MeshInstance3D in result.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var source: Material = mesh.mesh.surface_get_material(surface)
			if source is StandardMaterial3D and source.resource_name.begins_with("IdentityCloth"):
				var key := "%d/%s"%[source.get_instance_id(),color.to_html()]
				if not color_materials.has(key):
					var material: StandardMaterial3D = source.duplicate()
					material.albedo_color = color
					color_materials[key] = material
				mesh.set_surface_override_material(surface,color_materials[key])
	return result
