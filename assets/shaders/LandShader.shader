shader_type spatial;

uniform sampler2D u_texture;

void vertex()
{
}

void fragment()
{
	ALBEDO = texture(u_texture, UV).rgb;
	
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	
	//NORMAL = -normalize(cross(dpdy, dpdx));
}