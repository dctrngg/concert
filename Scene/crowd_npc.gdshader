shader_type canvas_item;

uniform vec2 texture_size = vec2(128.0, 192.0); // 4 frames * 32, 6 rows * 32
uniform float anim_speed = 10.0;

varying flat float v_flip_h;
varying flat vec4 v_custom;

void vertex() {
	v_flip_h = COLOR.r;
	v_custom = INSTANCE_CUSTOM;
	// QuadMesh uses Y-up (3D convention) but Godot 2D canvas uses Y-down.
	// Flipping UV.y here corrects the upside-down rendering.
	UV.y = 1.0 - UV.y;
}

void fragment() {
	// INSTANCE_CUSTOM.x = outfit_id (0, 1, 2, ...)
	// INSTANCE_CUSTOM.y = is_walking (0.0 or 1.0)
	// INSTANCE_CUSTOM.z = direction (0.0 = Down, 1.0 = Right, 2.0 = Up)
	// INSTANCE_CUSTOM.w = time_offset (to desynchronize animation)
	
	float outfit_id = v_custom.x;
	float is_walking = v_custom.y;
	float direction = v_custom.z;
	float time_offset = v_custom.w;
	
	// Determine speed based on movement status (walk vs idle)
	float speed = (is_walking > 0.5) ? anim_speed : 6.0;
	
	// There are 4 frames per animation row
	int frame = int((TIME + time_offset) * speed) % 4;
	
	// Row index in the dynamic atlas
	// Layout:
	// Row 0: Idle Down, Row 1: Idle Right, Row 2: Idle Up
	// Row 3: Walk Down, Row 4: Walk Right, Row 5: Walk Up
	// Height of one outfit is 6 rows.
	float row = (outfit_id * 6.0) + (is_walking * 3.0) + direction;
	
	// Flip horizontally if v_flip_h > 0.5
	vec2 frame_uv = UV;
	if (v_flip_h > 0.5) {
		frame_uv.x = 1.0 - frame_uv.x;
	}
	
	// Scale UV to 32x32 frame and offset to correct position
	vec2 uv_scale = vec2(32.0) / texture_size;
	vec2 uv_offset = vec2(float(frame) * 32.0, row * 32.0) / texture_size;
	
	vec2 final_uv = frame_uv * uv_scale + uv_offset;
	
	COLOR = texture(TEXTURE, final_uv);
}
