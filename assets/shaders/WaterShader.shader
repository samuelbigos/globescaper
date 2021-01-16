shader_type spatial;
render_mode unshaded;

uniform vec4 u_deep_colour = vec4(1.0);
uniform vec4 u_shallow_colour = vec4(1.0);
uniform vec3 u_camera_pos = vec3(0.0);
uniform sampler3D u_3d_noise;
uniform vec3 u_sun_pos;

uniform sampler2D u_sdf;
uniform int u_sdf_resolution;
uniform float u_sdf_volume_radius;
uniform float u_sdf_dist_mod;
uniform int u_rows;
uniform int u_cols;
uniform bool u_sdf_quintic_filter;

varying vec3 WORLD_PIXEL;
varying vec3 WORLD_NORMAL;

void vertex() {
	WORLD_PIXEL = VERTEX;
	WORLD_NORMAL = normalize(NORMAL);
}

vec4 _permute_4_s4_n0ise(vec4 x) {
	return ((x * 34.0) + 1.0) * x - floor(((x * 34.0) + 1.0) * x * (1.0 / 289.0)) * 289.0;
}

float _permute_s4_n0ise(float x) {
	return ((x * 34.0) + 1.0) * x - floor(((x * 34.0) + 1.0) * x * (1.0 / 289.0)) * 289.0;
}

vec4 _grad4_s4_n0ise(float j, vec4 ip) {
	vec4 ones = vec4(1.0, 1.0, 1.0, -1.0);
	vec4 p, s;
	p.xyz = floor( fract (vec3(j) * ip.xyz) * 7.0) * ip.z - 1.0;
	p.w = 1.5 - dot(abs(p.xyz), ones.xyz);
	s = vec4(lessThan(p, vec4(0.0)));
	p.xyz = p.xyz + (s.xyz*2.0 - 1.0) * s.www; 
	return p;
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
	if (length(ray) >= u_sdf_volume_radius)
	{
		return true;
	}
	return false;
}

float shadow_calc(vec3 origin, vec3 dir, float k) {
	float dist;
	ray_hit(origin, dist);
	dir = normalize(dir);
	float res = 1.0;
	float t = dist + 0.1;
	vec3 ray = origin + dir * t;
	for (int i = 0; i < 128; i++)
	{
		if (ray_hit(ray, dist))
		{
			return 0.0;
		}
		if (outofbounds(ray))
		{
			break;
		}
		res = min(res, k * dist / t);
		t += dist;
		ray = origin + dir * t;
	}
	return res;
}

float ao_calc(vec3 target) {
	float dist;
	ray_hit(target, dist);
	return dist;
}

float simplex_4d_noise(vec4 v) {
	vec4 C = vec4( 0.138196601125011,
				0.276393202250021,
				0.414589803375032,
				-0.447213595499958);
	
	vec4 i  = floor(v + dot(v, vec4(0.309016994374947451)) );
	vec4 x0 = v -   i + dot(i, C.xxxx);
	
	vec4 i0;
	vec3 isX = step( x0.yzw, x0.xxx );
	vec3 isYZ = step( x0.zww, x0.yyz );
	i0.x = isX.x + isX.y + isX.z;
	i0.yzw = 1.0 - isX;
	i0.y += isYZ.x + isYZ.y;
	i0.zw += 1.0 - isYZ.xy;
	i0.z += isYZ.z;
	i0.w += 1.0 - isYZ.z;
	
	vec4 i3 = clamp( i0, 0.0, 1.0 );
	vec4 i2 = clamp( i0-1.0, 0.0, 1.0 );
	vec4 i1 = clamp( i0-2.0, 0.0, 1.0 );
	
	vec4 x1 = x0 - i1 + C.xxxx;
	vec4 x2 = x0 - i2 + C.yyyy;
	vec4 x3 = x0 - i3 + C.zzzz;
	vec4 x4 = x0 + C.wwww;
	
	i = i - floor(i * (1.0 / 289.0)) * 289.0;
	float j0 = _permute_s4_n0ise( _permute_s4_n0ise( _permute_s4_n0ise( _permute_s4_n0ise(i.w) + i.z) + i.y) + i.x);
	vec4 j1 = _permute_4_s4_n0ise( _permute_4_s4_n0ise( _permute_4_s4_n0ise( _permute_4_s4_n0ise (
				i.w + vec4(i1.w, i2.w, i3.w, 1.0 ))
				+ i.z + vec4(i1.z, i2.z, i3.z, 1.0 ))
				+ i.y + vec4(i1.y, i2.y, i3.y, 1.0 ))
				+ i.x + vec4(i1.x, i2.x, i3.x, 1.0 ));
	
	vec4 ip = vec4(1.0/294.0, 1.0/49.0, 1.0/7.0, 0.0) ;
	
	vec4 p0 = _grad4_s4_n0ise(j0,   ip);
	vec4 p1 = _grad4_s4_n0ise(j1.x, ip);
	vec4 p2 = _grad4_s4_n0ise(j1.y, ip);
	vec4 p3 = _grad4_s4_n0ise(j1.z, ip);
	vec4 p4 = _grad4_s4_n0ise(j1.w, ip);
	
	vec4 norm = 2.79284291400159 - 1.85373472095314 * vec4(dot(p0,p0), dot(p1,p1), dot(p2, p2), dot(p3,p3));
	p0 *= norm.x;
	p1 *= norm.y;
	p2 *= norm.z;
	p3 *= norm.w;
	p4 *= 2.79284291400159 - 1.85373472095314 * dot(p4,p4);
	
	vec3 m0 = max(0.6 - vec3(dot(x0,x0), dot(x1,x1), dot(x2,x2)), vec3(0.0));
	vec2 m1 = max(0.6 - vec2(dot(x3,x3), dot(x4,x4)), vec2(0.0));
	m0 = m0 * m0;
	m1 = m1 * m1;
	return 33.0 *(dot(m0*m0, vec3(dot(p0, x0), dot(p1, x1), dot(p2, x2)))
				+ dot(m1*m1, vec2(dot(p3, x3), dot(p4, x4))));
}

float get_noise_4d(vec4 input, float period, int octaves) {
	float lacunarity = 2.0;
	float persistence = 0.5;
	
	input.x /= period;
	input.y /= period;
	input.z /= period;
	input.w /= period;

	float amp = 1.0;
	float fmax = 1.0;
	float sum = simplex_4d_noise(input);

	int i = 0;
	while (++i < octaves) 
	{
		input.x *= lacunarity;
		input.y *= lacunarity;
		input.z *= lacunarity;
		input.w *= lacunarity;
		amp *= persistence;
		fmax += amp;
		sum += simplex_4d_noise(input) * amp;
	}
	return sum / fmax;
}

float sdf_render(vec3 ro, vec3 rd) {
	int max_steps = 128;
	vec3 ray = ro;
	int steps = 0;
	for (int i = 0; i < max_steps; i++)
	{
		float dist;
		if (ray_hit(ray, dist))
		{
			steps = max_steps;
			break;
		}
		ray += dist * rd;
		if (outofbounds(ray))
			break;
			
		steps++;
	}
	float diff = float(steps) / float(max_steps);
	return diff;
}

void fragment() {
	// get the water colour by modulating between shallow and deep colour based on depth
	vec3 water_col = vec3(0.0);
	float depth_difference = 0.0;
	{
		float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
		vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
		vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
		view.xyz /= view.w;
		float linear_depth = -view.z;
		
		depth_difference = linear_depth - (FRAGCOORD.z / FRAGCOORD.w);
		float max_depth = 0.5;
		depth_difference = 1.0 - min(1.0, max(0.0, depth_difference / max_depth));
		depth_difference = pow(depth_difference, 1.0);
		
		water_col = u_deep_colour.rgb + (u_shallow_colour.rgb - u_deep_colour.rgb) * depth_difference;
	}
	
	// get the incidence angle of the camera and water
	float incidence = 0.0;
	{
		vec3 normal = NORMAL;
		incidence = min(1.0, max(0.0, dot(normalize(VERTEX), -normal)));
		incidence = pow(1.0 - incidence, 3.0);
	}
	
	// water colour modulated by depth and incidence
	water_col = water_col + (u_shallow_colour.rgb - water_col) * incidence;
	
	// add waves to the water
	{
		float wh_noise = get_noise_4d(vec4(WORLD_PIXEL, (TIME) * 0.05), 0.8, 3);
		float wh_a = 0.0;
		float wh_b = 0.05;
		float wave_high = step(wh_a, wh_noise) * step(wh_noise, wh_b) * 0.1;
		
		float wl_noise = get_noise_4d(vec4(WORLD_PIXEL, (TIME + 99.0) * 0.05), 0.8, 3);
		float wl_a = 0.0;
		float wl_b = 0.05;
		float wave_low = 1.0 - step(wl_a, wl_noise) * step(wl_noise, wl_b) * 0.25;
		
		float shore_noise = get_noise_4d(vec4(WORLD_PIXEL * vec3(1.0, 0.5, 1.0), (TIME + 999.0) * 0.025), 0.1, 2);
		shore_noise *= 0.25;
		float shore_step = ((1.0 - depth_difference) - 0.5) * 0.5;
		float wave_shore = step(shore_step, shore_noise) * depth_difference;
		
		water_col += + wave_high; // add high waves
		water_col *= max(wave_high, (wave_low) + 0.5); // add low waves
		water_col += wave_shore;
	}
	
	// LIGHTING	
	// calculate shadow
	vec3 ray_origin = WORLD_PIXEL + WORLD_NORMAL * 0.1;
	vec3 ray_dir = normalize(u_sun_pos - WORLD_PIXEL);
	vec3 oy = normalize(WORLD_PIXEL - dFdy(WORLD_PIXEL)) * 0.02;
	vec3 ox = normalize(WORLD_PIXEL - dFdx(WORLD_PIXEL)) * 0.02;
	float s = 0.0;
	for (int x = -1; x < 2; x++)
		for (int y = -1; y < 2; y++)
			s += shadow_calc(ray_origin + oy * float(y) + ox * float(x), ray_dir, 1.0);
	s /= 1.0;
	
	// ao
	float ao = 0.0;
	for (int x = -1; x < 2; x++)
	{
		for (int y = -1; y < 2; y++)
		{
			for (int z = -1; z < 2; z++)
			{
				float dist = 0.1;
				vec3 target = ray_origin; + WORLD_NORMAL * dist * 10.0;
				target += normalize(vec3(float(x), 0.0, 0.0)) * dist;
				target += normalize(vec3(0.0, float(y), 0.0)) * dist;
				target += normalize(vec3(0.0, 0.0, float(z))) * dist;
				ao += ao_calc(target);
			}
		}
	}
	ao /= 27.0;
	ao = pow(ao, 5.0);
	
	// reflection
	vec3 cam_ray = normalize(WORLD_PIXEL - u_camera_pos);
	vec3 reflection_ray = normalize(reflect(cam_ray, WORLD_NORMAL));
	float wave_noise_x = get_noise_4d(vec4(WORLD_PIXEL, (TIME) * 0.1), 0.2, 3);
	float wave_noise_y = get_noise_4d(vec4(WORLD_PIXEL, (TIME) * 0.1), 0.2, 3);
	vec3 perturb = vec3(wave_noise_x, wave_noise_y, 0.0);
	reflection_ray = normalize((WORLD_PIXEL + reflection_ray + perturb * 0.25) - WORLD_PIXEL);
	float r = sdf_render(WORLD_PIXEL, reflection_ray);
	r *= 0.5;
	
	// specular
	float spec = clamp(dot(normalize(reflection_ray), normalize(u_sun_pos - WORLD_PIXEL)), 0.0, 1.0);
	spec = pow(spec, 200.0) * 20.0;
	spec = mix(spec, 0.0, 1.0 - s);
		
	// combine terms
	vec3 col = water_col.rgb;
	float brightness = 1.0; // global sun brightness
		
	ALBEDO = col; // start with colour
	ALBEDO *= brightness;
	ALBEDO *= ao; // ao term
	ALBEDO *= clamp(s + 0.1, 0.0, 1.0); // shadow + ambient term
	ALBEDO *= (1.0 - r); // reflection term
	ALBEDO *= (1.0 + spec); // specular term
}