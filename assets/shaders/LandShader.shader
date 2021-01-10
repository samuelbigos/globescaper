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
uniform bool u_sdf_quintic_filter;

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

bool outofbounds(vec3 ray)
{
	float bounds = u_sdf_volume_radius;
	if (ray.x > bounds || ray.y > bounds || ray.z > bounds 
		|| ray.x < -bounds || ray.y < -bounds || ray.z < -bounds)
	{
		return true;
	}
	return false;
}

float shadow_calc(vec3 origin, vec3 dir, float k)
{	
	dir = normalize(dir);
	float res = 1.0;
	float ph = 1e20;
	float t = 0.1;
	vec3 ray = origin + dir * t;
	for (int i = 0; i < 128; i++)
	{
		float dist;
		if (ray_hit(ray, dist))
		{
			return 0.0;
		}
		if (outofbounds(ray))
		{
			break;
		}
		float y = dist * dist / (2.0 * ph);
		float d = sqrt(dist * dist - y * y);
		res = min(k * res, dist / max(0.0, t - y));
		ph = dist;
		t += dist;
		ray = origin + dir * t;
	}
	return res;
}

float ao_calc(vec3 target)
{
	float dist;
	ray_hit(target, dist);
	return dist;
}

bool raymarch(vec3 ro, vec3 rd, out vec3 hit)
{
	float t = 0.0;
	for (int i = 0; i < 64; i++)
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
		t += dist;
	}
	return false;
}

float gi_calc(vec3 pix, vec3 n)
{
	n = normalize(n);
	int nz = 3;
	int nx = 6;
	int ny = 6;
	vec3 oy = normalize(v_vertex - dFdy(v_vertex));
	vec3 ox = normalize(v_vertex - dFdx(v_vertex));
	
	vec3 ray_origin = pix;
	float gi = 0.0;
	for (int z = 0; z < nz; z++)
	{
		for (int x = 0; x < nx; x++)
		{
			for (int y = 0; y < ny; y++)
			{
				vec3 dir = vec3(0.0);
				dir += n * float(z) * 5.0; // z
				dir += ox * (float(x) - float(nx) * 0.5 + 0.5); // x
				dir += oy * (float(y) - float(ny) * 0.5 + 0.5); // y
				dir = normalize(dir);
				
				vec3 hit;
				if (raymarch(ray_origin, dir, hit))
				{
					vec3 sun_dir = normalize(u_sun_pos - v_vertex);
					float sun_bias = 0.1;
					float shadow = clamp(shadow_calc(hit + sun_dir * sun_bias, sun_dir, 1.0), 0.0, 1.0);
					gi += 0.1;
				}
			}
		}
	}	
	return gi / float(nz + nx + ny);
}

void fragment()
{
	// LIGHTING
	vec3 dpdx = dFdx(v_vertex);
	vec3 dpdy = dFdy(v_vertex);	
	vec3 norm = -normalize(cross(dpdy, dpdx));
	
	vec3 ray_origin = v_vertex + norm * 0.1;
	vec3 ray_dir = normalize(u_sun_pos - v_vertex);
	//ray_dir = normalize(v_vertex);
	
	vec3 oy = normalize(v_vertex - dFdy(v_vertex)) * 0.02;
	vec3 ox = normalize(v_vertex - dFdx(v_vertex)) * 0.02;
	
	// calculate shadow
	float s = 0.0;
	for (int x = -1; x < 2; x++)
		for (int y = -1; y < 2; y++)
			s += shadow_calc(ray_origin + oy * float(y) + ox * float(x), ray_dir, 1.0);
	s /= 9.0;
	
	// ao
	float ao = 0.0;
	for (int x = -2; x < 3; x++)
	{
		for (int y = -2; y < 3; y++)
		{
			for (int z = -2; z < 3; z++)
			{
				float dist = 0.1;
				vec3 target = ray_origin; + normalize(norm) * dist * 20.0;
				target += normalize(vec3(float(x), 0.0, 0.0)) * dist;
				target += normalize(vec3(0.0, float(y), 0.0)) * dist;
				target += normalize(vec3(0.0, 0.0, float(z))) * dist;
				ao += ao_calc(target);
			}
		}
	}
	ao /= 125.0;
	ao = pow(ao, 5.0) * 10.0;
	
	// global illumination
	//float gi = gi_calc(ray_origin, norm);
	
	vec3 col = texture(u_texture, UV).rgb;
	//col = vec3(1.0, 1.0, 1.0);
		
	ALBEDO = vec4(col * ao * (s + 0.005) * 8.0, 1.0).rgb;
	//ALBEDO = lin_to_srgb(vec4(texture(u_texture, UV).rgb * ao * s * 5.0, 1.0)).rgb;
}