shader_type spatial;
render_mode world_vertex_coords;
render_mode unshaded, cull_disabled;

void vertex()
{
	VERTEX = VERTEX;
}

void fragment()
{
	ALBEDO = COLOR.rgb;
	ALPHA = 1.0;
}