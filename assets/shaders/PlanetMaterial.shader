shader_type spatial;
render_mode world_vertex_coords;
//render_mode unshaded;

void vertex()
{
	VERTEX = VERTEX;
}

void fragment()
{
	ALBEDO = COLOR.rgb;
	
	//vec3 dpdx = dFdx(VERTEX);
	//vec3 dpdy = dFdy(VERTEX);
	
	//NORMAL = -normalize(cross(dpdy, dpdx));
}