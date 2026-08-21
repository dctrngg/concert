shader_type canvas_item;

uniform vec2 texture_size = vec2(128.0, 256.0); // 4 frames * 32, 8 rows * 32 per outfit
uniform float anim_speed = 10.0;

// Stage Beat Sync & Climax Wave Uniforms
uniform float climax_weight : hint_range(0.0, 1.0) = 0.0;
uniform float beat_time = 0.0;

varying flat vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
	// QuadMesh uses Y-up (3D convention) but Godot 2D canvas uses Y-down.
	// Flipping UV.y here corrects the upside-down rendering.
	UV.y = 1.0 - UV.y;

	// Hiệu ứng Làn Sóng Đám Đông (Crowd Wave / Mexican Wave) lan tỏa giơ tay & nảy người
	float wave_factor = COLOR.g;
	if (wave_factor > 0.001) {
		float wave_jump = -sin(wave_factor * 3.14159265) * 9.0;
		VERTEX.y += wave_jump;
	}

	// Nhún nhảy cao trào mượt mà (Dễ chịu, không bị rung giật)
	if (climax_weight > 0.02) {
		float time_offset = v_custom.w;
		float jump_offset = -abs(sin((beat_time * 3.5) + time_offset * 4.0)) * 2.2 * climax_weight;
		VERTEX.y += jump_offset;
	}
}

void fragment() {
	// INSTANCE_CUSTOM.x = outfit_id (0, 1, 2, ...)
	// INSTANCE_CUSTOM.y = is_walking (0.0 or 1.0)
	// INSTANCE_CUSTOM.z = direction (0.0 = Down, 1.0 = Right, 2.0 = Left, 3.0 = Up)
	// INSTANCE_CUSTOM.w = time_offset (to desynchronize animation)
	
	float outfit_id = max(0.0, v_custom.x);
	float is_walking = v_custom.y;
	float direction = clamp(v_custom.z, 0.0, 3.0);
	float time_offset = v_custom.w;
	
	// Determine speed based on movement status (walk vs idle)
	float speed = (is_walking > 0.5) ? anim_speed : 6.0;
	
	// Safe non-negative frame calculation across all renderers
	int frame = int(abs(mod((TIME + time_offset) * speed, 4.0)));
	
	// Row index in the 8-row native dynamic atlas:
	float row = (outfit_id * 8.0) + (is_walking * 4.0) + direction;
	
	// Scale UV to 32x32 frame and offset to correct position (safeguard div by zero)
	vec2 safe_tex_size = max(texture_size, vec2(1.0, 1.0));
	vec2 uv_scale = vec2(32.0) / safe_tex_size;
	vec2 uv_offset = vec2(float(frame) * 32.0, row * 32.0) / safe_tex_size;
	
	vec2 final_uv = clamp(UV, vec2(0.0), vec2(1.0)) * uv_scale + uv_offset;
	COLOR = texture(TEXTURE, final_uv);
}
