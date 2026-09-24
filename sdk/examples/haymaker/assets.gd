extends RefCounted
## Generated carnival-city textures and concept posters.

const ROOT := "res://examples/haymaker/assets/"

static func texture(relative: String) -> Texture2D:
	var path := ROOT + relative
	if ResourceLoader.exists(path):
		return load(path)
	return null


static func painted(tex_name: String, tint := Color.WHITE, roughness := 0.74, scale := 0.22) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = roughness
	var tex := texture("textures/" + tex_name)
	if tex:
		mat.albedo_texture = tex
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_triplanar_sharpness = 4.0
		mat.uv1_scale = Vector3(scale, scale, scale)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat


static func poster(source_name: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.roughness = 0.62
	var tex := texture("source/" + source_name)
	if tex:
		mat.albedo_texture = tex
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return mat


static func emit(color: Color, energy := 1.4) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.28
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat
