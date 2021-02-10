shader_type spatial;
render_mode unshaded, world_vertex_coords;

uniform sampler2D u_sdf;
uniform int u_sdf_resolution;
uniform float u_sdf_volume_radius;
uniform float u_sdf_dist_mod;
uniform int u_rows;
uniform int u_cols;
uniform vec3 u_cam_pos;

varying vec3 u_vertex;
varying vec3 SDF_TEX_SIZE;
varying vec3 INV_SDF_TEX_SIZE;

void vertex() {
	u_vertex = VERTEX;
	SDF_TEX_SIZE = vec3(float(u_sdf_resolution));
	INV_SDF_TEX_SIZE = 1.0 / SDF_TEX_SIZE;
}

float inner_sample_sdf(vec3 world_pos) {
	int z = int(world_pos.z * float(u_sdf_resolution));
	int col = z % u_cols;
	int row = z / u_cols;
	float y_scale = float(u_rows * u_sdf_resolution) / float(textureSize(u_sdf, 0).y);
	float x = (float(col) / float(u_cols)) + world_pos.x / float(u_cols);
	float y = (float(row) / float(u_rows)) + world_pos.y / float(u_rows);
	return texture(u_sdf, vec2(x, y)).r;
}

float sample_sdf_trilinear(vec3 uv) {
	vec3 pixel = uv;
	pixel.z = uv.z * SDF_TEX_SIZE.z;
	float f = fract(pixel.z);
	pixel.z = floor(pixel.z) / SDF_TEX_SIZE.z - float(INV_SDF_TEX_SIZE.z / 2.0);	
	float x0y0z0 = inner_sample_sdf(pixel + vec3(0.0, 0.0, 0.0) * INV_SDF_TEX_SIZE);
	float x0y0z1 = inner_sample_sdf(pixel + vec3(0.0, 0.0, 1.0) * INV_SDF_TEX_SIZE);
	return mix(x0y0z0, x0y0z1, f);
}

float sdf(vec3 uv) {
	uv.x *= float(-1.0);
	uv.z *= float(-1.0);
	uv /= (u_sdf_volume_radius * 2.0);
	uv += 0.5;
	return sample_sdf_trilinear(uv);
}

bool outofbounds(vec3 ray) {
	float bounds = u_sdf_volume_radius;
	if (ray.x > bounds || ray.y > bounds || ray.z > bounds 
		|| ray.x < -bounds || ray.y < -bounds || ray.z < -bounds)
	{
		return true;
	}
	return false;
}

bool ray_hit(vec3 pos, out float dist) {
	dist = sdf(pos);
	dist = dist * 2.0 - 1.0;
	dist *= u_sdf_dist_mod;
	return dist <= 0.001;
}

bool raymarch(vec3 ro, vec3 rd, out float dist) {
	float res = 1.0;
	int max_steps = 256;
	float t = 0.0f;
	for (int i = 0; i < max_steps; i++)
	{
		vec3 sample = ro + rd * t;
		if (outofbounds(sample) && i > 0) {
			return false;
		}
		if (ray_hit(sample, dist)) {
			return true;
		}
		res = min(res, dist / t);
		t = max(t + dist, 0.001f);
	}
	return false;
}

void fragment() {
	vec3 ray_dir = normalize(u_vertex - u_cam_pos);
	float dist;
	bool hit = raymarch(u_vertex, ray_dir, dist);
	if (hit) {
		ALBEDO = vec3(1.0);
		ALPHA = 1.0f;
	}
	else {
		ALBEDO = vec3(0.0);
		ALPHA = 0.0f;
	}
}