extends Node

export var _sdf_max_width : int = 4096
export var _sdf_resolution : int = 256
export var _sdf_volume_radius := 17.0
export var _sdf_dist_mod := 5.0
export var _mesh_image_size = Vector2(64, 64)

var _sdf_volume_mat : Material
var _viewport : Viewport
var _viewport_tex : TextureRect
var _viewport_mat : Material
var _draw_idx := 0


func _ready():
	_viewport = get_node("Viewport")
	_viewport_tex = _viewport.get_node("Rect")
	_viewport_mat = _viewport_tex.material
	
	var per_row = _sdf_max_width / _sdf_resolution
	var cols = min(_sdf_resolution, per_row)
	var rows = int(ceil(float(_sdf_resolution) / per_row))	
	
	var res = Vector2(cols * _sdf_resolution, rows * _sdf_resolution)
	_viewport.set_update_mode(Viewport.UPDATE_ONCE)
	_viewport.size = res
	_viewport.get_node("Rect").rect_size = res
	_viewport_mat.set_shader_param("u_rows", int(rows))
	_viewport_mat.set_shader_param("u_cols", int(cols))
	_viewport_mat.set_shader_param("u_sdf_resolution", _sdf_resolution)
	_viewport_mat.set_shader_param("u_sdf_volume_radius", _sdf_volume_radius)
	_viewport_mat.set_shader_param("u_sdf_dist_mod", _sdf_dist_mod)
		
	_sdf_volume_mat = $SDFVolume.mesh.surface_get_material(0)
	_sdf_volume_mat.set_shader_param("u_rows", int(rows))
	_sdf_volume_mat.set_shader_param("u_cols", int(cols))
	_sdf_volume_mat.set_shader_param("u_sdf_volume_radius", _sdf_volume_radius)
	_sdf_volume_mat.set_shader_param("u_sdf_dist_mod", _sdf_dist_mod)
	_sdf_volume_mat.set_shader_param("u_sdf_resolution", _sdf_resolution)
	$SDFVolume.mesh.size = Vector3(_sdf_volume_radius * 2.0, _sdf_volume_radius * 2.0, _sdf_volume_radius * 2.0)
	
func _process(_delta) -> void:
	_sdf_volume_mat.set_shader_param("u_cam_pos", get_viewport().get_camera().global_transform.origin)
	_sdf_volume_mat.set_shader_param("u_sdf", get_texture())
	$SDFPreview.set_texture(get_texture())
		
func reset():
	_draw_idx = 0	
	
func set_mesh_texture(var verts) ->void:
	if verts.size() == 0:
		return
		
	var mesh_data = Image.new()
	mesh_data.create(_mesh_image_size.x, _mesh_image_size.y, false, Image.FORMAT_RGBH)
	mesh_data.lock()
	
	var ub = verts[0]
	var lb = verts[0]
	for i in range(0, verts.size()):
		var col = Color()
		col.r = verts[i].x
		col.g = verts[i].y
		col.b = verts[i].z
		
		var x = int(i) % int(_mesh_image_size.x)
		var y = int(i) / int(_mesh_image_size.y)
		mesh_data.set_pixel(x, y, col)
		var v = verts[i]
		ub = Vector3(max(ub.x, v.x), max(ub.y, v.y), max(ub.z, v.z))
		lb = Vector3(min(lb.x, v.x), min(lb.y, v.y), min(lb.z, v.z))
		
	mesh_data.unlock()
	
	# calculate the bounding sphere
	var centre = (ub + lb) / 2.0
	var radius = ub.distance_to(centre) + _sdf_dist_mod
	
	_viewport_mat.set_shader_param("u_use_bounding_sphere", true)
	_viewport_mat.set_shader_param("u_bound_origin", centre)
	_viewport_mat.set_shader_param("u_bound_radius", radius)
	
	var image_texture = ImageTexture.new()
	image_texture.create_from_image(mesh_data, 0)
	
	_viewport_mat.set_shader_param("u_sdf", _viewport.get_texture())
	_viewport_mat.set_shader_param("u_mesh_tex", image_texture)
	_viewport_mat.set_shader_param("u_mesh_tex_size", _mesh_image_size)
	_viewport_mat.set_shader_param("u_num_tris", verts.size() / 3)
	_viewport_mat.set_shader_param("u_draw_idx", _draw_idx)
	_viewport.set_update_mode(Viewport.UPDATE_ONCE)
	_draw_idx += 1
	
func get_texture() -> Texture:
	_viewport.get_texture().flags = Texture.FLAG_FILTER
	return _viewport.get_texture()

func set_sdf_params_on_mat(var material : Material) -> void:
	var per_row = _sdf_max_width / _sdf_resolution
	var cols = min(_sdf_resolution, per_row)
	var rows = int(ceil(float(_sdf_resolution) / per_row))
	
	material.set_shader_param("u_sdf", get_texture())
	material.set_shader_param("u_rows", int(rows))
	material.set_shader_param("u_cols", int(cols))
	material.set_shader_param("u_sdf_volume_radius", _sdf_volume_radius)
	material.set_shader_param("u_sdf_dist_mod", _sdf_dist_mod)
	material.set_shader_param("u_sdf_resolution", _sdf_resolution)
