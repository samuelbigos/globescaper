shader_type spatial;
//render_mode unshaded;

varying mat4 CAMERA;
varying vec3 VERTEX_MODEL;

uniform vec4 u_deep_colour = vec4(1.0);
uniform vec4 u_shallow_colour = vec4(1.0);
uniform vec3 u_camera_pos = vec3(0.0);
uniform sampler3D u_3d_noise;

void vertex()
{
	VERTEX_MODEL = VERTEX;
}

vec4 _permute_4_s4_n0ise(vec4 x) 
{
	return ((x * 34.0) + 1.0) * x - floor(((x * 34.0) + 1.0) * x * (1.0 / 289.0)) * 289.0;
}

float _permute_s4_n0ise(float x) 
{
	return ((x * 34.0) + 1.0) * x - floor(((x * 34.0) + 1.0) * x * (1.0 / 289.0)) * 289.0;
}

vec4 _grad4_s4_n0ise(float j, vec4 ip) 
{
	vec4 ones = vec4(1.0, 1.0, 1.0, -1.0);
	vec4 p, s;
	p.xyz = floor( fract (vec3(j) * ip.xyz) * 7.0) * ip.z - 1.0;
	p.w = 1.5 - dot(abs(p.xyz), ones.xyz);
	s = vec4(lessThan(p, vec4(0.0)));
	p.xyz = p.xyz + (s.xyz*2.0 - 1.0) * s.www; 
	return p;
}

float simplex4dN0iseFunc(vec4 v) 
{
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

float get_noise_4d(vec4 input, float period, int octaves)
{
	float lacunarity = 2.0;
	float persistence = 0.5;
	
	input.x /= period;
	input.y /= period;
	input.z /= period;
	input.w /= period;

	float amp = 1.0;
	float fmax = 1.0;
	float sum = simplex4dN0iseFunc(input);

	int i = 0;
	while (++i < octaves) 
	{
		input.x *= lacunarity;
		input.y *= lacunarity;
		input.z *= lacunarity;
		input.w *= lacunarity;
		amp *= persistence;
		fmax += amp;
		sum += simplex4dN0iseFunc(input) * amp;
	}
	return sum / fmax;
}

void fragment()
{
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
		incidence = pow(1.0 - incidence, 7.0);
	}
	
	// water colour modulated by depth and incidence
	water_col = water_col + (u_shallow_colour.rgb - water_col) * incidence;
	
	// add waves to the water
	{
		float wh_noise = get_noise_4d(vec4(VERTEX_MODEL, (TIME) * 0.05), 0.8, 3);
		float wh_a = 0.0;
		float wh_b = 0.05;
		float wave_high = step(wh_a, wh_noise) * step(wh_noise, wh_b) * 0.1;
		
		float wl_noise = get_noise_4d(vec4(VERTEX_MODEL, (TIME + 99.0) * 0.05), 0.8, 3);
		float wl_a = 0.0;
		float wl_b = 0.05;
		float wave_low = 1.0 - step(wl_a, wl_noise) * step(wl_noise, wl_b) * 0.25;
		
		float shore_noise = get_noise_4d(vec4(VERTEX_MODEL * vec3(1.0, 0.5, 1.0), (TIME + 999.0) * 0.025), 0.1, 2);
		shore_noise *= 0.25;
		float shore_step = ((1.0 - depth_difference) - 0.5) * 0.5;
		float wave_shore = step(shore_step, shore_noise) * depth_difference;
		
		water_col += + wave_high; // add high waves
		water_col *= max(wave_high, (wave_low) + 0.5); // add low waves
		water_col += wave_shore;
	}
	
	ALBEDO = water_col;
}