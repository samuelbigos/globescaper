shader_type spatial;
render_mode unshaded, blend_add;

uniform sampler2D u_sdf;
uniform int u_sdf_resolution;
uniform float u_sdf_volume_radius;
uniform float u_sdf_dist_mod;
uniform bool u_sdf_quintic_filter;
uniform int u_rows;
uniform int u_cols;

uniform vec3 u_camera_pos;
uniform vec3 u_sun_pos;
uniform vec3 u_planet_centre = vec3(0.0);
uniform float u_atmosphere_radius = 18.0;
uniform float u_planet_radius;
uniform int u_atmosphere_samples = 20;
uniform int u_optical_samples = 10;
uniform float u_sun_intensity = 0.1;
uniform float u_scattering_strength = 1.0;
uniform vec3 u_scattering_wavelengths = vec3(100.0);
uniform float u_density_falloff = 1.0;
uniform float u_volumetric_shadow_scale = 10.0;

varying vec3 WORLD_PIXEL;
varying vec3 SDF_TEX_SIZE;
varying vec3 INV_SDF_TEX_SIZE;

void vertex() {
	WORLD_PIXEL = VERTEX;
	SDF_TEX_SIZE = vec3(float(u_sdf_resolution));
	INV_SDF_TEX_SIZE = 1.0 / SDF_TEX_SIZE;
}

vec3 inner_sample_sdf(vec3 world_pos) {	
	int z = int(world_pos.z * float(u_sdf_resolution));
	int col = z % u_cols;
	int row = z / u_cols;
	float y_scale = float(u_rows * u_sdf_resolution) / float(textureSize(u_sdf, 0).y);
	float x = (float(col) / float(u_cols)) + world_pos.x / float(u_cols);
	float y = (float(row) / float(u_rows)) + world_pos.y / float(u_rows);
	return texture(u_sdf, vec2(x, y)).rgb;
}

vec3 sample_sdf_trilinear(vec3 uv) {
	vec3 pixel = uv * SDF_TEX_SIZE + vec3(0.5, 0.5, 0.0);
	vec3 f = fract(pixel);
	// Quintic filtering
	// https://www.iquilezles.org/www/articles/texture/texture.htm
	f = f*f*f*(f*(f*6.0-15.0)+10.0);
	pixel = floor(pixel) / SDF_TEX_SIZE - vec3(INV_SDF_TEX_SIZE / 2.0);	
	vec3 x0y0z0 = inner_sample_sdf(pixel + vec3(0.0, 0.0, 0.0) * INV_SDF_TEX_SIZE);
	vec3 x0y0z1 = inner_sample_sdf(pixel + vec3(0.0, 0.0, 1.0) * INV_SDF_TEX_SIZE);
	vec3 x0y1z0 = inner_sample_sdf(pixel + vec3(0.0, 1.0, 0.0) * INV_SDF_TEX_SIZE);
	vec3 x0y1z1 = inner_sample_sdf(pixel + vec3(0.0, 1.0, 1.0) * INV_SDF_TEX_SIZE);
	vec3 x1y0z0 = inner_sample_sdf(pixel + vec3(1.0, 0.0, 0.0) * INV_SDF_TEX_SIZE);
	vec3 x1y0z1 = inner_sample_sdf(pixel + vec3(1.0, 0.0, 1.0) * INV_SDF_TEX_SIZE);
	vec3 x1y1z0 = inner_sample_sdf(pixel + vec3(1.0, 1.0, 0.0) * INV_SDF_TEX_SIZE);
	vec3 x1y1z1 = inner_sample_sdf(pixel + vec3(1.0, 1.0, 1.0) * INV_SDF_TEX_SIZE);
	vec3 z1 = mix(x0y0z0, x0y0z1, f.z);
	vec3 z2 = mix(x0y1z0, x0y1z1, f.z);
	vec3 z3 = mix(x1y0z0, x1y0z1, f.z);
	vec3 z4 = mix(x1y1z0, x1y1z1, f.z);
	vec3 y1 = mix(z1, z2, f.y);
	vec3 y2 = mix(z3, z4, f.y);	
	return mix(y1, y2, f.x);
}

float sdf(vec3 uv) {
	uv.x *= float(-1.0);
	uv.z *= float(-1.0);
	uv /= (u_sdf_volume_radius * 2.0);
	uv += 0.5;
	return sample_sdf_trilinear(uv).r;
}

bool ray_hit(vec3 pos, out float dist) {
	dist = sdf(pos);
	dist = dist * 2.0 - 1.0;
	dist *= u_sdf_dist_mod;
	return dist <= 0.0001;
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

bool raymarch(vec3 ro, vec3 rd, out vec3 hit, out float res) {
	res = 1.0;
	float t = 0.1;
	for (int i = 0; i < 256; i++)
	{
		float dist;
		vec3 ray = ro + t * rd;
		if (ray_hit(ray, dist))
		{
			hit = ray;
			return true;
		}
		if (outofbounds(ray))
		{
			return false;
		}
		res = min(res, u_volumetric_shadow_scale * dist / t);
		t += dist;
	}
	return false;
}

bool intersect(vec3 origin, vec3 ray, float radius, vec3 centre, out float a, out float b) {
	float ot = dot(centre - origin, ray);
	vec3 vt = origin + ot * ray;	
	float ct2 = pow(length(origin - centre), 2.0) - pow(length(vt - origin), 2.0);
	float r2 = pow(radius, 2.0);
	
	if (ct2 > r2)
		return false;
		
	float at = sqrt(r2 - ct2);
	a = ot - at;
	b = ot + at;
	return true;
}

float density_at_point(vec3 point) {
	float height_above_surface = distance(u_planet_centre, point) - u_planet_radius;
	float height = height_above_surface / (u_atmosphere_radius - u_planet_radius);
	float local_density = exp(-height * u_density_falloff) * (1.0 - height);
	return local_density;
}

float optical_depth(vec3 point, vec3 sun_dir, float ray_length) {
	float optical_depth = 0.0;

	// sample on the segment pc
	float step_size = ray_length / float(u_optical_samples);
	float dist = step_size * 0.5;
	
	for (int i = 0; i < u_optical_samples; i++) {
		vec3 sample_point = point + sun_dir * (dist + step_size * 0.5);
		optical_depth += density_at_point(sample_point) * step_size;
		dist += step_size;
	}
	return optical_depth;
}

bool hit_planet(vec3 origin, vec3 ray, float atmosphere_dist, out vec3 hit, out float res) {
	bool inside_sdf = false;
	vec3 raymarch_origin;
	if (u_atmosphere_radius > u_sdf_volume_radius) {
		float sdf_origin, _;
		// TODO: this isn't working properly when sdf < atmos
		if (intersect(origin, ray, u_sdf_volume_radius, u_planet_centre, sdf_origin, _)) {
			raymarch_origin = origin + ray * sdf_origin;
			inside_sdf = true;
		}	
	}
	else {
		raymarch_origin = origin + ray * atmosphere_dist;
		inside_sdf = true;
	}
	if (inside_sdf && raymarch(raymarch_origin, ray, hit, res)) {
		return true;
	}
	return false;
}

void fragment() {
	vec3 ray = normalize(WORLD_PIXEL - u_camera_pos);
	vec3 origin = WORLD_PIXEL;
	
	vec3 scatter_coeffs = vec3(0.0);
	scatter_coeffs.r = pow(400.0 / u_scattering_wavelengths.r, 4.0) * u_scattering_strength;
	scatter_coeffs.g = pow(400.0 / u_scattering_wavelengths.g, 4.0) * u_scattering_strength;
	scatter_coeffs.b = pow(400.0 / u_scattering_wavelengths.b, 4.0) * u_scattering_strength;
	
	float aA; // atmosphere entry
	float aB; // atmosphere exit (or planet surface)
	if (intersect(origin, ray, u_atmosphere_radius, u_planet_centre, aA, aB)) {
		// check if ray hits planet using sdf
		vec3 hit;
		float res;
		if (hit_planet(origin, ray, aA, hit, res)) {
			aB = distance(origin, hit);
		}
			
		float optical_depth_pa = 0.0;
		vec3 light = vec3(0.0);
		float step_size = (aB - aA) / float(u_atmosphere_samples);
		float dist = aA + step_size * 0.5;
		
		for (int i = 0; i < u_atmosphere_samples; i++) {
			vec3 in_scatter_point = origin + ray * dist;
			vec3 to_sun = normalize(u_sun_pos - in_scatter_point);
			
			if (hit_planet(in_scatter_point, to_sun, 0.0, hit, res)) {
				dist += step_size;
				continue;
			}
			
			float sun_ray_dist, _;
			intersect(in_scatter_point, to_sun, u_atmosphere_radius, u_planet_centre, _, sun_ray_dist);
			float sun_ray_optical_depth = optical_depth(in_scatter_point, to_sun, sun_ray_dist);
			float view_ray_optical_depth = optical_depth(in_scatter_point, -ray, dist);
			
			vec3 transmittance = exp(-scatter_coeffs * (sun_ray_optical_depth + view_ray_optical_depth));
			light += transmittance * density_at_point(in_scatter_point) * step_size * res;
			dist += step_size;
		}
		vec3 sun_i = light * u_sun_intensity * scatter_coeffs;
		ALBEDO = vec3(sun_i);
	}
	else {
		ALBEDO = vec3(0.0);
	}
}