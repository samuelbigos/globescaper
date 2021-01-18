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
uniform float u_atmosphere_radius = 14.0;
uniform float u_planet_radius;
uniform int u_atmosphere_samples = 5;
uniform int u_light_samples = 5;
uniform float u_sun_intensity = 1.0;
uniform float u_scattering_coeff = 1.0;
uniform float u_scale_height = 1.0;
uniform float u_ray_scale_height = 1.0;

varying vec3 WORLD_PIXEL;

void vertex() {
	WORLD_PIXEL = VERTEX;
}

bool atmosphere_intersect(vec3 origin, vec3 ray, float radius, vec3 centre, out float a, out float b) {
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

float sample(vec3 point, float sample_dist) {
	return 1.0;
}

bool light_sample(vec3 point, vec3 sun_dir, out float optical_depth) {
	float _;
	float c;
	atmosphere_intersect(point, sun_dir, u_atmosphere_radius, u_planet_centre, _, c);
	
	// sample on the segment pc
	float time = 0.0;
	float ds = distance(point, point + sun_dir * c) / float(u_light_samples);
	for (int i = 0; i < u_light_samples; i++) {
		vec3 q = point + sun_dir * (time + ds * 0.5);
		float height = distance(u_planet_centre, q) - u_planet_radius;
		if (height < 0.0) {
			return false;
		}
		
		optical_depth += exp(-height / u_ray_scale_height) * ds;
		time += ds;
	}	
	return true;
}

void fragment() {
	vec3 ray = normalize(WORLD_PIXEL - u_camera_pos);
	vec3 centre = u_planet_centre;
	float radius = u_atmosphere_radius;
	vec3 origin = WORLD_PIXEL;
	
	float aA; // atmosphere entry
	float aB; // atmosphere exit (or planet surface)
	if (atmosphere_intersect(origin, ray, radius, centre, aA, aB)) {
		// check if ray hits planet
		// TODO: replace with SDF?
		float pA, pB;
		if (atmosphere_intersect(origin, ray, u_planet_radius, centre, pA, pB))
			aB = pA;
			
		float optical_depth_pa = 0.0;
		float samples = 0.0;
		float time = aA;
		float ds = (aB - aA) / float(u_atmosphere_samples);
		for (int i = 0; i < u_atmosphere_samples; i++) {
			vec3 p = origin + ray * (time + ds * 0.5);
			
			float height = length(centre - p) - u_planet_radius;
			float optical_depth_segment = exp(-height / u_scale_height) * ds;
			optical_depth_pa += optical_depth_segment;
			
			float optical_depth_cp = 0.0;
			bool overground = light_sample(p, normalize(u_sun_pos - p), optical_depth_cp);
			if (overground) {
				float transmittance = exp(-u_scattering_coeff * (optical_depth_cp + optical_depth_pa));
				samples += transmittance * optical_depth_cp;
			}
			time += ds;
		}
		
		float phase = 1.0;
		float sun_i = u_sun_intensity * u_scattering_coeff * phase * samples;
		
		ALBEDO = vec3(sun_i);
	}
	else {
		ALBEDO = vec3(0.0);
	}
}