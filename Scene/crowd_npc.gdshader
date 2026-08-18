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
	
	float outfit_id = v_custom.x;
	float is_walking = v_custom.y;
	float direction = v_custom.z;
	float time_offset = v_custom.w;
	
	// Determine speed based on movement status (walk vs idle)
	float speed = (is_walking > 0.5) ? anim_speed : 6.0;
	
	// There are 4 frames per animation row
	int frame = int((TIME + time_offset) * speed) % 4;
	
	// Row index in the 8-row native dynamic atlas:
	float row = (outfit_id * 8.0) + (is_walking * 4.0) + direction;
	
	// Scale UV to 32x32 frame and offset to correct position
	vec2 uv_scale = vec2(32.0) / texture_size;
	vec2 uv_offset = vec2(float(frame) * 32.0, row * 32.0) / texture_size;
	
	vec2 final_uv = UV * uv_scale + uv_offset;
	COLOR = texture(TEXTURE, final_uv);
}
