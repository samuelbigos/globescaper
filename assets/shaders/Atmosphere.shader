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
uniform float u_scattering_coeff = 1.0;
uniform float u_density_falloff = 1.0;

varying vec3 WORLD_PIXEL;

void vertex() {
	WORLD_PIXEL = VERTEX;
}

vec3 sample_sdf(vec3 world_pos) {	
	ivec2 texture_res_i = textureSize(u_sdf, 0);
	
	int z = int(world_pos.z * float(u_sdf_resolution));
	int col = z % u_cols;
	int row = z / u_cols;	
	float y_scale = float(u_rows * u_sdf_resolution) / float(texture_res_i.y);	
	float x = (float(col) / float(u_cols)) + world_pos.x / float(u_cols);
	float y = (float(row) / float(u_rows)) + world_pos.y / float(u_rows);
	
	if (u_sdf_quintic_filter)
	{
		// Quintic filtering
		// https://www.iquilezles.org/www/articles/texture/texture.htm
		vec2 texture_res = vec2(float(texture_res_i.x), float(texture_res_i.y));
		vec2 p = vec2(x, y);
		p = p * texture_res + 0.5;

	    vec2 i = floor(p);
	    vec2 f = p - i;
	    f = f*f*f*(f*(f*6.0-15.0)+10.0);
	    p = i + f;
	    p = (p - 0.5)/texture_res;
		
		return texture(u_sdf, p).rgb;
	}
	else
	{
		return texture(u_sdf, vec2(x, y)).rgb;
	}
}

vec3 sample_sdf_1d(vec3 uv) {
	uv.x *= float(-1.0);
	uv.z *= float(-1.0);	
	uv /= (u_sdf_volume_radius * 2.0);
	uv += 0.5;	
	return sample_sdf(uv);
}

bool ray_hit(vec3 pos, out float dist) {
	// hacky hacks
	//vec3 SDF_SHADOW_OFFSET_BIAS = vec3(0.0, 0.01, 0.06); // 256
	vec3 SDF_SHADOW_OFFSET_BIAS = vec3(0.0, 0.0, -0.42); // 384
	pos += SDF_SHADOW_OFFSET_BIAS;
	//origin.z *= 1.003; // 256
	pos.z *= 1.003; // 384
	
	dist = sample_sdf_1d(pos).r;
	dist = dist * 2.0 - 1.0;
	dist *= u_sdf_dist_mod;
	return dist <= 0.0;
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
		res = min(res, 1.0 * dist / t);
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
		float light = 0.0;		
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
			
			float transmittance = exp(-u_scattering_coeff * (sun_ray_optical_depth + view_ray_optical_depth));
			light += transmittance * density_at_point(in_scatter_point) * step_size;
			dist += step_size;
		}
		float sun_i = u_sun_intensity * light;
		ALBEDO = vec3(sun_i);
	}
	else {
		ALBEDO = vec3(0.0);
	}
}