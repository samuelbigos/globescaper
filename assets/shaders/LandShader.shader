shader_type spatial;
//render_mode unshaded;

uniform sampler2D u_texture;

varying vec3 v_vertex;
varying vec3 v_normal;

void vertex()
{
	v_vertex = VERTEX;
	v_normal = NORMAL;
}

void fragment()
{
	ALBEDO = texture(u_texture, UV).rgb;
}