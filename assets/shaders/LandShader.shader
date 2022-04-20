shader_type spatial;
//render_mode unshaded;

uniform sampler2D u_texture;
uniform vec3 u_sun_pos;
uniform vec3 u_camera_pos;

uniform sampler2D u_sdf;
uniform int u_sdf_resolution;
uniform float u_sdf_volume_radius;
uniform float u_sdf_dist_mod;
uniform int u_rows;
uniform int u_cols;
uniform bool u_sdf_quintic_filter;

varying vec3 WORLD_PIXEL;
varying vec3 WORLD_NORMAL;
varying vec3 SDF_TEX_SIZE;
varying vec3 INV_SDF_TEX_SIZE;

void vertex() {
	WORLD_PIXEL = VERTEX;
	WORLD_NORMAL = normalize(NORMAL);
	SDF_TEX_SIZE = vec3(float(u_sdf_resolution));
	INV_SDF_TEX_SIZE = 1.0 / SDF_TEX_SIZE;
}

vec4 lin_to_srgb(vec4 color) {
    vec3 x = color.rgb * 12.92;
    vec3 y = 1.055 * pow(clamp(color.rgb, 0., 1.),vec3(0.4166667)) - 0.055;
    vec3 clr = color.rgb;
    clr.r = (color.r < 0.0031308) ? x.r : y.r;
    clr.g = (color.g < 0.0031308) ? x.g : y.g;
    clr.b = (color.b < 0.0031308) ? x.b : y.b;
	return vec4(clr, color.a);
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

bool ray_hit(vec3 pos, out float dist) {
	dist = sdf(pos);
	dist = dist * 2.0 - 1.0;
	dist *= u_sdf_dist_mod;
	return dist <= 0.001;
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

float ao_calc(vec3 target) {
	float dist;
	ray_hit(target, dist);
	return clamp(dist, 0.0, 1.0);
}

bool raymarch(vec3 ro, vec3 rd, out vec3 hit) {
	float t = 0.0;
	for (int i = 0; i < 64; i++) {
		float dist;
		vec3 ray = ro + t * rd;
		if (ray_hit(ray, dist))	{
			hit = ray;
			return true;
		}
		if (outofbounds(ray)) {
			return false;
		}
		t += dist;
	}
	return false;
}

void fragment() {
	// calculate shadow
	vec3 ray_origin = WORLD_PIXEL + WORLD_NORMAL * 0.1;
	vec3 ray_dir = normalize(u_sun_pos - WORLD_PIXEL);	
	vec3 oy = normalize(WORLD_PIXEL - dFdy(WORLD_PIXEL)) * 0.05;
	vec3 ox = normalize(WORLD_PIXEL - dFdx(WORLD_PIXEL)) * 0.05;
	float s = 0.0;
	for (int x = 0; x < 2; x++) {
		for (int y = 0; y < 2; y++) {
			float fx = float(x) - 0.5;
			float fy = float(y) - 0.5;
			s += shadow_calc(ray_origin + oy * fy + ox * fx, ray_dir, 1.0);
		}
	}
	s /= 4.0;
	
	// ao
	float ao = ao_calc(WORLD_PIXEL + WORLD_NORMAL * 1.1);
	
	// specular
	vec3 cam_ray = normalize(WORLD_PIXEL - u_camera_pos);
	vec3 reflection_ray = normalize(reflect(cam_ray, WORLD_NORMAL));
	float diffuse_noise_x = get_noise_4d(vec4(WORLD_PIXEL, 0.0), 0.05, 1);
	float diffuse_noise_y = get_noise_4d(vec4(WORLD_PIXEL, 0.0), 0.05, 1);
	vec3 perturb = vec3(diffuse_noise_x, diffuse_noise_y, 0.0);
	reflection_ray = normalize((WORLD_PIXEL + reflection_ray + perturb * 0.25) - WORLD_PIXEL);
	float spec = clamp(dot(normalize(reflection_ray), normalize(u_sun_pos - WORLD_PIXEL)), 0.0, 1.0);
	spec = pow(spec, 3.0) * 0.5;
	spec = mix(spec, 0.0, 1.0 - s);
	
	// combine terms
	float ambient = clamp(dot(WORLD_NORMAL, ray_dir), 0.1, 1.0);
	vec3 col = texture(u_texture, UV).rgb;
	float brightness = 1.0;
		
	ALBEDO = col * ambient; // start with colour
	ALBEDO *= brightness; // global sun brightness
	ALBEDO *= ao; // ao term
	ALBEDO *= clamp(s, 0.025, 1.0); // shadow + ambient term
	ALBEDO *= (1.0 + spec); // specular term
}