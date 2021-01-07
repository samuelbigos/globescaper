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

float sample_sdf(vec3 world_pos)
{	
	// restore the proper axis directions.
	world_pos.x *= float(-1.0);
	world_pos.z *= float(-1.0);
	
	world_pos /= (u_sdf_volume_radius * 2.0);
	world_pos += 0.499;
	
	int z = int(world_pos.z * float(u_sdf_resolution));

	int col = z % u_cols;
	int row = z / u_cols;
	
	float y_scale = float(u_rows * u_sdf_resolution) / float(textureSize(u_sdf, 0).y);
	
	float x = (float(col) / float(u_cols)) + world_pos.x / float(u_cols);
	float y = (float(row) / float(u_rows)) + world_pos.y / float(u_rows);
	
	return texture(u_sdf, vec2(x, y)).r;
}

void fragment()
{
	vec3 ray_dir = normalize(u_vertex - u_cam_pos);
	
	int max_steps = 48;
	vec3 ray_start = u_vertex;
	vec3 ray_end;
	vec3 ray = ray_start;
	int steps = 0;
	for (int i = 0; i < max_steps; i++)
	{
		float dist = max(0.01, sample_sdf(ray)) * u_sdf_dist_mod;
		ray += dist * ray_dir;
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