shader_type canvas_item;

uniform sampler2D u_sdf;
uniform sampler2D u_mesh_tex;
uniform vec2 u_mesh_tex_size;
uniform int u_num_tris;
uniform int u_rows;
uniform int u_cols;
uniform int u_sdf_resolution;
uniform float u_sdf_volume_radius;
uniform float u_sdf_dist_mod;
uniform int u_draw_idx;

uniform bool u_use_bounding_sphere;
uniform vec3 u_bound_origin;
uniform float u_bound_radius;

float dot2( in vec3 v ) 
{ 
	return dot(v,v); 
}

float ud_triangle(vec3 p, vec3 a, vec3 b, vec3 c)
{
	vec3 ba = b - a; vec3 pa = p - a;
	vec3 cb = c - b; vec3 pb = p - b;
	vec3 ac = a - c; vec3 pc = p - c;
	vec3 nor = cross( ba, ac );

	return (sign(dot(cross(ba,nor),pa)) +
		sign(dot(cross(cb,nor),pb)) +
		sign(dot(cross(ac,nor),pc))<2.0)
		?
		min( min(
			dot2(ba*clamp(dot(ba,pa)/dot2(ba),0.0,1.0)-pa),
			dot2(cb*clamp(dot(cb,pb)/dot2(cb),0.0,1.0)-pb) ),
			dot2(ac*clamp(dot(ac,pc)/dot2(ac),0.0,1.0)-pc) )
		:
		dot(nor,pa)*dot(nor,pa)/dot2(nor);
}

vec2 mesh_idx_to_img_uv(int idx, vec2 tex_size)
{
	vec2 uv = vec2(float(idx % int(tex_size.x)), float(idx / int(tex_size.y)));
	return uv / u_mesh_tex_size;
}

vec3 sdf_uv_to_world_pos(vec2 uv)
{
	vec3 pos = vec3(uv.xy, 0.0);
	pos.x = fract(pos.x * float(u_cols));
	pos.y = fract(pos.y * float(u_rows));
	
	float col = floor(uv.x * float(u_cols));
	float row = floor((1.0 - uv.y) * float(u_rows));
	pos.z = (row * float(u_cols) + col) / float(u_sdf_resolution);
	pos -= 0.499;
	pos *= 2.0 * u_sdf_volume_radius;
	return pos;
}

void fragment() 
{
	// flip x when writing the sdf because reasons
	vec3 uv = sdf_uv_to_world_pos(vec2(1.0 - UV.x, UV.y));
	
	// skip this pixel if it's out of the supplied bounds
	bool skip = false;
	if (u_use_bounding_sphere)
	{
		if (length(u_bound_origin - uv) > u_bound_radius)
		{
			skip = true;
		}
	}
	
	vec4 current = texture(u_sdf, UV);
	
	if (!skip || u_draw_idx == 0)
	{
		float closest_dist = 999999.9;
		vec3 closest_tri[3];
		for (int i = 0; i < u_num_tris; i++)
		{
			int v = i * 3;
			vec3 v1 = texture(u_mesh_tex, mesh_idx_to_img_uv(v + 0, u_mesh_tex_size)).xyz;
			vec3 v2 = texture(u_mesh_tex, mesh_idx_to_img_uv(v + 1, u_mesh_tex_size)).xyz;
			vec3 v3 = texture(u_mesh_tex, mesh_idx_to_img_uv(v + 2, u_mesh_tex_size)).xyz;
			
			float dist = ud_triangle(uv, v1, v2, v3);
			if (dist < closest_dist)
			{
				closest_dist = dist;
				closest_tri[0] = v1;
				closest_tri[1] = v2;
				closest_tri[2] = v3;
			}
		}
		float dist = sqrt(closest_dist);
		vec3 crossp = cross(closest_tri[1] - closest_tri[0], closest_tri[2] - closest_tri[0]);
		float dotp = dot(normalize(crossp), normalize(closest_tri[0] - uv));
		
		dist /= u_sdf_dist_mod;
		
		if (u_draw_idx == 0)
			COLOR = vec4(dist, 0.0, 0.0, 1.0);
		else
			COLOR = vec4(min(dist, current.r), 0.0, 0.0, 1.0);
	}
	else
	{
		if (u_draw_idx == 0)
			COLOR = vec4(1.0, 0.0, 0.0, 1.0);
		else:
			COLOR = current;
	}
}