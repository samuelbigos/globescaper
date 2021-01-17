shader_type spatial;
render_mode unshaded;

void vertex()
{
	VERTEX = VERTEX;
}

void fragment()
{
	//ALBEDO = vec3(180.0 / 255.0, 200.0 / 255.0, 230.0 / 255.0);
	ALBEDO = vec3(255.0 / 255.0, 255.0 / 255.0, 255.0 / 255.0);
	ALPHA = 0.5;
	
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	
	//NORMAL = -normalize(cross(dpdy, dpdx));
}