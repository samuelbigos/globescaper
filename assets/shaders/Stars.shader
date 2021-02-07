shader_type spatial;
render_mode unshaded;

uniform vec3 u_camera_pos;
uniform vec4 u_nebula_high;
uniform vec4 u_nebula_low;

varying vec3 WORLD_PIXEL;

void vertex() {
	WORLD_PIXEL = VERTEX;
}

vec3 lin_to_srgb(vec3 color) {
    vec3 x = color.rgb * 12.92;
    vec3 y = 1.055 * pow(clamp(color.rgb, 0., 1.),vec3(0.4166667)) - 0.055;
    vec3 clr = color.rgb;
    clr.r = (color.r < 0.0031308) ? x.r : y.r;
    clr.g = (color.g < 0.0031308) ? x.g : y.g;
    clr.b = (color.b < 0.0031308) ? x.b : y.b;
	return vec3(clr);
}

// https://gist.github.com/patriciogonzalezvivo/670c22f3966e662d2f83
float mod289(float x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 mod289_4(vec4 x){return x - floor(x * (1.0 / 289.0)) * 289.0;}
vec4 perm(vec4 x){return mod289_4(((x * 34.0) + 1.0) * x);}

float snoise_3d(vec3 p){
    vec3 a = floor(p);
    vec3 d = p - a;
    d = d * d * (3.0 - 2.0 * d);

    vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
    vec4 k1 = perm(b.xyxy);
    vec4 k2 = perm(k1.xyxy + b.zzww);

    vec4 c = k2 + a.zzzz;
    vec4 k3 = perm(c);
    vec4 k4 = perm(c + 1.0);

    vec4 o1 = fract(k3 * (1.0 / 41.0));
    vec4 o2 = fract(k4 * (1.0 / 41.0));

    vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
    vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

    return o4.y * d.y + o4.x * (1.0 - d.y);
}

float fbm_3d(vec3 input, float period, int octaves, float persistence, float lacunarity) {
	input.x /= period;
	input.y /= period;
	input.z /= period;
	float amp = 1.0;
	float fmax = 1.0;
	float sum = snoise_3d(input);
	int i = 0;
	while (++i < octaves) 
	{
		input.x *= lacunarity;
		input.y *= lacunarity;
		input.z *= lacunarity;
		amp *= persistence;
		fmax += amp;
		sum += snoise_3d(input) * amp;
	}
	return sum / fmax;
}

float nebula_raymarch(vec3 origin, vec3 dir, out float density) {
	float period = 3.0;
	int octaves = 3;
	float persistence = 0.75f;
	float t = 0.0f;
	float t_delta = 0.1f;
	int steps = 8;
	for (int i = 0; i < steps; i++) {
		vec3 sample = origin + dir * t;
		density += fbm_3d(sample, period, octaves, persistence, 5.0);
		t += (1.0f / float(steps)) * 5.0;
	}
	density /= float(steps);
	return t;
}

void fragment() {
	// stars
	float period = 0.01;
	int octaves = 3;
	float persistence = 1.0f;
	float kernel_size = 0.0005;	
	float stars = 0.0;
	for (int x = -1; x < 2; x++) {
		for (int y = -1; y < 2; y++) {
			for (int z = -1; z < 2; z++) {
				vec3 pos = WORLD_PIXEL;
				pos += vec3(float(x) * kernel_size, float(y) * kernel_size, float(z) * kernel_size);
				float noise = fbm_3d(pos, period, octaves, persistence, 2.0);
				noise = pow(noise, 50);
				stars += noise;
			}
		}
	}
	stars /= 27.0;
	stars = 1.0 - pow(1.0 - stars, 100);
	
	// nebula
	float nebula;
	nebula_raymarch(WORLD_PIXEL, normalize(WORLD_PIXEL), nebula);
	nebula = pow(nebula, 5);
	vec3 nebula_col = mix(u_nebula_low.rgb, u_nebula_high.rgb, nebula) * nebula;
	
	ALBEDO = vec3(stars) + nebula_col;
}