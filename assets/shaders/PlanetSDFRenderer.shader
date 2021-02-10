shader_type spatial;
render_mode unshaded;

uniform sampler2D u_sdf;
uniform int u_sdf_resolution;
uniform float u_sdf_volume_radius;
uniform float u_sdf_dist_mod;
uniform int u_rows;
uniform int u_cols;
uniform vec3 u_cam_pos;

uniform vec3 u_sun_pos;

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
	float sdf = sample_sdf_trilinear(uv);
	sdf = sdf * 2.0 - 1.0;
	sdf *= u_sdf_dist_mod;
	return clamp(sdf, 0.0, 1.0);
}

vec3 calc_normal(vec3 p) {
    float h = 0.1;
    vec2 k = vec2(1,-1);
    return normalize( k.xyy*sdf(p + k.xyy*h) + 
                      k.yyx*sdf(p + k.yyx*h) + 
                      k.yxy*sdf(p + k.yxy*h) + 
                      k.xxx*sdf(p + k.xxx*h));
}

bool outofbounds(vec3 ray) {
	return length(ray) > u_sdf_volume_radius;
}

bool ray_hit(vec3 pos, out float dist) {
	dist = sdf(pos);
	return dist <= 0.0;
}

bool raymarch(vec3 ro, vec3 rd, out float dist, out vec3 hit_pos) {
	float res = 1.0;
	int max_steps = 256;
	float t = 0.0;
	for (int i = 0; i < max_steps; i++)
	{
		vec3 sample = ro + rd * t;
		if (outofbounds(sample) && i > 0) {
			return false;
		}
		if (ray_hit(sample, dist)) {
			hit_pos = sample;
			return true;
		}
		res = min(res, dist / t);
		t += max(dist, 0.0025);
	}
	return false;
}

float ao_calc(vec3 target) {
	float dist;
	ray_hit(target, dist);
	return clamp(dist, 0.0, 1.0);
}

float shadow_calc(vec3 origin, vec3 dir, float k) {
	float dist;
	dir = normalize(dir);
	float res = 1.0;
	float t = 0.1;
	vec3 ray = origin + dir * t;
	for (int i = 0; i < 128; i++) {
		if (ray_hit(ray, dist)) {
			return 0.0;
		}
		if (outofbounds(ray)) {
			break;
		}
		res = min(res, k * dist / min(t, 1.0));
		t += max(0.01, dist);
		ray = origin + dir * t;
	}
	return res;
}

void fragment() {
	vec3 rd = normalize(u_vertex - u_cam_pos);
	float dist;
	vec3 hit_pos;
	bool hit = raymarch(u_vertex, rd, dist, hit_pos);
	
	if (hit) {
		vec3 normal = calc_normal(hit_pos);
		
		// ao
		float ao = ao_calc(hit_pos + normal * 1.1);
		
		// shadow
		vec3 ray_origin = hit_pos + normal * 0.1;
		vec3 ray_dir = normalize(u_sun_pos - hit_pos);	
		vec3 oy = normalize(hit_pos - dFdy(hit_pos)) * 0.05;
		vec3 ox = normalize(hit_pos - dFdx(hit_pos)) * 0.05;
		float s = 0.0;
		for (int x = 0; x < 2; x++) {
			for (int y = 0; y < 2; y++) {
				float fx = float(x) - 0.5;
				float fy = float(y) - 0.5;
				s += shadow_calc(ray_origin + oy * fy + ox * fx, ray_dir, 1.0);
			}
		}
		s /= 4.0;
	
		vec3 col = vec3(124.0/255.0, 161.0/255.0, 103.0/255.0);
		col *= ao;
		col *= s;
		ALBEDO = col;
		ALPHA = 1.0;
	}
	else {
		ALPHA = 0.0;
	}
}