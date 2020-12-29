shader_type spatial;
render_mode world_vertex_coords;

uniform sampler2D u_texture;

void vertex()
{
	VERTEX = VERTEX;
}

void fragment()
{
	ALBEDO = texture(u_texture, UV).rgb;
	
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	
	NORMAL = -normalize(cross(dpdy, dpdx));
}