shader_type spatial;
render_mode unshaded, world_vertex_coords, blend_add;

uniform vec3 u_camera_pos;
uniform vec3 u_orbit_centre;
uniform float u_orbit_radius; 
uniform float u_width = 0.25f;
uniform float u_softness = 10.0f;

varying vec3 WORLD_PIXEL;

void vertex() {
	WORLD_PIXEL = VERTEX;
}

// https://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdTorus( vec3 p, vec2 t ) {
	vec2 q = vec2(length(p.xz)-t.x,p.y);
	return length(q)-t.y;
}

float sdSphere(vec3 p, float r) {
	return length(p) - r;
}

bool outofbounds(vec3 ray) {
	float bounds = 150.0f;
	if (ray.x > bounds || ray.y > bounds || ray.z > bounds 
		|| ray.x < -bounds || ray.y < -bounds || ray.z < -bounds)
	{
		return true;
	}
	return false;
}

bool raymarch(vec3 ro, vec3 rd, out float res) {
	float t = 0.0f;
	res = 999.0f;
	int max_steps = 64;
	for (int i = 0; i < max_steps; i++) {
		vec3 sample = ro + rd * t;
		float dist = sdTorus(sample - u_orbit_centre, vec2(u_orbit_radius, u_width));
		res = min(res, dist);
		if (dist <= 0.0f) {
			return true;
		}
		t += max(0.1f, dist);
		if (t > 50.0f) {
			return false;
		}
	}
	return false;
}

void fragment() {
	float res = 1.0f;
	raymarch(WORLD_PIXEL, normalize(WORLD_PIXEL - u_camera_pos), res);
	res = clamp(res * u_softness, 0.0f, 1.0f);
	ALBEDO = vec3(1.0f - res);
	//ALBEDO = vec3(1.0f);
}