# Prompt: Hệ thống đám đông NPC cho game concert top-down 2D (Godot 4)

## Bối cảnh dự án
Đang xây dựng một game concert top-down 2D pixel art trong **Godot 4 (GDScript)**. Một đêm concert có rất nhiều NPC (khán giả) cùng xuất hiện trên màn hình. Phần lớn NPC chỉ là đám đông trang trí, một số ít có nhiệm vụ (quest) để người chơi tương tác.

**Asset hiện có:** Chỉ có **một model cơ thể pixel art duy nhất, chưa có trang phục/outfit nào khác**, kèm animation 4 hướng (3 hướng vẽ thật: down/up/right, hướng left dùng `flip_h` lật animation "right"). Bộ animation gồm: `idle_down, idle_up, idle_right, walk_down, walk_up, walk_right, run_down, run_up, run_right`.

**Quan trọng:** Vì asset outfit chưa có, hệ thống phải chạy đúng ngay với placeholder (1 outfit duy nhất = model gốc), nhưng kiến trúc phải sẵn sàng để cắm thêm nhiều outfit (texture atlas + outfit_id) vào sau **mà không cần sửa lại core logic**.

## Mục tiêu cần triển khai
Xây dựng 3 hệ thống con, hoạt động cùng nhau:
1. **CrowdManager** — render đám đông NPC nền, tối ưu (không phải Node riêng cho từng người).
2. **Hệ thống gán quest theo xác suất** — khi spawn NPC, random xem NPC đó có nhiệm vụ hay không.
3. **Logic Promote / Demote** — chỉ NPC nào gần người chơi VÀ có nhiệm vụ mới được "thăng cấp" thành Node tương tác thật.

---

## 1. CrowdManager — Render đám đông

- Dùng `MultiMeshInstance2D` để render toàn bộ NPC nền bằng **một draw call**, không dùng Node riêng (không CharacterBody2D, không AnimatedSprite2D) cho từng người trong đám đông.
- Lưu dữ liệu NPC dạng **array-of-struct** trong script quản lý (ví dụ dùng `PackedVector2Array`, `PackedInt32Array`, `PackedFloat32Array`), tối thiểu gồm:
  - `position: Vector2`
  - `velocity: Vector2` (cho wander behavior đơn giản)
  - `outfit_id: int` (hiện tại luôn = 0 vì chỉ có 1 outfit, nhưng phải có field này)
  - `has_quest: bool`
  - `is_promoted: bool`
  - `time_offset: float` (lệch nhịp animation để tránh trông "đồng bộ giả")
- Viết kèm **canvas_item shader** (`crowd_npc.gdshader`) dùng `INSTANCE_CUSTOM` để truyền `outfit_id` + `time_offset`/frame cho từng instance. Hiện tại chỉ 1 outfit nên shader có thể đơn giản, nhưng **phải có sẵn logic UV offset theo outfit_id** (kể cả khi outfit_count = 1) để sau này chỉ cần tăng `outfit_count` và đổi texture atlas là chạy được nhiều outfit, không phải viết lại shader.
- NPC nền di chuyển ngẫu nhiên đơn giản (wander) trong phạm vi khu vực concert được định nghĩa trước (ví dụ một `Rect2` hoặc danh sách điểm waypoint).
- Cung cấp `@export var npc_count: int` để dễ test hiệu năng với số lượng khác nhau (test với 200, 500, 1000 NPC).
- NPC ngoài camera + margin: không cần update animation chi tiết, chỉ update position (skip phần tốn kém nếu ngoài view).

## 2. Hệ thống gán quest theo xác suất

- Khi spawn mỗi NPC trong `CrowdManager`, dùng weighted random để set `has_quest = true/false`, dựa theo `@export var quest_probability: float = 0.1` (0.0 - 1.0).
- Định nghĩa một cấu trúc/Resource riêng cho dữ liệu quest (ví dụ `NPCQuestData` hoặc đơn giản là `Dictionary` lưu theo `npc_index`), để sau này có thể mở rộng nhiều loại quest khác nhau theo trọng số khác nhau **mà không cần sửa logic gán xác suất cốt lõi**.
- Hàm gán quest phải là 1 function riêng, dễ thay thế (ví dụ `_assign_quest(npc_index: int) -> void`), không trộn lẫn vào logic render hay logic movement.

## 3. Logic Promote / Demote

- Khi người chơi vào bán kính `promote_radius` (export) của 1 NPC có `has_quest = true` và `is_promoted = false`:
  - Lấy 1 Node từ **object pool** (pool NPC tương tác đã pre-instantiate sẵn, ví dụ 30 node — KHÔNG gọi `instantiate()` liên tục lúc runtime).
  - Đặt Node tại đúng `position` của NPC đó, set animation/outfit khớp với outfit_id.
  - Ẩn/loại bỏ instance tương ứng khỏi MultiMesh (ví dụ set scale = 0 hoặc đẩy ra ngoài vùng nhìn thấy trong buffer multimesh).
  - Set `is_promoted = true`.
- Node NPC tương tác (`npc_interactive.gd`, kế thừa `CharacterBody2D`) cần có:
  - `Area2D` để detect tương tác (người chơi bấm nút tương tác khi đứng gần).
  - Component/placeholder cho dialogue & quest (chưa cần UI thật, chỉ cần signal hoặc `print()` placeholder, ví dụ `signal interacted(npc_id)`).
- Khi người chơi ra khỏi bán kính `demote_radius` (lớn hơn `promote_radius` để tránh flicker liên tục ở biên):
  - Nếu NPC đó **chưa từng được tương tác** (chưa nhận quest/chưa nói chuyện) → trả Node về pool, hiện lại instance trong MultiMesh, set `is_promoted = false`.
  - Nếu NPC đó **đã tương tác rồi** (đã có state cần giữ, ví dụ đã giao quest) → **giữ nguyên Node thật**, không demote, vì cần giữ trạng thái.

---

## Tiêu chí hoàn thành (Acceptance Criteria)

- Chạy ổn định với **500 NPC nền** + tối đa **~20-30 NPC tương tác** tồn tại đồng thời cùng lúc trên màn hình, FPS không tụt đáng kể trên máy tầm trung.
- Có cách debug nhanh: hiển thị số NPC đang promoted hiện tại + FPS (overlay đơn giản, ví dụ `Label` góc màn hình hoặc `print` định kỳ).
- **Không hard-code logic chỉ cho 1 outfit** — khi sau này có texture atlas nhiều outfit, chỉ cần đổi texture + tăng `outfit_count`, không phải sửa lại CrowdManager hay shader.
- Code tách rõ 3 phần (render / quest assignment / promote-demote) thành các function hoặc file riêng, dễ đọc, dễ test từng phần độc lập.

## Output mong đợi
- `crowd_manager.gd` — quản lý data + MultiMeshInstance2D + wander movement.
- `crowd_npc.gdshader` — shader đọc INSTANCE_CUSTOM, sẵn logic outfit_id (dù outfit_count=1 lúc này).
- `npc_interactive.gd` + scene `.tscn` tương ứng — NPC tương tác thật (CharacterBody2D + Area2D + signal placeholder).
- Giải thích ngắn (comment trong code hoặc README) cách test: spawn bao nhiêu NPC, cách bật debug overlay, cách chỉnh `promote_radius`/`demote_radius`/`quest_probability` để test nhanh.
