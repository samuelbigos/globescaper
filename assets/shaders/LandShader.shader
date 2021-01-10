shader_type spatial;
render_mode unshaded;

uniform sampler2D u_texture;
uniform vec3 u_sun_pos;

uniform sampler2D u_sdf;
uniform int u_sdf_resolution;
uniform float u_sdf_volume_radius;
uniform float u_sdf_dist_mod;
uniform int u_rows;
uniform int u_cols;

varying vec3 v_vertex;
varying vec3 v_normal;

void vertex()
{
	v_vertex = VERTEX;
	v_normal = NORMAL;
}

vec4 lin_to_srgb(vec4 color)
{
    vec3 x = color.rgb * 12.92;
    vec3 y = 1.055 * pow(clamp(color.rgb, 0., 1.),vec3(0.4166667)) - 0.055;
    vec3 clr = color.rgb;
    clr.r = (color.r < 0.0031308) ? x.r : y.r;
    clr.g = (color.g < 0.0031308) ? x.g : y.g;
    clr.b = (color.b < 0.0031308) ? x.b : y.b;
	return vec4(clr, color.a);
}

vec3 sample_sdf(vec3 world_pos)
{	
	int z = int(world_pos.z * float(u_sdf_resolution));

	int col = z % u_cols;
	int row = z / u_cols;
	
	float y_scale = float(u_rows * u_sdf_resolution) / float(textureSize(u_sdf, 0).y);
	
	float x = (float(col) / float(u_cols)) + world_pos.x / float(u_cols);
	float y = (float(row) / float(u_rows)) + world_pos.y / float(u_rows);
	
	return texture(u_sdf, vec2(x, y)).rgb;
}

vec3 sample_sdf_3d(vec3 uv)
{
	uv.x *= float(-1.0);
	uv.z *= float(-1.0);
	uv /= (u_sdf_volume_radius * 2.0);
	uv += 0.5;
	
	vec3 tex_size = vec3(float(u_sdf_resolution)) * 1.0;
	vec3 inv_tex_size = 1.0 / tex_size;
	
	vec3 x0y0z0 = sample_sdf(uv + vec3(0.0, 0.0, 0.0) * inv_tex_size);
	vec3 x0y0z1 = sample_sdf(uv + vec3(0.0, 0.0, 1.0) * inv_tex_size);
	vec3 x0y1z0 = sample_sdf(uv + vec3(0.0, 1.0, 0.0) * inv_tex_size);
	vec3 x0y1z1 = sample_sdf(uv + vec3(0.0, 1.0, 1.0) * inv_tex_size);
	vec3 x1y0z0 = sample_sdf(uv + vec3(1.0, 0.0, 0.0) * inv_tex_size);
	vec3 x1y0z1 = sample_sdf(uv + vec3(1.0, 0.0, 1.0) * inv_tex_size);
	vec3 x1y1z0 = sample_sdf(uv + vec3(1.0, 1.0, 0.0) * inv_tex_size);
	vec3 x1y1z1 = sample_sdf(uv + vec3(1.0, 1.0, 1.0) * inv_tex_size);

	vec3 f = fract(uv * tex_size);

	vec3 z1 = mix(x0y0z0, x0y0z1, f.z);
	vec3 z2 = mix(x0y1z0, x0y1z1, f.z);
	vec3 z3 = mix(x1y0z0, x1y0z1, f.z);
	vec3 z4 = mix(x1y1z0, x1y1z1, f.z);

	vec3 y1 = mix(z1, z2, f.y);
	vec3 y2 = mix(z3, z4, f.y);
	
	return mix(y1, y2, f.x);
}

vec3 sample_sdf_1d(vec3 uv)
{
	uv.x *= float(-1.0);
	uv.z *= float(-1.0);	
	uv /= (u_sdf_volume_radius * 2.0);
	uv += 0.5;	
	return sample_sdf(uv);
}

bool ray_hit(vec3 pos, out float dist)
{
	dist = sample_sdf_1d(pos).r;
	dist = dist * 2.0 - 1.0;
	dist *= u_sdf_dist_mod;
	return dist <= 0.01;
}

float shadow(vec3 origin, vec3 dir, float k)
{
	// hacky hacks
	//vec3 SDF_SHADOW_OFFSET_BIAS = vec3(0.0, 0.01, 0.06); // 256
	vec3 SDF_SHADOW_OFFSET_BIAS = vec3(0.0, 0.0, -0.42); // 384
	origin += SDF_SHADOW_OFFSET_BIAS;
	//origin.z *= 1.003; // 256
	origin.z *= 1.0; // 256
	
	dir = normalize(dir);
	float res = 1.0;
	float ph = 1e20;
	float t = 0.05;
	vec3 ray = origin + dir * t;
	float acc = 0.0;
	for (int i = 0; i < 128; i++)
	{
		float dist;
		if (ray_hit(ray, dist))
		{
			return 0.0;
		}
		float bounds = u_sdf_volume_radius;
		if (ray.x > bounds || ray.y > bounds || ray.z > bounds 
			|| ray.x < -bounds || ray.y < -bounds || ray.z < -bounds)
		{
			break;
		}
		float y = dist * dist / (2.0 * ph);
		float d = sqrt(dist * dist - y * y);
		res = min(res, k * dist / max(0.0, t - y));
		ph = dist;
		t += dist;
		ray = origin + dir * t;
	}
	return res;
}

void fragment()
{
	vec3 ray_origin = v_vertex + normalize(v_normal) * 0.05;
	vec3 ray_dir = normalize(u_sun_pos - v_vertex);
	//ray_dir = normalize(v_vertex);
	
	vec3 oy = normalize(v_vertex - dFdy(v_vertex)) * 0.05;
	vec3 ox = normalize(v_vertex - dFdx(v_vertex)) * 0.05;
	
	// calculate shadow
	float s = 0.0;
	for (int x = 0; x < 3; x++)
		for (int y = 0; y < 3; y++)
			s += shadow(ray_origin + oy * float(y) + ox * float(x), ray_dir, 1.0);
	s /= 9.0;
	float ambient = 0.0;
	
	ALBEDO = lin_to_srgb(vec4(texture(u_texture, UV).rgb * (s + ambient), 1.0)).rgb;
}