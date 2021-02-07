shader_type spatial;
render_mode unshaded, blend_add;

uniform vec3 u_camera_pos;
uniform vec3 u_sun_pos;
uniform vec3 u_planet_centre = vec3(0.0);
uniform float u_atmosphere_radius;
uniform float u_planet_radius;
uniform int u_atmosphere_samples = 20;
uniform int u_optical_samples = 10;
uniform float u_sun_intensity = 0.1;
uniform float u_scattering_strength = 1.0;
uniform vec3 u_scattering_wavelengths = vec3(100.0);
uniform float u_density_falloff = 1.0;
uniform float u_volumetric_shadow_scale = 10.0;
uniform bool u_volumetric_shadows = false;

uniform float u_phase_r = 16.0;
uniform float u_mie_scatter_coeff = 500.0;
uniform float u_mie_falloff = 1.0;
uniform float u_mie_g = 0.76;

varying vec3 WORLD_PIXEL;

const float PI = 3.14159265358979323846;

void vertex() {
	WORLD_PIXEL = VERTEX;
}

float sdf(vec3 pos) {
	return length(pos) - u_planet_radius;
}

bool ray_hit(vec3 pos, out float dist) {
	dist = sdf(pos);
	return dist <= 0.001;
}

bool outofbounds(vec3 ray) {
	if (length(ray) > 999.0)
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

float density_at_point(vec3 point, float falloff) {
	float height_above_surface = distance(u_planet_centre, point) - u_planet_radius;
	float height = height_above_surface / (u_atmosphere_radius - u_planet_radius);
	float local_density = exp(-height * falloff) * (1.0 - height);
	return local_density;
}

float optical_depth(vec3 point, vec3 sun_dir, float ray_length, float falloff) {
	float optical_depth = 0.0;

	// sample on the segment pc
	float step_size = ray_length / float(u_optical_samples);
	float dist = step_size * 0.5;
	
	for (int i = 0; i < u_optical_samples; i++) {
		vec3 sample_point = point + sun_dir * (dist + step_size * 0.5);
		optical_depth += density_at_point(sample_point, falloff) * step_size;
		dist += step_size;
	}
	return optical_depth;
}

bool hit_planet(vec3 origin, vec3 ray, float atmosphere_dist, out vec3 hit, out float res) {
	vec3 raymarch_origin = origin + ray * atmosphere_dist;
	if (raymarch(raymarch_origin, ray, hit, res)) {
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
	
	vec3 scatter_coeffs_m = vec3(0.0);
	scatter_coeffs_m.r = pow(400.0 / u_mie_scatter_coeff, 4.0) * u_scattering_strength;
	scatter_coeffs_m.g = pow(400.0 / u_mie_scatter_coeff, 4.0) * u_scattering_strength;
	scatter_coeffs_m.b = pow(400.0 / u_mie_scatter_coeff, 4.0) * u_scattering_strength;
	
	vec3 sun_dir = normalize(u_sun_pos - u_camera_pos);
	float mu = dot(ray, sun_dir); // mu in the paper which is the cosine of the angle between the sun direction and the ray direction 
	float phase_r = 3.0 / (u_phase_r * PI) * (1.0 + mu * mu);
	
	float g = u_mie_g; 
    float phase_m = 3.0 / (8.0 * PI) * ((1.0 - g * g) * (1.0 + mu * mu)) / ((2.0 + g * g) * pow(1.0 + g * g - 2.0 * g * mu, 1.50)); 
	
	float aA; // atmosphere entry
	float aB; // atmosphere exit (or planet surface)
	if (intersect(origin, ray, u_atmosphere_radius, u_planet_centre, aA, aB)) {
		// check if ray hits planet using sdf
		vec3 hit;
		float res = 1.0;
		if (hit_planet(origin, ray, aA, hit, res)) {
			aB = distance(origin, hit);
		}
			
		float optical_depth_pa = 0.0;
		vec3 light_r = vec3(0.0);
		vec3 light_m = vec3(0.0);
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
			float sun_ray_optical_depth_r = optical_depth(in_scatter_point, to_sun, sun_ray_dist, u_density_falloff);
			float sun_ray_optical_depth_m = optical_depth(in_scatter_point, to_sun, sun_ray_dist, u_mie_falloff);
			
			float view_ray_optical_depth_r = optical_depth(in_scatter_point, -ray, dist, u_density_falloff);
			float view_ray_optical_depth_m = optical_depth(in_scatter_point, -ray, dist, u_mie_falloff);
			
			vec3 tau = scatter_coeffs * (sun_ray_optical_depth_r + view_ray_optical_depth_r) + scatter_coeffs_m * 1.1 * (sun_ray_optical_depth_m + view_ray_optical_depth_m);
			vec3 transmittance = vec3(exp(-tau.x), exp(-tau.y), exp(-tau.z));
			light_r += transmittance * density_at_point(in_scatter_point, u_density_falloff) * step_size * res;
			light_m += transmittance * density_at_point(in_scatter_point, u_mie_falloff) * step_size * res;
			dist += step_size;
		}
		vec3 sun_i = (light_r * scatter_coeffs * phase_r + light_m * scatter_coeffs_m * phase_m) * u_sun_intensity;
		ALBEDO = vec3(sun_i);
	}
	else {
		ALBEDO = vec3(0.0);
	}
}