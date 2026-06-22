# Phase 1 — Hệ thống đám đông NPC & Va chạm Player–NPC (Godot 4)

> **Trạng thái: ĐÃ HOÀN THÀNH.** Tài liệu này tổng hợp lại toàn bộ kiến trúc đã triển khai trong Phase 1, gộp từ 2 prompt thiết kế ban đầu (hệ thống đám đông + hệ thống va chạm/vật lý), phản ánh đúng phiên bản code cuối cùng đang chạy trong project.

## Bối cảnh dự án

Game concert top-down 2D pixel art, Godot 4 (GDScript). Một đêm concert có rất nhiều NPC khán giả cùng xuất hiện trên màn hình. Đa số NPC là đám đông trang trí, một số ít có quest để người chơi tương tác.

Asset: một model cơ thể pixel art (sprite sheet 16×32, hỗ trợ nhiều outfit qua atlas dựng động), animation 3 hướng vẽ thật (down/up/right) + hướng left dùng `flip_h`.

---

## 1. Kiến trúc tổng thể

| File | Vai trò |
|---|---|
| `crowd_manager.gd` | Render đám đông nền (`MultiMeshInstance2D`), gán quest, promote/demote, resistance đám đông |
| `npc_interactive.gd` | NPC tương tác thật (`CharacterBody2D`), dialogue/quest placeholder, nhường nhẹ khi player ép vào |
| `npc_quest_data.gd` | `Resource` chứa dữ liệu 1 quest (`quest_id`, `title`, `description`, `is_completed`) |
| `player.gd` | Di chuyển, animation 4 hướng, áp resistance đám đông + contact slowdown |

**Luồng hoạt động:** NPC sinh ra là dữ liệu nền trong `MultiMesh` → nếu `has_quest = true` và player đến gần (`promote_radius`) → lấy 1 Node từ pool, hiện lên thành NPC tương tác thật → nếu player đi xa (`demote_radius`) và NPC **chưa được tương tác** → trả về pool, ẩn lại; nếu **đã tương tác** → giữ Node thật vĩnh viễn để giữ state.

---

## 2. CrowdManager — Render đám đông nền

- `MultiMeshInstance2D` + `QuadMesh` (32×32) render toàn bộ NPC nền bằng **1 draw call**, không có Node riêng cho từng người.
- Atlas texture nhiều outfit được **dựng động lúc `_ready()`** (`_create_dynamic_atlas()`): ghép các sprite sheet Idle/Walk theo từng `outfit_id` vào 1 `ImageTexture` lớn, fallback về asset mặc định nếu thiếu file outfit riêng — nên hiện tại chạy đúng với 1 outfit, và chỉ cần thêm sprite sheet theo đúng quy ước tên file (`res://16x32/<id>_Idle-Sheet.png`, `..._Walk-Sheet.png`) là tự động có thêm outfit, không cần sửa code.
- Dữ liệu NPC dạng array-of-struct bằng packed array: `positions`, `velocities`, `outfit_ids`, `has_quests`, `is_promoted`, `time_offsets`, `wander_timers`, `directions` (0=Down/1=Right/2=Up), `flip_hs`, `is_walking`.
- Shader (`crowd_npc.gdshader`) đọc `INSTANCE_CUSTOM` (outfit_id, is_walking, direction, time_offset) + `instance_color` (flip_h) để chọn đúng frame/outfit trong atlas — sẵn sàng nhiều outfit dù hiện tại `outfit_count = 1`.
- Wander behavior: state machine **idle ↔ walking** theo `wander_timers` (`min/max_wander_time`, `min/max_idle_time`), hướng đi random mỗi lần chuyển sang walking, bounce nhẹ khi chạm biên `wander_area`.
- Tối ưu: NPC ngoài camera view (`_get_camera_view_rect()`, có margin 200px) bị đẩy ra ngoài vùng nhìn thấy trong buffer multimesh, không cập nhật animation/custom data chi tiết; NPC đã promote bị multimesh ẩn (transform đẩy ra `(-999999, -999999)`).
- Debug overlay (`CanvasLayer` + `Label`): hiển thị FPS, tổng số NPC, số NPC đang promoted, mật độ NPC quanh player.

### 2.1 Render layer đúng theo chiều sâu (Player ↔ đám đông nền)

> **Bug đã fix:** Player đi xuống dưới NPC nền nhưng vẫn bị vẽ sai lớp (NPC nền lúc nào cũng đè lên hoặc lúc nào cũng bị đè, không đổi theo vị trí thật).

- **Nguyên nhân:** đám đông nền render bằng **1 `MultiMeshInstance2D` duy nhất** = 1 CanvasItem. Engine chỉ y-sort được giữa các **Node riêng biệt** (Player, NPC promoted...), không thể tự y-sort **từng instance bên trong 1 MultiMesh** so với Player.
- **Fix:** tách render đám đông nền thành **2 buffer**: `mm_back` (`z_index = -1`, vẽ sau Player) và `mm_front` (`z_index = +1`, vẽ trước Player), dùng chung 1 atlas texture + 1 shader material như cũ.
  - Mỗi frame, `_process()` so sánh `position.y` của từng NPC nền với `position.y` của Player (local space của CrowdManager): NPC có y lớn hơn Player (đứng thấp hơn trên màn hình → gần camera hơn) → đẩy vào `mm_front`; ngược lại → `mm_back`. NPC còn lại bị ẩn ở buffer kia bằng cách đẩy transform ra `(-999999, -999999)`, giống kỹ thuật ẩn NPC đã promote.
  - `_promote_npc` / `_demote_npc` cũng cập nhật để ẩn/hiện đúng ở cả 2 buffer, tránh nhấp nháy 1 frame khi promote/demote.
  - NPC promoted (`npc_interactive.gd`, Node2D thật) không bị ảnh hưởng — z-index của engine vẫn ưu tiên hơn y-sort nên layer Player ↔ NPC promoted không cần sửa.
- Yêu cầu cấu trúc scene: Player và CrowdManager phải là **sibling cùng 1 parent** (đúng giả định `../CrowdManager` trong `player.gd`), và Player không đặt `z_index` thủ công khác 0 trong Inspector.

## 3. Hệ thống gán quest theo xác suất

- `@export var quest_probability: float = 0.1` — mỗi NPC sinh ra có `has_quest = true` theo xác suất này (weighted random đơn giản).
- Dữ liệu quest tách riêng vào `NPCQuestData` (`Resource`, file `npc_quest_data.gd`) — `quest_id`, `title`, `description`, `is_completed`.
- `_assign_quest(npc_idx)` là hàm riêng, chỉ tạo `NPCQuestData` và lưu vào `quest_data_map[npc_idx]`, không trộn với logic render/movement → dễ thay bằng nhiều loại quest trọng số khác nhau sau này mà không đụng vào phần còn lại.

## 4. Promote / Demote

- Object pool (`npc_pool`, kích thước `pool_size = 30`) — pre-instantiate `npc_interactive.tscn`, **không** `instantiate()` lúc runtime trừ khi pool hết (tự mở rộng nếu cần).
- `_check_promote_demote(player)`:
  - **Promote:** NPC có `has_quest = true`, chưa promoted, trong `promote_radius` → `_promote_npc(i)`: lấy node từ pool, đặt đúng `position`/hướng/flip/outfit hiện tại của NPC nền, gọi `setup()`, set `is_promoted[i] = 1`, ẩn instance khỏi multimesh.
  - **Demote:** NPC promoted, ngoài `demote_radius`, **chưa** `is_interacted` → `_demote_npc(i)`: trả node về pool, hiện lại instance multimesh, set `is_promoted[i] = 0`. NPC **đã** `is_interacted` → giữ nguyên Node thật, không demote (giữ state quest).
- NPC tương tác thật (`npc_interactive.gd`, `CharacterBody2D`):
  - `CircleShape2D` (radius 8) để va chạm, vùng detect riêng (`_on_detection_area_body_entered/exited`) để biết player đứng gần.
  - `signal interacted(npc_index)` + `interact()` (placeholder `print` dialogue/quest), bấm phím tương tác (`ui_accept` / `E`) khi đang ở gần.

---

## 5. Va chạm & Vật lý Player ↔ NPC

> Thiết kế ban đầu dùng cơ chế **"push"** (đẩy NPC bay ra bằng lực, tự dừng nhờ friction). Cơ chế này đã được **thay bằng "resistance / yield"** vì lực đẩy mạnh tạo cảm giác phi vật lý — mục tiêu cuối cùng: **không đi xuyên qua được, nhưng đi qua đám đông chỉ khó/chậm, không có gì bị bắn bay.**

### Lớp 1 — Player ↔ NPC promoted (physics thật)
- Player (`CharacterBody2D`) có `CollisionShape2D` (`CapsuleShape2D` height=20 radius=6, hoặc `CircleShape2D` radius=7), layer `1`, mask `2`.
- NPC promoted: `CircleShape2D` radius=8, layer `2`, mask `1` (chỉ active khi đã promote; lúc còn trong pool, `collision_layer/mask = 0`).
- `move_and_slide()` của Player tự chặn xuyên qua NPC — **đây là phần đảm bảo "không đi xuyên qua được"**, không liên quan gì đến lực đẩy.
- Khi player va vào: NPC chỉ **nhường rất nhẹ** (`yield_max_offset = 6px`, `yield_speed = 40`) theo hướng bị ép (`receive_press(direction)`), rồi tự về `base_position` khi không còn bị ép — không có `push_velocity`/friction như bản cũ.
- Player tự giảm tốc độ của chính nó (`contact_slowdown_factor = 0.4`) ở **frame kế tiếp** khi đang tiếp xúc NPC, thay vì truyền lực cho NPC.

### Lớp 2 — Player ↔ NPC nền (resistance, không có physics node)
- `CrowdManager._apply_separations(player_local_pos)` mỗi frame quét NPC nền trong `crowd_resistance_radius` quanh player:
  - Đếm số NPC trong bán kính → mật độ đám đông cục bộ (`_last_crowd_density`).
  - NPC chỉ nhường nhẹ (`npc_yield_strength = 18`, nhỏ hơn lực đẩy cũ rất nhiều) để không bị đè lên, **không bắn xa**.
- `get_crowd_slowdown()` quy đổi mật độ thành hệ số tốc độ (`slowdown_per_npc = 0.08` mỗi NPC, sàn `min_speed_multiplier = 0.45`) — **player nhân hệ số này vào tốc độ chính nó** trước khi `move_and_slide()`. Đám đông dày → tự đi chậm hơn, không có tường cứng, không có gì bị đẩy.
- NPC ↔ NPC separation (optional, `enable_npc_separation`, tắt mặc định vì O(n²) tốn CPU với 500 NPC).

### Collision Layers

| Layer | Tên | Dùng cho |
|---|---|---|
| 1 | `player` | Player body |
| 2 | `npc` | NPC promoted body |
| 3 | `world` | Tường, vật cản môi trường (tương lai) |

Mask: Player mask = `2` (va với NPC) · NPC promoted mask = `1` (va với Player).

---

## 6. Bảng tham số (`@export`) để tune

| Tham số | File | Mặc định | Ý nghĩa |
|---|---|---|---|
| `npc_count` | crowd_manager | 500 | số NPC nền, test 200/500/1000 |
| `quest_probability` | crowd_manager | 0.1 | tỉ lệ NPC có quest |
| `promote_radius` | crowd_manager | 200 | bán kính thăng cấp |
| `demote_radius` | crowd_manager | 250 | bán kính giáng cấp (> promote_radius) |
| `outfit_count` | crowd_manager | 1 | số outfit trong atlas |
| `npc_speed` | crowd_manager | 50 | tốc độ wander NPC nền |
| `pool_size` | crowd_manager | 30 | số Node NPC tương tác pre-instantiate |
| `crowd_resistance_radius` | crowd_manager | 45 | bán kính đo mật độ quanh player |
| `npc_yield_strength` | crowd_manager | 18 | NPC nền nhường nhẹ bao nhiêu |
| `slowdown_per_npc` | crowd_manager | 0.08 | mỗi NPC làm player chậm thêm bao nhiêu |
| `min_speed_multiplier` | crowd_manager | 0.45 | tốc độ sàn của player giữa đám đông dày |
| `npc_separation_radius/strength` | crowd_manager | 20 / 50 | NPC nền tự tách nhau (optional) |
| `enable_npc_separation` | crowd_manager | false | tắt mặc định, tốn CPU O(n²) |
| `yield_max_offset` | npc_interactive | 6 | NPC promoted nhường tối đa bao nhiêu px |
| `yield_speed` | npc_interactive | 40 | tốc độ nhường/trả lại |
| `contact_slowdown_factor` | player | 0.4 | tốc độ còn lại khi player ép vào NPC promoted |
| `walk_speed` / `run_speed` | player | 200 / 300 | tốc độ di chuyển cơ bản |

---

## 7. Cách test nhanh

- Đổi `npc_count` để test hiệu năng (200 / 500 / 1000) — theo dõi FPS qua debug overlay góc màn hình.
- Đổi `promote_radius` / `demote_radius` để test khoảng cách thăng/giáng cấp (luôn giữ `demote_radius > promote_radius` để tránh flicker biên).
- Đổi `quest_probability` để có nhiều/ít NPC có nhiệm vụ hơn.
- Đi vào giữa đám đông và quan sát: NPC nền chỉ lệch nhẹ chỗ đứng, **không bị bắn ra xa**; tốc độ di chuyển của player giảm dần theo mật độ xung quanh — overlay hiển thị thêm "Density quanh player" để kiểm chứng trực quan.
- Đứng ép vào 1 NPC promoted: NPC lệch vài pixel rồi giữ yên, player đi chậm hẳn lại trong lúc tiếp xúc, không có hiện tượng văng/giật.
- Bật `enable_npc_separation` chỉ khi `npc_count ≤ 200` để test NPC nền tự tách nhau (mặc định nên để tắt).

---

## 8. Tiêu chí hoàn thành (Acceptance Criteria)

- [x] Chạy ổn định với 500 NPC nền + tối đa ~20–30 NPC tương tác cùng lúc, FPS không tụt đáng kể.
- [x] Debug overlay: số NPC promoted + FPS + mật độ đám đông quanh player.
- [x] Không hard-code logic cho 1 outfit — atlas dựng động theo `outfit_count`, shader đọc UV theo `outfit_id`.
- [x] Code tách rõ: render (`crowd_manager.gd`) / quest assignment (`_assign_quest`, `npc_quest_data.gd`) / promote-demote (`_check_promote_demote`, `_promote_npc`, `_demote_npc`) / va chạm-resistance (`_apply_separations`, `get_crowd_slowdown`, `receive_press`).
- [x] Player không đi xuyên qua NPC promoted (collision thật, không nhờ lực đẩy).
- [x] Đi qua đám đông NPC nền chỉ khó/chậm (resistance), NPC không bị bắn bay.
- [x] NPC promoted khi bị ép vào chỉ lệch nhẹ rồi tự về vị trí gốc, không còn hiện tượng "bắn rồi dừng nhờ friction".
- [x] Layer hiển thị đúng chiều sâu: Player đi qua đám đông nền theo đúng vị trí Y (NPC ở dưới Player thì đè lên, NPC ở trên Player thì bị đè), không còn tình trạng layer cố định sai một chiều do MultiMesh không tự y-sort được theo từng instance.

---

## 9. Hướng mở rộng cho Phase tiếp theo (chưa làm)

- Nhiều loại outfit thật (hiện đang fallback atlas mặc định khi thiếu sprite sheet riêng theo `outfit_id`).
- Nhiều loại quest có trọng số khác nhau (hiện `NPCQuestData` chỉ có 1 template quest cố định trong `_assign_quest`).
- UI dialogue/quest thật thay cho `print()` placeholder khi `interact()`.
- NPC nền tách nhau theo viewport-only thay vì tắt hẳn `enable_npc_separation`, để dùng được với `npc_count` lớn hơn 200.
