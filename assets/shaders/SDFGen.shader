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

int intersect_tri(vec3 ray_origin, vec3 ray_dir, vec3 v0, vec3 v1, vec3 v2)
{
	float EPSILON = 0.00001;
	
	float a,f,u,v;
	vec3 edge1, edge2, h, s, q;
    edge1 = v1 - v0;
    edge2 = v2 - v0;
    h = cross(ray_dir, edge2);
    a = dot(edge1, h);
    if (a > -EPSILON && a < EPSILON)
        return 0; // this ray is parallel to this triangle.
		
	f = 1.0/a;
    s = ray_origin - v0;
	u = f * dot(s, h);
	if (u < 0.0 || u > 1.0)
        return 0;
		
	q = cross(s, edge1);
    v = f * dot(ray_dir, q);
    if (v < 0.0 || u + v > 1.0)
        return 0;
		
	// at this stage we can compute t to find out where the intersection point is on the line.
	float t = f * dot(edge2, q);
    if (t > EPSILON) // ray intersection
    {
        //outIntersectionPoint = rayOrigin + rayVector * t;
        return 1;
    }
    else // this means that there is a line intersection but not a ray intersection.
        return 0;
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
			skip = true;
	}
	
	vec4 current = texture(u_sdf, UV);
	
	if (!skip)
	{
		float closest_dist = 999999.9;
		vec3 closest_tri[3];
		int intersections[3] = {0, 0, 0};
		for (int i = 0; i < u_num_tris; i++)
		{
			int v = i * 3;
			vec3 v1 = texture(u_mesh_tex, mesh_idx_to_img_uv(v + 0, u_mesh_tex_size)).xyz;
			vec3 v2 = texture(u_mesh_tex, mesh_idx_to_img_uv(v + 1, u_mesh_tex_size)).xyz;
			vec3 v3 = texture(u_mesh_tex, mesh_idx_to_img_uv(v + 2, u_mesh_tex_size)).xyz;

			// cast a ray in 3 cardinal directions from the sample point, and test if we intersect this
			// triangle. if the total number of intersections along a ray is even, we can consider the sample
			// point inside the mesh. we test 3 directions and take the majority result because it is
			// possible for an intersection test to return a false negative depending on the geometry of
			// the mesh.
			intersections[0] += intersect_tri(uv, vec3(0.0, 1.0, 0.0), v1, v2, v3);
			intersections[1] += intersect_tri(uv, vec3(1.0, 0.0, 0.0), v1, v2, v3);
			intersections[2] += intersect_tri(uv, vec3(0.0, 0.0, 1.0), v1, v2, v3);
			
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
		dist /= u_sdf_dist_mod;
		dist = clamp(dist, 0.0, 1.0);
		
		// determine if we're inside or outside the mesh based on the intersection test results.
		int odd_intersections = 0;
		for (int i = 0; i < 3; i++)
			odd_intersections += intersections[i] % 2;
		bool outside = odd_intersections < 2;
		dist = dist * (outside ? 1.0 : -1.0);
		
		// on the first draw we have no previous dist to compare with so just dump our new dist.
		if (u_draw_idx == 0)
		{
			COLOR = vec4(dist * 0.5 + 0.5, 0.0, 0.0, 1.0);
		}
		else
		{
			float prev_dist = current.r * 2.0 - 1.0;
			float final = min(prev_dist, dist) * 0.5 + 0.5;
			COLOR = vec4(final, step(final, 0.5), 0.0, 1.0);
		}
	}
	else
	{
		if (u_draw_idx == 0)
		{
			COLOR = vec4(1.0, 0.0, 0.0, 1.0);
		}
		else
		{
			COLOR = current;
		}
	}
}