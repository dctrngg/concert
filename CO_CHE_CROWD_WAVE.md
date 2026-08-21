# ĐẶC TẢ KỸ THUẬT: HIỆU ỨNG "LÀN SÓNG ĐÁM ĐÔNG" (CROWD WAVE)
## Dự án: Concert Management Game (Godot 4)

*Tài liệu bổ sung cho PROJECT_SPECIFICATION.md — mô tả chi tiết thiết kế và triển khai kỹ thuật cho hiệu ứng Mexican Wave lan qua đám đông NPC (MultiMesh).*

---

## 1. TỔNG QUAN Ý TƯỞNG

Khi ban nhạc chơi tới đoạn cao trào (hoặc khi Hype Meter đạt mốc tối đa), toàn bộ đám đông (500-1000 NPC) thực hiện hiệu ứng "Mexican Wave" — giơ tay lên lần lượt theo thứ tự lan tỏa từ sân khấu ra ngoài, tạo khoảnh khắc thị giác ấn tượng ("wow moment") cho người chơi.

**Nguyên lý cốt lõi:** Wave là một hàm khoảng cách theo thời gian. Mỗi NPC "kích hoạt" tư thế giơ tay tại thời điểm:

```
t_activate(NPC) = wave_start_time + distance(NPC, wave_origin) / wave_speed
```

NPC càng gần `wave_origin` (thường là vị trí sân khấu) thì giơ tay càng sớm; NPC càng xa thì giơ tay càng muộn — tạo cảm giác sóng lan tỏa ra ngoài.

**Vì sao chi phí hiệu năng gần như bằng 0:**
Hệ thống `CrowdManager` đã có sẵn `INSTANCE_CUSTOM` (dùng cho `outfit_id`, `time_offset`) và vòng lặp update instance chạy mỗi frame cho toàn bộ NPC. Wave chỉ cần thêm 1 kênh dữ liệu (`wave_progress`) vào custom data đã có sẵn — không cần vòng lặp mới, không cần Node bổ sung.

---

## 2. THIẾT KẾ DỮ LIỆU

### 2.1. Biến trạng thái trong `crowd_manager.gd`

| Biến | Kiểu | Ý nghĩa |
|---|---|---|
| `wave_active` | `bool` | Wave đang diễn ra hay không |
| `wave_origin` | `Vector2` | Vị trí phát sóng (thường = vị trí sân khấu) |
| `wave_start_time` | `float` | Thời điểm bắt đầu (giây, `Time.get_ticks_msec()/1000.0`) |
| `wave_speed` | `float` | Tốc độ lan sóng (px/s), mặc định `400.0` |
| `wave_arm_duration` | `float` | Thời gian mỗi NPC giữ tay lên (giây), mặc định `0.6` |
| `wave_max_radius` | `float` | Bán kính tối đa cần lan tới (tính từ NPC xa nhất) |

### 2.2. Kênh dữ liệu MultiMesh Custom Data

`INSTANCE_CUSTOM` là `vec4` (r, g, b, a) đã dùng sẵn 2 kênh — bổ sung kênh thứ 3:

| Kênh | Dữ liệu hiện có/mới | Ghi chú |
|---|---|---|
| `.r` | `outfit_id` | Đã có |
| `.g` | `time_offset` | Đã có |
| `.b` | **`wave_progress`** (mới) | Giá trị âm = không có wave; `0 → wave_arm_duration` = đang giơ tay |
| `.a` | (dự phòng) | Có thể dùng cho tính năng tương lai |

---

## 3. TRIỂN KHAI PHÍA GDSCRIPT

### 3.1. Kích hoạt Wave

```gdscript
# crowd_manager.gd

# --- Crowd Wave state ---
var wave_active: bool = false
var wave_origin: Vector2 = Vector2.ZERO
var wave_start_time: float = 0.0
var wave_speed: float = 400.0        # px/s — tốc độ lan sóng
var wave_arm_duration: float = 0.6   # thời gian NPC giữ tay lên (giây)
var wave_max_radius: float = 2000.0  # bán kính tối đa sóng lan tới
var wave_cooldown_remaining: float = 0.0
const WAVE_COOLDOWN: float = 35.0    # giới hạn tần suất trigger (giây)

func trigger_crowd_wave(origin: Vector2, speed: float = 400.0) -> bool:
	if wave_active or wave_cooldown_remaining > 0.0:
		return false  # đang có wave hoặc còn cooldown -> bỏ qua

	wave_active = true
	wave_origin = origin
	wave_speed = speed
	wave_start_time = Time.get_ticks_msec() / 1000.0
	wave_max_radius = _get_max_distance_from(origin) + 200.0
	wave_cooldown_remaining = WAVE_COOLDOWN
	print("[CrowdManager] Crowd Wave triggered from ", origin)
	return true

func _get_max_distance_from(origin: Vector2) -> float:
	var max_dist := 0.0
	for pos in positions:
		max_dist = max(max_dist, origin.distance_to(pos))
	return max_dist
```

### 3.2. Cập nhật mỗi frame (gộp vào vòng lặp update instance sẵn có)

```gdscript
func _update_multimesh_instances(delta: float) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0
	var wave_elapsed := current_time - wave_start_time

	for i in range(positions.size()):
		var pos := positions[i]
		var custom := Color(0, 0, 0, 0)

		# --- Data hiện có ---
		custom.r = float(outfit_ids[i])
		custom.g = time_offsets[i]

		# --- Wave data ---
		if wave_active:
			var dist := wave_origin.distance_to(pos)
			custom.b = wave_elapsed - dist / wave_speed
		else:
			custom.b = -1.0

		# Gán vào đúng buffer (mm_back hoặc mm_front tùy Y-sort bucket hiện tại)
		var target_mm := mm_back if pos.y <= player.position.y else mm_front
		target_mm.set_instance_custom_data(_get_local_index(i, target_mm), custom)

	# Tự tắt wave khi đã lan hết bán kính + thời gian giơ tay
	if wave_active and wave_elapsed > (wave_max_radius / wave_speed + wave_arm_duration):
		wave_active = false
		print("[CrowdManager] Crowd Wave finished")

	# Giảm cooldown
	if wave_cooldown_remaining > 0.0:
		wave_cooldown_remaining -= delta
```

> **Lưu ý:** `_get_local_index()` là hàm ánh xạ index toàn cục sang index trong buffer `mm_back`/`mm_front` tương ứng — tái sử dụng logic Y-sort đã có ở mục 3.2 của đặc tả gốc.

### 3.3. Kích hoạt đồng bộ với sân khấu (`stage.gd`)

```gdscript
# stage.gd
signal crowd_hype_peak(stage_position: Vector2)

func _on_music_climax_reached() -> void:
	# Gọi khi phát hiện đoạn cao trào (BGM marker hoặc Hype Meter đạt max)
	emit_signal("crowd_hype_peak", global_position)
```

```gdscript
# world.gd hoặc game_manager.gd — nơi kết nối signal
func _ready() -> void:
	stage.crowd_hype_peak.connect(_on_crowd_hype_peak)

func _on_crowd_hype_peak(origin: Vector2) -> void:
	var triggered := crowd_manager.trigger_crowd_wave(origin, 400.0)
	if triggered:
		_play_wave_camera_effect()
		sound_manager.play_sfx("crowd_cheer_swell")
```

---

## 4. TRIỂN KHAI PHÍA SHADER (`crowd_npc.gdshader`)

```glsl
shader_type canvas_item;

// ... uniform hiện có (texture atlas, frame size, v.v) ...

uniform float wave_arm_duration : hint_range(0.1, 2.0) = 0.6;

varying float v_wave_factor;

void vertex() {
	// INSTANCE_CUSTOM.r = outfit_id, .g = time_offset, .b = wave_progress
	float wave_progress = INSTANCE_CUSTOM.b;

	// wave_factor: 0 = bình thường, 1 = đang giơ tay full
	float wave_factor = 0.0;
	if (wave_progress > 0.0 && wave_progress < wave_arm_duration) {
		// Dùng sin để tạo curve mượt: lên nhanh, giữ, xuống nhanh
		wave_factor = sin((wave_progress / wave_arm_duration) * PI);
	}

	v_wave_factor = wave_factor;
}

void fragment() {
	// Sample 2 frame: pose đi bộ bình thường + pose giơ tay
	vec2 uv_walk = get_walk_uv(...);       // logic UV hiện có
	vec2 uv_wave = get_wave_pose_uv(...);  // row mới trong atlas cho pose giơ tay

	vec4 color_walk = texture(TEXTURE, uv_walk);
	vec4 color_wave = texture(TEXTURE, uv_wave);

	// step() để chuyển frame cứng (giống pixel art), thay vì mix mờ
	COLOR = mix(color_walk, color_wave, step(0.5, v_wave_factor));
}
```

**Yêu cầu về asset:** cần bổ sung 1-2 frame "giơ tay" (arm-up pose) vào texture atlas hiện có cho mỗi `outfit_id`. Vì hệ thống atlas đã tổ chức theo outfit sẵn, chỉ cần mở rộng thêm 1 row trong atlas, không cần vẽ lại toàn bộ sprite sheet.

---

## 5. TÍNH NĂNG BỔ SUNG ĐỂ TĂNG "WOW FACTOR"

| Ý tưởng | Mô tả | Độ phức tạp |
|---|---|---|
| **Camera pull-back** | Zoom camera ra 10-15% trong 1-2s khi wave kích hoạt, giúp người chơi thấy toàn cảnh sóng lan thay vì chỉ vùng gần Player | Thấp — tween camera zoom có sẵn trong Godot |
| **Player tham gia wave** | Tự động trigger animation giơ tay cho chính Player khi wave đi qua vị trí của họ | Thấp — check `distance / wave_speed` tương tự NPC, áp cho `player.gd` |
| **SFX lan theo sóng** | Phát tiếng "hò reo" tăng dần theo vị trí wave đang đi qua, dùng `AudioStreamPlayer2D` đặt tạm tại vị trí wave hiện tại với volume falloff theo bán kính | Trung bình |
| **Giới hạn tần suất** | Cooldown 30-45s giữa các lần trigger để giữ giá trị "đặc biệt", tránh lạm dụng gây nhàm | Đã tích hợp ở mục 3.1 (`WAVE_COOLDOWN`) |

---

## 6. TÓM TẮT CHI PHÍ & RỦI RO

| Hạng mục | Đánh giá |
|---|---|
| Hiệu năng runtime | Gần như 0 — tái sử dụng vòng lặp update instance sẵn có, không thêm Node hay loop mới |
| Code mới (GDScript) | ~40-50 dòng |
| Code mới (Shader) | ~15 dòng GLSL |
| Asset mới | 1-2 frame pose "giơ tay" cho mỗi outfit trong atlas |
| Rủi ro kỹ thuật | Thấp — không đụng vào core logic promote/demote, physics, hay quest |
| Điểm cần lưu ý khi triển khai | `_get_local_index()` phải chính xác khớp với buffer `mm_back`/`mm_front` hiện tại của từng frame, nếu không wave sẽ áp sai lên NPC |

---

## 7. HƯỚNG PHÁT TRIỂN TIẾP THEO (Backlog)

- Thiết kế cụ thể layout UV atlas cho pose "giơ tay" theo từng outfit_id.
- Xây dựng logic detect "đoạn cao trào" (climax) trong BGM — có thể dùng marker thời gian đặt sẵn trong file nhạc, hoặc phân tích biên độ audio real-time.
- Cân nhắc thêm biến thể wave: "double wave" (2 sóng đối xứng từ 2 điểm) làm phần thưởng cho các màn chơi khó hơn ở cấp độ sau.

---
*Tài liệu đã được hoàn tất triển khai thành công vào mã nguồn dự án (Trạng thái: ✅ Đã hoàn thành 2026-08-19).*
