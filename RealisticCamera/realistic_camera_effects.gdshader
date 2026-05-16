shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform vec2 resolution = vec2(1920, 1080);

group_uniforms Camera_Settings;
uniform float iso : hint_range(100, 25600, 100) = 400;
uniform float fstop : hint_range(1.0, 32.0, 0.1) = 2.8;
uniform float shutter_speed : hint_range(0.016667, 4.0, 0.0001) = 0.004;
uniform float set_ev : hint_range(-5.0, 5.0, 0.001) = 0.0;

group_uniforms Exposure;
uniform float base_ev = 17.621;

group_uniforms MotionBlur;
uniform bool motion_blur_enabled = false;
uniform vec2 blur_direction = vec2(0.0, 0.0);
uniform int samples : hint_range(4, 32) = 32;

group_uniforms Noise_Settings;
uniform float noise_intensity : hint_range(0, 1.0, 0.001) = 0.5;
uniform float max_noise : hint_range(0.1, 2.0, 0.001) = 1.0;

group_uniforms Red;
uniform float r_intensity : hint_range(0, 2.0, 0.001) = 1.0;
uniform float r_scale : hint_range(0.1, 0.6, 0.001) = 0.472;

group_uniforms Green;
uniform float g_intensity : hint_range(0, 2.0, 0.001) = 0.667;
uniform float g_scale : hint_range(0.1, 0.6, 0.001) = 0.6;

group_uniforms Blue;
uniform float b_intensity : hint_range(0, 2.0, 0.001) = 1.213;
uniform float b_scale : hint_range(0.1, 0.6, 0.001) = 0.41;

// hash22 random taken from https://www.shadertoy.com/view/lldyDn w/ a seed added
vec2 hash22(vec2 uv, float seed) {
	uv += seed;
	vec3 p3 = fract(vec3(uv.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy) * 2.0 - 1.0;
}

// perlin noise from https://godotshaders.com/snippet/2d-noise/
float noise(vec2 uv, float s) {
	vec2 uv_index = floor(uv);
	vec2 uv_fract = fract(uv);
	vec2 blur = smoothstep(0.0, 1.0, uv_fract);
	
	return mix(
		mix(dot(hash22(uv_index + vec2(0.0, 0.0), s), uv_fract - vec2(0.0, 0.0)),
			dot(hash22(uv_index + vec2(1.0, 0.0), s), uv_fract - vec2(1.0, 0.0)), blur.x),
		mix(dot(hash22(uv_index + vec2(0.0, 1.0), s), uv_fract - vec2(0.0, 1.0)),
			dot(hash22(uv_index + vec2(1.0, 1.0), s), uv_fract - vec2(1.0, 1.0)), blur.x),
		blur.y) + 0.5;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	
	// motion blur modified from https://godotshaders.com/shader/3d-camera-smooth-motion-blur/
	vec4 pixel_color;
	if (motion_blur_enabled) {
		vec4 color = vec4(0.0);
		float total_weight = 0.0;
		
		for (int i = 0; i < samples; i++) {
			float offset = float(i) / float(samples - 1) + 0.5;
			vec2 uv_offset = blur_direction * offset;
			color += texture(screen_texture, uv + uv_offset);
			total_weight += 1.0;
		}
		
		pixel_color = color / total_weight;
	} else {
		pixel_color = texture(screen_texture, uv);
	}
	
	// exposure calculation
	uv.y *= resolution.y / resolution.x;
	
	float light_gathering = (1.0 / (fstop * fstop)) * shutter_speed;
	float scene_ev = set_ev + base_ev + log2(light_gathering * iso / 100.0);
	float exposure_multiplier = pow(2.0, scene_ev - 12.0);
	
	pixel_color.rgb *= exposure_multiplier;
	
	// blobby noise using perlin func
	float photon_noise_factor = sqrt(1.0 / max(light_gathering, 0.0001));
	float read_noise_factor = sqrt(iso / 100.0);
	float noise_amplifier = photon_noise_factor * read_noise_factor;
	
	vec3 delta_color = vec3(
		(noise(uv * resolution.y * r_scale, 1.23 + TIME) - 0.5) * 2.0 * r_intensity,
		(noise(uv * resolution.y * g_scale, 4.32 + TIME) - 0.5) * 2.0 * g_intensity,
		(noise(uv * resolution.y * b_scale, 5.25 + TIME) - 0.5) * 2.0 * b_intensity
	) * noise_intensity * min(noise_amplifier * 0.01, max_noise);
	
	pixel_color.rgb += delta_color;
	COLOR = pixel_color;
}
