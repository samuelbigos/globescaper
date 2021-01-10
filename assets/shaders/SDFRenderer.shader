shader_type spatial;
render_mode unshaded;

uniform sampler2D u_sdf;
uniform int u_sdf_resolution;
uniform float u_sdf_volume_radius;
uniform float u_sdf_dist_mod;
uniform int u_rows;
uniform int u_cols;
uniform vec3 u_cam_pos;

varying vec3 u_vertex;

void vertex()
{
	u_vertex = VERTEX;
}

vec3 sample_sdf(vec3 world_pos)
{	
	int z = int(world_pos.z * float(u_sdf_resolution));

	int col = z % u_cols;
	int row = z / u_cols;
	
	float y_scale = float(u_rows * u_sdf_resolution) / float(textureSize(u_sdf, 0).y);
	
	float x = (float(col) / float(u_cols)) + world_pos.x / float(u_cols);
	float y = (float(row) / float(u_rows)) + world_pos.y / float(u_rows);
	
	return texture(u_sdf, vec2(x, y)).rgb;
}

vec3 sample_sdf_1d(vec3 uv)
{
	uv.x *= float(-1.0);
	uv.z *= float(-1.0);	
	uv /= (u_sdf_volume_radius * 2.0);
	uv += 0.5;
	
	return sample_sdf(uv);
}

vec3 sample_sdf_3d(vec3 uv)
{
	uv.x *= float(-1.0);
	uv.z *= float(-1.0);
	uv /= (u_sdf_volume_radius * 2.0);
	uv += 0.5;
	
	vec3 tex_size = vec3(float(u_sdf_resolution)) * 1.0;
	vec3 inv_tex_size = 1.0 / tex_size;
	
	vec3 x0y0z0 = sample_sdf(uv + vec3(0.0, 0.0, 0.0) * tex_size);
	vec3 x0y0z1 = sample_sdf(uv + vec3(0.0, 0.0, 1.0) * tex_size);
	vec3 x0y1z0 = sample_sdf(uv + vec3(0.0, 1.0, 0.0) * tex_size);
	vec3 x0y1z1 = sample_sdf(uv + vec3(0.0, 1.0, 1.0) * tex_size);
	vec3 x1y0z0 = sample_sdf(uv + vec3(1.0, 0.0, 0.0) * tex_size);
	vec3 x1y0z1 = sample_sdf(uv + vec3(1.0, 0.0, 1.0) * tex_size);
	vec3 x1y1z0 = sample_sdf(uv + vec3(1.0, 1.0, 0.0) * tex_size);
	vec3 x1y1z1 = sample_sdf(uv + vec3(1.0, 1.0, 1.0) * tex_size);

	vec3 f = fract(uv * tex_size);

	vec3 z1 = mix(x0y0z0, x0y0z1, f.z);
	vec3 z2 = mix(x0y1z0, x0y1z1, f.z);
	vec3 z3 = mix(x1y0z0, x1y0z1, f.z);
	vec3 z4 = mix(x1y1z0, x1y1z1, f.z);

	vec3 y1 = mix(z1, z2, f.y);
	vec3 y2 = mix(z3, z4, f.y);
	
	return mix(y1, y2, f.x);
}

bool ray_hit(vec3 pos, out float dist)
{
	dist = sample_sdf_1d(pos).r;
	dist = dist * 2.0 - 1.0;
	dist *= u_sdf_dist_mod;
	return dist <= 0.0;
}

void fragment()
{
	vec3 ray_dir = normalize(u_vertex - u_cam_pos);
	
	int max_steps = 128;
	vec3 ray_start = u_vertex;
	vec3 ray_end;
	vec3 ray = ray_start;
	int steps = 0;
	for (int i = 0; i < max_steps; i++)
	{
		float dist;
		if (ray_hit(ray, dist))
		{
			steps = max_steps;
			break;
		}
		ray += max(0.025, dist) * ray_dir;
		float bounds = u_sdf_volume_radius;
		if (ray.x > bounds || ray.y > bounds || ray.z > bounds 
			|| ray.x < -bounds || ray.y < -bounds || ray.z < -bounds)
		{
			ray_end = ray;
			break;
		}
		steps++;
	}
	float diff = float(steps) / float(max_steps);
	ALBEDO = vec3(diff);
}