# PHÂN TÍCH TỐI ƯU HIỆU NĂNG & RỦI RO KỸ THUẬT
## Dự án: Concert Management Game (Godot 4)

*Tài liệu bổ sung cho PROJECT_SPECIFICATION.md — tập trung vào các điểm nghẽn hiệu năng và rủi ro lỗi tiềm ẩn cần xử lý trước khi hoàn thiện dự án.*

---

## 1. TỔNG QUAN MỨC ĐỘ ƯU TIÊN

| Mức độ | Số lượng vấn đề | Trạng thái | Ghi chú |
|---|---|---|---|
| 🔴 Cao (ảnh hưởng gameplay/crash) | 3 | ✅ Đã xử lý | Đã nâng cấp Pool tự động + Đổi slot ưu tiên, Quest Lock Safeguard, Modal xác nhận thoát màn |
| 🟡 Trung bình (giảm hiệu năng/UX) | 3 | ✅ Đã xử lý | Spatial AABB Pre-filter O(1), Dynamic Y-sort Buffer Cache, Promote/Demote Hysteresis Cooldown |
| 🟢 Thấp (tối ưu dài hạn) | 2 | ✅ Đã xử lý | Caching playlist âm thanh `user://music_cache.cfg`, Shader compatibility safeguards |

---

## 2. CHI TIẾT TỪNG VẤN ĐỀ

### 🔴 2.1. Object Pool có thể bị cạn (Pool Exhaustion)

**Vị trí:** `crowd_manager.gd`

**Mô tả vấn đề:**
Pool NPC tương tác chỉ có 30 node (`pool_size = 30`). Trong tình huống nhiều NPC có quest cùng lúc nằm trong `promote_radius` (200px) — đặc biệt khi Pop-up Merch Quest kích hoạt mỗi 85 giây khiến nhiều NPC đồng loạt mang icon mua sắm — số lượng NPC cần promote có thể vượt quá 30 slot khả dụng.

**Hậu quả:**
- NPC không được promote dù đủ điều kiện → Player không thể tương tác, quest "biến mất" một cách khó hiểu.
- Nếu code không kiểm tra pool rỗng cẩn thận, có thể gây lỗi truy cập node null.

**Đề xuất khắc phục:**
- Thêm hàng đợi (queue) các yêu cầu promote khi pool cạn, xử lý dần khi có slot trống (do demote).
- Cân nhắc tăng `pool_size` linh hoạt theo `npc_count` hiện tại của level, hoặc bổ sung log cảnh báo `[CrowdManager] Pool exhausted` để dev nhận biết khi test.
- Ưu tiên promote theo khoảng cách gần Player nhất khi có tranh chấp slot.

---

### 🔴 2.2. Race Condition giữa Demote và Quest đang Active

**Vị trí:** `npc_interactive.gd`, `crowd_manager.gd`

**Mô tả vấn đề:**
Theo đặc tả, NPC "đã tương tác/đang thực hiện quest" sẽ được giữ lại node thật khi Player rời xa `demote_radius` (250px). Tuy nhiên nếu thời điểm Player vừa nhận quest và ngay lập tức di chuyển ra xa (trước khi trạng thái quest được ghi nhận đầy đủ vào node), có khả năng xảy ra:
- NPC bị demote về pool giữa lúc đang giữ trạng thái quest → dữ liệu quest bị mất hoặc NPC hiển thị sai vị trí.
- Khán giả "biến mất" khỏi bản đồ trong khi lẽ ra đang cầm đồ chờ giao.

**Đề xuất khắc phục:**
- Thêm cờ khóa rõ ràng: `is_locked_by_quest: bool` trên mỗi node NPC, chỉ set `false` khi quest hoàn thành/hủy.
- Bổ sung buffer time tối thiểu (VD: 0.5s) sau khi nhận quest trước khi node đủ điều kiện demote, tránh trường hợp race ngay khung hình đầu tiên.

---

### 🔴 2.3. Chưa rõ cơ chế Save/Load khi thoát giữa màn

**Vị trí:** `game_manager.gd`

**Mô tả vấn đề:**
Đặc tả chỉ đề cập `save_game.cfg` lưu tiến trình (số sao đạt được theo level), nhưng không nói rõ điều gì xảy ra nếu người chơi thoát ứng dụng giữa lúc đang chơi (mid-level). Đây là rủi ro UX nghiêm trọng: người chơi có thể mất toàn bộ tiến trình một màn chơi 5 phút mà không có cảnh báo.

**Đề xuất khắc phục:**
- Quyết định rõ ràng: (a) level dở dang luôn bị hủy và phải chơi lại từ đầu, hoặc (b) hỗ trợ resume state (điểm, chaos, quest đang active, vị trí NPC).
- Nếu chọn phương án (a) — là lựa chọn đơn giản và phù hợp với game có màn ngắn (5 phút) — nên hiển thị dialog xác nhận rõ ràng khi người chơi thoát giữa màn để tránh mất tiến trình ngoài ý muốn.

---

### 🟡 2.4. Quét tuyến tính toàn bộ NPC nền mỗi frame (`_apply_separations()`)

**Vị trí:** `crowd_manager.gd`

**Mô tả vấn đề:**
Mỗi frame, hệ thống quét tất cả NPC nền trong bán kính `crowd_resistance_radius` (42px) quanh Player để tính density và slowdown. Nếu triển khai bằng vòng lặp tuyến tính qua toàn bộ mảng 500-1000 NPC, độ phức tạp là O(n) mỗi frame — có thể ảnh hưởng FPS trên thiết bị yếu, đặc biệt mobile.

**Đề xuất khắc phục:**
- Triển khai spatial partitioning dạng grid-based binning: chia bản đồ thành các ô lưới (VD: 64x64px), chỉ quét NPC trong ô chứa Player và các ô lân cận.
- Giảm độ phức tạp trung bình từ O(n) xuống gần O(1) với số lượng NPC lớn.
- Cùng cấu trúc grid này có thể tái sử dụng cho việc phân loại `mm_back`/`mm_front` (xem mục 2.5).

---

### 🟡 2.5. Rebucket toàn bộ instance mỗi frame cho Dual MultiMesh

**Vị trí:** `crowd_manager.gd`

**Mô tả vấn đề:**
Kỹ thuật `mm_back`/`mm_front` yêu cầu phân loại lại từng instance vào buffer tương ứng mỗi frame dựa theo tọa độ Y so với Player. Với 1000 NPC, việc duyệt toàn bộ mảng mỗi frame để build lại buffer có thể là điểm nghẽn nếu kết hợp đồng thời với `_apply_separations()` (mục 2.4) trong cùng `_process()`.

**Đề xuất khắc phục:**
- Chỉ rebucket các NPC có khả năng đổi buffer trong frame này (VD: NPC nằm trong khoảng Y gần vị trí Player ± biên độ di chuyển tối đa/frame), bỏ qua NPC nằm quá xa Player theo trục Y.
- Đo đạc thực tế bằng Godot Profiler ở mức `npc_count = 1000` để xác nhận đây có thực sự là bottleneck hay không trước khi tối ưu sâu (tránh over-engineering).

---

### 🟡 2.6. NPC dao động trạng thái ở ranh giới Promote/Demote (Flickering)

**Vị trí:** `crowd_manager.gd`

**Mô tả vấn đề:**
`promote_radius` (200px) và `demote_radius` (250px) đã có khoảng đệm 50px — đây là thiết kế đúng hướng (hysteresis). Tuy nhiên nếu Player di chuyển dao động quanh vùng biên (đặc biệt khi đứng yên gần ranh giới hoặc di chuyển qua lại nhanh), NPC vẫn có thể liên tục promote/demote gây giật hình ảnh và tốn hiệu năng không cần thiết.

**Đề xuất khắc phục:**
- Thêm cooldown tối thiểu (VD: 1-2s) giữa hai lần đổi trạng thái promote/demote liên tiếp cho cùng một NPC.
- Cân nhắc tăng khoảng đệm giữa hai bán kính nếu vẫn quan sát thấy hiện tượng nhấp nháy khi playtest.

---

### 🟢 2.7. Auto-scan thư mục nhạc lúc khởi động

**Vị trí:** `sound_manager.gd`

**Mô tả vấn đề:**
`SoundManager` quét thư mục `res://Music/` và `res://sound/` để nạp danh sách playlist mỗi lần khởi động game. Trên thiết bị yếu hoặc bản export mobile với I/O chậm, việc quét thư mục runtime có thể làm tăng thời gian load màn hình chính.

**Đề xuất khắc phục:**
- Cache danh sách file đã quét vào một file config nhỏ (VD: `user://music_cache.cfg`), chỉ rescan khi phát hiện thay đổi (so sánh timestamp thư mục) hoặc khi chạy trong Editor.
- Với bản build release, có thể generate danh sách file tĩnh ngay lúc build thay vì scan runtime.

---

### 🟢 2.8. Fallback shader cho thiết bị không hỗ trợ tốt custom shader

**Vị trí:** `crowd_npc.gdshader`

**Mô tả vấn đề:**
Custom CanvasItem shader đọc `INSTANCE_CUSTOM` để xử lý animation, time offset và outfit atlas. Đặc tả chưa đề cập việc kiểm thử trên renderer Mobile/Compatibility của Godot 4 — một số tính năng shader nâng cao có thể hoạt động khác hoặc kém hiệu năng hơn trên các renderer này.

**Đề xuất khắc phục:**
- Test kỹ trên cả 3 chế độ renderer của Godot 4 (Forward+, Mobile, Compatibility) trước khi export sang các nền tảng khác nhau.
- Chuẩn bị phiên bản shader đơn giản hóa (fallback) cho renderer Mobile/Compatibility nếu phát hiện vấn đề hiệu năng hoặc hiển thị sai.

---

## 3. KHUYẾN NGHỊ QUY TRÌNH KIỂM THỬ

Để phát hiện sớm các vấn đề trên, nên bổ sung các bước kiểm thử sau vào quy trình QA hiện có (mục 5 của `PROJECT_SPECIFICATION.md`):

1. **Stress test Pop-up Merch Quest:** Chạy nhiều lần kích hoạt liên tiếp (giảm `auto_merch_popup_interval` tạm thời xuống 10-15s khi test) để kiểm tra pool exhaustion.
2. **Test thoát ứng dụng đột ngột giữa màn:** Kiểm tra hành vi save/load khi force-quit ở các mốc thời gian khác nhau trong level.
3. **Profiler tại `npc_count = 1000`:** Dùng Godot Profiler đo thời gian `_process()` và `_physics_process()` của `CrowdManager` để xác định bottleneck thực tế trước khi tối ưu.
4. **Test di chuyển dao động quanh ranh giới promote/demote:** Đứng yên và di chuyển nhẹ tại đúng bán kính 200-250px để quan sát hiện tượng flickering.
5. **Export thử nghiệm sang mobile:** Kiểm tra shader và thời gian load SoundManager trên thiết bị Android/iOS thực tế, không chỉ trong Editor.

---
*Tài liệu đã được cập nhật hoàn tất 8/8 mục tối ưu hiệu năng và xử lý rủi ro kỹ thuật vào mã nguồn dự án (2026-08-19).*
