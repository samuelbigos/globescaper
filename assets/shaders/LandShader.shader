shader_type spatial;

uniform sampler2D u_texture;
uniform sampler3D u_voxels;
uniform sampler2D u_mesh_tex;
uniform vec2 u_mesh_tex_size;
uniform int u_num_tris;
uniform vec3 u_voxels_offset = vec3(0.0, 0.0, 0.0);
uniform float u_world_size = 10.0;
uniform int u_voxel_res = 2;

varying vec3 v_vertex;

void vertex()
{
	v_vertex = VERTEX;
}

vec3 tri_sample(sampler3D sampler, vec3 uv, vec3 texel_size)
{
	return texture(sampler, clamp(uv * texel_size, vec3(0.0), vec3(0.999))).rgb;
}

vec3 tri_lerp(sampler3D sampler, vec3 uv, vec3 tex_size)
{		
	vec3 inv_tex_size = 1.0 / tex_size;
	uv += inv_tex_size * 0.5;
	
	vec3 sample = uv * tex_size;
	sample = floor(sample);
	sample -= vec3(0.5);
	
	vec3 x0y0z0 = tri_sample(sampler, sample + vec3(0.0, 0.0, 0.0), inv_tex_size).xyz;
	vec3 x0y0z1 = tri_sample(sampler, sample + vec3(0.0, 0.0, 1.0), inv_tex_size).xyz;
	vec3 x0y1z0 = tri_sample(sampler, sample + vec3(0.0, 1.0, 0.0), inv_tex_size).xyz;
	vec3 x0y1z1 = tri_sample(sampler, sample + vec3(0.0, 1.0, 1.0), inv_tex_size).xyz;
	vec3 x1y0z0 = tri_sample(sampler, sample + vec3(1.0, 0.0, 0.0), inv_tex_size).xyz;
	vec3 x1y0z1 = tri_sample(sampler, sample + vec3(1.0, 0.0, 1.0), inv_tex_size).xyz;
	vec3 x1y1z0 = tri_sample(sampler, sample + vec3(1.0, 1.0, 0.0), inv_tex_size).xyz;
	vec3 x1y1z1 = tri_sample(sampler, sample + vec3(1.0, 1.0, 1.0), inv_tex_size).xyz;

	vec3 f = fract(uv * tex_size);

	vec3 z1 = mix(x0y0z0, x0y0z1, f.z);
	vec3 z2 = mix(x0y1z0, x0y1z1, f.z);
	vec3 z3 = mix(x1y0z0, x1y0z1, f.z);
	vec3 z4 = mix(x1y1z0, x1y1z1, f.z);

	vec3 y1 = mix(z1, z2, f.y);
	vec3 y2 = mix(z3, z4, f.y);

	return mix(y1, y2, f.x);
}

float dot2( in vec3 v ) 
{ 
	return dot(v,v); 
}

float udTriangle( vec3 p, vec3 a, vec3 b, vec3 c )
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

void fragment()
{
	if (false) // draw 3d texture
	{
		vec3 uv = ((v_vertex - u_voxels_offset) / u_world_size); // adjust by world bounds and offset
		uv = (uv + vec3(1.0)) / 2.0; // convert to 0-1
		if (uv.x < 0.0 || uv.y < 0.0 || uv.z < 0.0 || uv.x > 1.0 || uv.y > 1.0 || uv.z > 1.0)
			ALBEDO = texture(u_texture, UV).rgb;
		else
			ALBEDO = tri_lerp(u_voxels, uv, vec3(float(u_voxel_res))).rgb;
	}
	
	if (true) // draw sdf
	{
		vec3 pixel = v_vertex;
		float closest_dist = 999999.9;
		vec3 closest_tri[3];
		for (int v = 0; v < u_num_tris * 3; v += 3)
		{
			vec3 v1 = texture(u_mesh_tex, vec2(float(v) / u_mesh_tex_size.x, 0.0)).xyz;
			vec3 v2 = texture(u_mesh_tex, vec2(float(v + 1)  / u_mesh_tex_size.x, 0.0)).xyz;
			vec3 v3 = texture(u_mesh_tex, vec2(float(v + 2)  / u_mesh_tex_size.x, 0.0)).xyz;
			
			float dist = udTriangle(pixel, v1, v2, v3);
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
		float dotp = dot(normalize(crossp), normalize(closest_tri[0] - pixel));
		
		float sd = dist * sign(-dotp);
		float distance_mod = 25.0;
		sd = clamp(sd / distance_mod, -1.0, 1.0);
		
		ALBEDO = vec3(sd, -sd, 0.0);
		
		//ALBEDO = texture(u_mesh_tex, vec2(4.0 / , 0.0)).rgb;
	}
	//ALBEDO = texture(u_texture, UV).rgb;
}