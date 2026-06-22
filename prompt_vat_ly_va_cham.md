# Prompt: Hệ thống vật lý & va chạm Player – NPC (Godot 4)

## Bối cảnh hiện tại

Dự án đang có:
- **Player** (`CharacterBody2D`) — có script di chuyển, nhưng **chưa có `CollisionShape2D`** trong scene.
- **NPC tương tác / promoted** (`npc_interactive.tscn`) — `CharacterBody2D` với `CircleShape2D` radius=8, layer 2, mask 3. Đã có collision body, đứng yên sau khi promote.
- **NPC nền** (`MultiMeshInstance2D`) — **không có physics node**, chỉ là dữ liệu vị trí trong packed array. Không thể dùng `move_and_slide` hay `CollisionShape2D`.

**Mục tiêu:** Player và NPC phải không đi xuyên qua nhau. Khi đi vào đám đông, cảm giác phải **giống ngoài đời thật** — chỉ khó đi, chậm lại — **không phải bị NPC bắn/đẩy bay** ra như bóng bi-a.

> ⚠️ **Lưu ý quan trọng:** Bản đầu tiên của hệ thống này dùng cơ chế "push" (player đẩy NPC bay ra bằng lực, NPC tự dừng nhờ friction). Cơ chế đó đã bị **thay thế hoàn toàn** bằng cơ chế **"resistance / yield"** mô tả dưới đây, vì lực đẩy mạnh tạo cảm giác phi vật lý, không giống người thật nhường đường.

---

## Phân tích kỹ thuật

Vì NPC nền dùng `MultiMeshInstance2D` (render 1 draw call, không có Node riêng), **không thể gán physics body riêng cho từng NPC** mà không phá vỡ hiệu năng. Dùng **2 lớp vật lý khác nhau**, cả hai đều theo triết lý "resistance" (làm khó đi) thay vì "push" (đẩy bay):

### Lớp 1 — Player ↔ NPC promoted (Physics thật)
- Player và NPC promoted đều là `CharacterBody2D`.
- Godot `move_and_slide` tự xử lý collision giữa 2 CharacterBody2D theo collision layer/mask → đây là phần đảm bảo **không đi xuyên qua được**, không cần thêm lực gì cả.
- NPC promoted **không bị đẩy bay**. Nó chỉ "nhường" rất nhẹ (vài pixel, có giới hạn, chậm) theo hướng bị ép vào, rồi tự về vị trí gốc — giống người thật hơi nghiêng người tránh.
- Phần "khó đi" nằm ở **player**: khi đang ép vào 1 NPC, player tự giảm tốc độ di chuyển của chính mình ở frame kế tiếp.

### Lớp 2 — Player ↔ NPC nền (Resistance — không dùng physics node)
- Mỗi frame, `CrowdManager` quét các NPC nền trong bán kính `crowd_resistance_radius` quanh player, đồng thời **đếm số NPC đó** (mật độ đám đông cục bộ quanh player).
- NPC nền chỉ nhường rất nhẹ (`npc_yield_strength`, nhỏ hơn lực đẩy cũ rất nhiều) để không bị player đè lên, **không bắn ra xa**.
- Mật độ đếm được dùng để tính `get_crowd_slowdown()` — một hệ số tốc độ (0.45 – 1.0) mà `player.gd` nhân vào tốc độ di chuyển của chính nó mỗi frame. Đám đông dày → player tự đi chậm hơn, giống "lội" qua đám người.
- Không tạo Node mới, không dùng `move_and_slide` cho NPC nền — chỉ cộng vector nhỏ vào `positions[i]` mỗi frame.
- NPC nền cũng có thể tự tách nhau (optional, chỉ khi khoảng cách < `npc_separation_radius`).

---

## Chi tiết triển khai

### 1. Thêm CollisionShape2D cho Player (`Player.tscn`)

Player hiện tại **không có CollisionShape2D** → cần thêm vào `.tscn`:
- Node: `CollisionShape2D` con của `Player`
- Shape: `CapsuleShape2D` (height=20, radius=6) hoặc `CircleShape2D` (radius=7)
- Position: `Vector2(0, 8)` (dời xuống một chút để khớp chân nhân vật)
- `collision_layer = 1` (Player layer)
- `collision_mask = 2` (va chạm với NPC layer)

Đây là phần duy nhất đảm bảo "không đi xuyên qua" ở mức vật lý cứng (đối với NPC promoted) — collision này tự nó chặn xuyên qua, không cần lực đẩy nào thêm.

### 2. NPC promoted — nhường nhẹ khi player ép vào (`npc_interactive.gd`)

Thay vì `push_velocity` + `move_and_slide()`, NPC chỉ lệch nhẹ theo offset có giới hạn rồi tự về vị trí gốc:

```gdscript
@export var yield_max_offset: float = 6.0   # NPC chỉ nhường tối đa 6px
@export var yield_speed: float = 40.0        # tốc độ nhường / trả lại RẤT chậm

var base_position: Vector2 = Vector2.ZERO    # set lại mỗi lần promote, trong setup()
var _yield_offset: Vector2 = Vector2.ZERO
var _being_pressed: bool = false
var _press_dir: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
	if _being_pressed:
		_yield_offset = (_yield_offset + _press_dir * yield_speed * delta).limit_length(yield_max_offset)
	else:
		_yield_offset = _yield_offset.move_toward(Vector2.ZERO, yield_speed * delta)

	position = base_position + _yield_offset
	_being_pressed = false  # player gọi lại receive_press() mỗi frame nếu vẫn còn ép vào

## Gọi bởi player.gd mỗi frame khi player đang va vào NPC này
func receive_press(direction: Vector2) -> void:
	_being_pressed = true
	_press_dir = direction
```

> NPC không tự gọi `move_and_slide()` nữa — vị trí được set trực tiếp qua `position`, collision shape vẫn cập nhật theo, nên player vẫn không đi xuyên qua được.

Player phát hiện va chạm và chỉ **báo hướng** cho NPC (không truyền lực), đồng thời **tự giảm tốc chính mình**:

```gdscript
# Trong player.gd, sau move_and_slide():
for i in get_slide_collision_count():
	var col := get_slide_collision(i)
	var collider := col.get_collider()
	if collider != null and collider.is_in_group("npc_interactive"):
		if collider.has_method("receive_press"):
			collider.receive_press(-col.get_normal())
		_next_frame_contact_mult = min(_next_frame_contact_mult, contact_slowdown_factor)
```

`contact_slowdown_factor` (export, ví dụ `0.4`) là tốc độ còn lại của player khi đang ép vào 1 NPC — áp dụng ở **frame kế tiếp** vì slide collision của frame hiện tại chỉ biết được sau khi `move_and_slide()` đã chạy.

### 3. NPC nền — Resistance trong CrowdManager (`crowd_manager.gd`)

Hàm `_apply_separations(player_local_pos)` được gọi trong `_process`, giờ chỉ nhường nhẹ + đo mật độ thay vì đẩy mạnh:

```gdscript
@export var crowd_resistance_radius: float = 45.0   # bán kính tính mật độ quanh player
@export var npc_yield_strength: float = 18.0         # NPC chỉ nhường nhẹ, KHÔNG bắn bay
@export var slowdown_per_npc: float = 0.08            # mỗi NPC trong bán kính làm player chậm thêm
@export var min_speed_multiplier: float = 0.45        # tốc độ tối thiểu khi đám đông dày nhất
@export var npc_separation_radius: float = 20.0       # khoảng cách tối thiểu giữa các NPC
@export var npc_separation_strength: float = 50.0
@export var enable_npc_separation: bool = false        # tắt mặc định (tốn CPU với 500 NPC)

var _last_crowd_density: int = 0

func _apply_separations(player_local_pos: Vector2) -> void:
	var dt := get_process_delta_time()
	var density := 0

	for i in range(npc_count):
		if is_promoted[i] == 1:
			continue
		var diff: Vector2 = positions[i] - player_local_pos
		var dist: float = diff.length()
		if dist < crowd_resistance_radius and dist > 0.5:
			density += 1
			var nudge: float = (1.0 - dist / crowd_resistance_radius) * npc_yield_strength
			positions[i] += diff.normalized() * nudge * dt
			positions[i].x = clamp(positions[i].x, wander_area.position.x, wander_area.position.x + wander_area.size.x)
			positions[i].y = clamp(positions[i].y, wander_area.position.y, wander_area.position.y + wander_area.size.y)

	_last_crowd_density = density

	if not enable_npc_separation:
		return
	for i in range(npc_count):
		if is_promoted[i] == 1:
			continue
		for j in range(i + 1, npc_count):
			if is_promoted[j] == 1:
				continue
			var diff: Vector2 = positions[i] - positions[j]
			var dist: float = diff.length()
			if dist < npc_separation_radius and dist > 0.5:
				var push: Vector2 = diff.normalized() * (npc_separation_radius - dist) * 0.5 * npc_separation_strength * dt
				positions[i] += push
				positions[j] -= push

## Gọi bởi player.gd mỗi frame để biết phải đi chậm bao nhiêu
func get_crowd_slowdown() -> float:
	return clamp(1.0 - float(_last_crowd_density) * slowdown_per_npc, min_speed_multiplier, 1.0)
```

Player áp `get_crowd_slowdown()` vào tốc độ di chuyển của chính nó **trước khi** gọi `move_and_slide()`:

```gdscript
# player.gd
var crowd_mult := 1.0
if crowd_manager and crowd_manager.has_method("get_crowd_slowdown"):
	crowd_mult = crowd_manager.get_crowd_slowdown()

velocity = input_vector * speed * crowd_mult * contact_mult
move_and_slide()
```

> ⚠️ **Lưu ý hiệu năng:** NPC↔NPC separation O(n²) với 500 NPC = 125,000 phép tính/frame → nên **tắt mặc định** hoặc chỉ check NPC trong camera viewport. Nếu muốn bật, giảm `npc_count` xuống ≤ 200. Việc đếm `density` để tính slowdown tái dùng đúng loop này, không tốn thêm chi phí.

---

## Collision Layers (quy hoạch)

| Layer | Tên | Dùng cho |
|---|---|---|
| 1 | `player` | Player body |
| 2 | `npc` | NPC promoted body |
| 3 | `world` | Tường, vật cản môi trường (tương lai) |

**Mask:**
- Player mask = `2` (va chạm với NPC)
- NPC promoted mask = `1` (va chạm với Player)

---

## Output mong đợi

- `Player.tscn` — thêm `CollisionShape2D` phù hợp với sprite 16×32 (scale ×3).
- `Scripts/player.gd` — thêm tham chiếu `crowd_manager` (sibling `../CrowdManager`), nhân `get_crowd_slowdown()` vào tốc độ; sau `move_and_slide()`, loop `get_slide_collision_count()` để gọi `receive_press()` trên NPC + set `_next_frame_contact_mult` (KHÔNG còn `push_strength`/`receive_push`).
- `Scripts/npc_interactive.gd` — thêm `_physics_process` dùng `_yield_offset`/`receive_press()` để nhường nhẹ (KHÔNG còn `push_velocity`/`PUSH_FRICTION`/`move_and_slide()` trên NPC).
- `Scripts/crowd_manager.gd` — `_apply_separations()` đổi từ đẩy mạnh (`push_radius`/`push_strength`) sang nhường nhẹ + đo mật độ (`crowd_resistance_radius`/`npc_yield_strength`), thêm `get_crowd_slowdown()`.

---

## Tiêu chí hoàn thành

- Player **không đi xuyên** qua NPC promoted (nhờ `CollisionShape2D` + `move_and_slide`, không phải nhờ lực đẩy).
- Khi player đi vào đám đông NPC nền, NPC chỉ **nhường rất nhẹ** (vài pixel) để không đè lên player — **không bị bắn ra xa**.
- Cảm giác "khó đi qua đám đông" đến từ việc **player tự chậm lại** (`get_crowd_slowdown()` + `contact_slowdown_factor`), không phải vật lý đẩy NPC.
- NPC promoted khi bị player ép vào chỉ lệch nhẹ rồi tự về vị trí gốc (`yield_max_offset`, `yield_speed`), không có hiện tượng "bắn rồi dừng lại do friction" như bản cũ.
- FPS vẫn ổn định với 500 NPC nền (resistance + đo mật độ chỉ chạy trên `positions[]`, không tạo Node, tái dùng cùng 1 loop).
- Dễ tune qua các `@export`: `crowd_resistance_radius`, `npc_yield_strength`, `slowdown_per_npc`, `min_speed_multiplier`, `yield_max_offset`, `yield_speed`, `contact_slowdown_factor`, `npc_separation_radius`, `enable_npc_separation`.
