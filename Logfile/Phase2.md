# Phase 2 — Stamina / Stress / Quest Loop (Godot 4)

> **Trạng thái: ĐÃ CHỐT THIẾT KẾ, CHƯA CODE.** Tài liệu này chốt lại core gameplay loop mới (stamina, stress, đồng hồ nhiệm vụ, 4 loại nhiệm vụ) dựa trên thảo luận thiết kế. Toàn bộ quyết định đã chốt ở mục 8 — sẵn sàng implement.

---

## 1. Core loop

```
Player di chuyển (stamina) ──► Nhận nhiệm vụ từ NPC (đồng hồ riêng)
										│
						 ┌──────────────┴──────────────┐
						 ▼                              ▼
			  Hoàn thành đúng giờ                  Hết giờ
			  → stress giảm nhẹ                → stress tăng
						 │                              │
						 └──────────► tiếp tục ◄─────────┘
														  │
										  Stress đầy ───► Thua
```

- **Stamina**: tài nguyên di chuyển. Sprint tốn stamina; hết stamina → **chỉ mất khả năng sprint**, tốc độ đi bộ (`walk_speed`) giữ nguyên, không bị phạt thêm. Stamina tự hồi khi không sprint.
- **Stress**: tài nguyên "thua/thắng" của 1 đêm diễn. **Tăng** khi 1 nhiệm vụ hết giờ mà chưa hoàn thành, **giảm** khi hoàn thành nhiệm vụ thành công. Đầy stress (100%) → game over.
- **Đồng hồ nhiệm vụ**: mỗi nhiệm vụ có thời gian giới hạn riêng, bắt đầu tính **chỉ khi player chủ động interact + accept** (không tính giờ ngay lúc NPC promote/xuất hiện gần player) — tránh bị trừ oan khi player còn chưa kịp thấy NPC giữa đám đông.

---

## 2. Hệ thống mới cần thêm

| Hệ thống | File đề xuất | Vai trò |
|---|---|---|
| `PlayerStats` | `player_stats.gd` (gắn vào `player.gd` hoặc autoload riêng) | Quản lý stamina + stress, expose `consume_stamina()`, `add_stress()`, `reduce_stress()`, signal `stress_maxed` |
| `Inventory` | `inventory.gd` (gắn vào `player.gd`) | Túi đồ 3 ô (`@export inventory_slots`), giới hạn số nhiệm vụ active cùng lúc, `has_free_slot()`, `assign_slot()`, `free_slot()` |
| `QuestManager` | `quest_manager.gd` (autoload hoặc con của Main) | Theo dõi đồng hồ của từng quest đang active, gọi vào `PlayerStats` khi hết giờ/hoàn thành, kiểm tra `Inventory` trước khi cho accept |
| `NPCQuestData` (mở rộng) | `npc_quest_data.gd` (đã có) | Thêm `quest_type`, `time_limit`, `time_remaining`, `state` (offered / active / completed / failed) |

`crowd_manager.gd` và `npc_interactive.gd` của Phase 1 **giữ nguyên kiến trúc promote/demote** — chỉ thêm bước "accept nhiệm vụ" vào luồng `interact()` hiện có (hiện đang là `print()` placeholder).

---

## 3. Stamina

| Tham số | Giá trị đề xuất | Ý nghĩa |
|---|---|---|
| `max_stamina` | 100 | stamina tối đa |
| `sprint_drain_per_sec` | 20 | tốc độ tụt khi giữ `run` |
| `stamina_regen_per_sec` | 12 | tốc độ hồi khi không sprint (đi bộ hoặc idle) |
| `min_stamina_to_sprint` | 5 | dưới mức này không cho bắt đầu sprint mới |

- Hết stamina → input `run` bị khoá (không chuyển sang `run_speed`), vẫn đi `walk_speed` bình thường.
- Regen luôn chạy nền (cả khi đi bộ và khi đứng yên), không cần "nghỉ" riêng.
- HUD: 1 thanh stamina góc màn hình, có thể tái dùng `debug overlay` pattern đã có ở Phase 1.

---

## 4. Stress

| Tham số | Giá trị đề xuất | Ý nghĩa |
|---|---|---|
| `max_stress` | 100 | đầy = thua, restart toàn bộ |
| `stress_per_timeout` | 15–25 (tuỳ loại nhiệm vụ, xem mục 6) | stress tăng khi 1 nhiệm vụ hết giờ |
| `stress_decay_on_success` | 10 | stress giảm ngay khi hoàn thành 1 nhiệm vụ đúng giờ |
| `stress_decay_per_sec` | 0.5 (đề xuất, cần playtest) | stress tự giảm dần theo thời gian khi đang chơi (áp dụng liên tục, không cần điều kiện gì thêm) |

- Stress có **3 nguồn thay đổi**: tăng khi timeout, giảm ngay khi hoàn thành thành công, và tự giảm chậm theo thời gian (`stress_decay_per_sec`) — cho người chơi khoảng thở khi đang không có nhiệm vụ nào gấp, đồng thời thưởng skill khi hoàn thành nhanh.
- Stress đầy (100%) → **restart toàn bộ** (không phải end đêm diễn + result screen).

---

## 5. Luồng nhận nhiệm vụ (accept flow)

1. Player interact với NPC có quest (Click chuột trái khi ở gần).
2. Dialog/placeholder hiện ra: mô tả nhiệm vụ + nút "Nhận" — nút này chỉ bấm được nếu `Inventory.has_free_slot()`. Hết ô trống → nút bị khoá, NPC vẫn đứng yên chờ.
3. Bấm "Nhận" → **đây là lúc đồng hồ bắt đầu chạy** (không phải lúc promote) — `Inventory.assign_slot()` chiếm 1 ô, quest chuyển sang state `active`, hiện thanh thời gian (UI nhỏ phía trên đầu NPC hoặc trong panel "nhiệm vụ đang làm" góc màn hình).
4. `QuestManager` đếm `time_remaining` mỗi frame cho mọi quest `active`:
   - Hết giờ mà chưa hoàn thành → `PlayerStats.add_stress()` + `Inventory.free_slot()`, quest chuyển `failed` (NPC rời đi / demote như cũ, không giữ state quest).
   - Hoàn thành trước giờ → `PlayerStats.reduce_stress()` + `Inventory.free_slot()`, quest chuyển `completed`.

### Túi đồ (Inventory) — giới hạn nhiệm vụ

Thay vì 1 con số giới hạn ẩn (`max_concurrent_quests`), giới hạn này được thể hiện trực tiếp bằng **túi đồ 3 ô**: mỗi ô = 1 nhiệm vụ đang nhận. Hết ô trống → không nhận thêm được nhiệm vụ mới cho tới khi giao/hết giờ 1 nhiệm vụ đang giữ để giải phóng ô.

| Tham số | Giá trị đề xuất | Ý nghĩa |
|---|---|---|
| `inventory_slots` | 3 (`@export`, tự chỉnh được) | số nhiệm vụ tối đa cùng lúc |

- Mỗi ô lưu 1 `QuestSlotData` (tham chiếu tới `NPCQuestData` đang active) + trạng thái hiển thị:
  - **Chưa lấy hàng** (nhiệm vụ carry vừa accept, chưa đến điểm nguồn) → icon viền mờ/outline theo loại nhiệm vụ (ghế/đồ ăn/mech).
  - **Đang mang** (đã lấy hàng ở điểm nguồn) → icon đặc, có thể thêm viền sáng để dễ nhận biết đang "tay đang vướng đồ".
  - **Nhiệm vụ không có vật phẩm** (ví dụ "ngăn cản đánh nhau") → chiếm 1 ô ngay khi accept, icon riêng (ví dụ dấu `!`), không có giai đoạn "lấy hàng".
- Accept nhiệm vụ = gọi `Inventory.has_free_slot()` trước khi cho hiện nút "Nhận" trong dialog; hết ô → nút bị khoá / disable, NPC vẫn đứng đó chờ (không bị mất nhiệm vụ, chỉ là chưa nhận được).
- Giao/hoàn thành hoặc hết giờ → gọi `Inventory.free_slot()`, ô đó trống lại ngay, không cần chờ animation gì thêm.
- HUD: vẽ 3 ô vuông cạnh thanh stamina/stress, ô trống hiển thị viền nhạt, ô có nhiệm vụ hiển thị icon tương ứng — giúp người chơi nhìn 1 lần biết còn rảnh tay nhận thêm nhiệm vụ hay không.

---

## 6. Bốn loại nhiệm vụ

Chia 2 nhóm cơ chế khác nhau:

### Nhóm A — Fetch & Carry (dùng chung 1 hệ thống generic)

| Quest | Điểm nguồn | Điểm đích | Thời gian đề xuất |
|---|---|---|---|
| Khiêng ghế | `khu ghế` (Area2D) | NPC đã accept quest | 45s |
| Giao đồ ăn | `khu bán hàng` (Area2D) | NPC đã accept quest | 35s |
| Bán mech | `quầy mech` (Area2D) | NPC đã accept quest | 30s |

- State chung: `idle (chưa lấy hàng) → carrying (đang mang) → delivered`.
- Lấy hàng: player đi vào `Area2D` nguồn, click chuột trái → chuyển `carrying`, hiện overlay sprite vật mang theo (ghế/đồ ăn/mech) trên player.
- Giao hàng: player mang `carrying` đến đúng NPC đã accept quest đó, click chuột trái → `delivered`, gọi `QuestManager` báo thành công.
- **Bán mech dùng chung 100% cơ chế carry** với ghế/đồ ăn: có điểm nguồn riêng (`quầy mech`), player phải đến lấy hàng trước khi mang đi bán — không có nhánh "tồn kho sẵn trong túi". 3 loại nhiệm vụ này chỉ khác `source_location` + icon/sprite vật mang theo, dùng đúng 1 hệ thống generic.
- Đang `carrying` **không khoá sprint** — player vẫn chạy bình thường khi đang mang đồ, độ khó của nhiệm vụ carry chỉ đến từ khoảng cách + đồng hồ đếm giờ, không cộng thêm giới hạn di chuyển.

### Nhóm B — Intervention (event riêng, không tái dùng code carry)

| Quest | Trigger | Cách giải quyết | Thời gian đề xuất |
|---|---|---|---|
| Ngăn cản đánh nhau | Ngẫu nhiên giữa 2 NPC nền gần nhau (hoặc tại điểm cố định) | Player đến gần + tương tác trong thời gian giới hạn | 20s |

- Cần thêm state mới cho 2 NPC liên quan (ví dụ `is_fighting` trong `CrowdManager`, hoặc promote tạm cả 2 NPC thành node thật với animation/placeholder "đang cãi nhau").
- Trigger **random hoàn toàn giữa NPC nền** (giống cơ chế `quest_probability` đang có) — không giới hạn vào khu vực cố định. Cần thêm 1 xác suất riêng (ví dụ `fight_probability` mỗi giây hoặc mỗi N giây, kiểm tra trong `CrowdManager._process`) để chọn ngẫu nhiên 2 NPC nền gần nhau và chuyển cả 2 sang state "đang cãi nhau".
- Giải quyết chỉ cần click chuột trái trong bán kính gần (không cần dialogue nhiều bước) để giữ nhịp game nhanh, đúng tinh thần "ngăn cản kịp lúc".

---

## 7. Việc cần làm (theo thứ tự đề xuất)

1. [x] `PlayerStats`: stamina + stress, test độc lập (chưa cần quest) bằng debug overlay. (ĐÃ XONG)
2. [x] Mở rộng `NPCQuestData` + `QuestManager`: luồng accept → đồng hồ → success/fail → gọi `PlayerStats`. Test với quest giả (chưa cần carry thật). (ĐÃ XONG)
3. [x] Carry mechanic cho **1 loại trước** (đề xuất "giao đồ ăn" vì đơn giản nhất) — làm template cho 2 loại còn lại. (ĐÃ XONG logic core & điểm lấy đồ)
4. [ ] Nhân bản carry mechanic cho "khiêng ghế" và "bán mech" (sau khi đã chốt mục 6). (CHƯA LÀM)
5. [ ] "Ngăn cản đánh nhau" — làm sau cùng vì cần state mới riêng, không tái dùng được carry. (CHƯA LÀM)
6. [x] HUD: Quest HUD Stack — danh sách nhiệm vụ đang nhận dạng Panel xếp chồng ở góc phải, mỗi quest hiện tên + thanh thời gian đếm ngược + trạng thái mang vác. (ĐÃ XONG)

---

## 8. Tổng hợp các quyết định thiết kế

- [x] Stress: tăng khi trễ, giảm khi hoàn thành thành công, **và tự giảm chậm theo thời gian** (`stress_decay_per_sec`).
- [x] Stress đầy → **restart toàn bộ**.
- [x] Giới hạn nhiệm vụ active: **túi đồ 3 ô** (`inventory_slots`, tự chỉnh), không dùng số ẩn.
- [x] "Bán mech": **đi lấy hàng ở quầy mech** trước, dùng chung 100% cơ chế carry với ghế/đồ ăn.
- [x] Đang carrying vật phẩm: **không khoá sprint**, player vẫn chạy bình thường.
- [x] "Ngăn cản đánh nhau": trigger **random hoàn toàn** giữa NPC nền, không giới hạn khu vực cố định.
- [x] Ngăn chặn nhận cùng lúc nhiều quest khi đứng gần nhiều NPC: **Chỉ tương tác với NPC gần nhất trong phạm vi.**
- [x] Đổi phím tương tác (interact): từ phím **E** sang **Click chuột trái (Left Mouse Button)**.
- [x] Quest HUD Stack: mỗi nhiệm vụ đang nhận = 1 Panel ở góc phải màn hình, xếp chồng từ trên xuống, đếm ngược độc lập, tự xóa khi hoàn thành/thất bại.

---

## 9. Quest HUD Stack — Thiết kế chi tiết

Hiển thị các nhiệm vụ đang nhận ở **góc trên bên phải** màn hình dưới dạng các Panel xếp chồng từ trên xuống. Số lượng panel = số nhiệm vụ đang active (tối đa 3 theo giới hạn túi đồ).

### Cấu trúc từng Panel (quest_hud_item)

```
┌──────────────────────────────┐
│ 🍜 Giao đồ ăn #5          32s│  ← Tên + thời gian còn lại
│ ████████████░░░░░░░░░░░░░░░ │  ← ProgressBar (xanh → vàng → đỏ)
│ [Chưa lấy hàng]             │  ← Trạng thái nhỏ
└──────────────────────────────┘
```

### Luồng cập nhật

| Sự kiện | Hành động trên HUD |
|---|---|
| `quest_accepted` | Tạo và thêm 1 Panel mới vào stack |
| `quest_timer_updated` | Cập nhật ProgressBar + số giây còn lại |
| `inventory_changed` (is_item_picked_up) | Đổi text trạng thái → "Sẵn sàng giao!" |
| `quest_completed` / `quest_failed` | Xóa Panel tương ứng khỏi stack |

### Màu sắc thanh thời gian

| Thời gian còn lại | Màu thanh |
|---|---|
| > 50% | Xanh lá (`#2ECC71`) |
| 25% – 50% | Vàng (`#F39C12`) |
| < 25% | Đỏ (`#E74C3C`) nhấp nháy |

### File cần tạo/sửa

| File | Trạng thái | Vai trò |
|---|---|---|
| `Scripts/quest_hud_item.gd` | [NEW] | Script điều khiển 1 panel quest |
| `Scene/quest_hud_item.tscn` | [NEW] | Layout UI của 1 panel quest |
| `Scripts/hud.gd` | [MODIFY] | Lắng nghe signal, thêm/xóa panel động |
| `Scene/hud.tscn` | [MODIFY] | Thêm `QuestListContainer` góc phải |
