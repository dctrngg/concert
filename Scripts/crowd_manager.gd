extends Node2D

@export var shader: Shader = preload("res://Scene/crowd_npc.gdshader")
@export var npc_count: int = 500
@export var quest_probability: float = 0.1
@export var promote_radius: float = 200.0
@export var demote_radius: float = 250.0
@export var outfit_count: int = 1
@export var npc_speed: float = 50.0
@export var wander_area: Rect2 = Rect2(-1500, -1500, 3000, 3000)
@export var enable_stage_obstacle: bool = true
@export var stage_obstacle_rect: Rect2 = Rect2(-250, -190, 560, 135)

@export var min_wander_time: float = 1.0
@export var max_wander_time: float = 4.0
@export var min_idle_time: float = 2.0
@export var max_idle_time: float = 6.0

@export var pool_size: int = 30

@export_group("Character Filter Config")
## Các từ khóa tên nhân vật/thư mục không phù hợp với concert để tự động loại bỏ (vd: goblin, viking, knight, punk_kid_boy)
@export var excluded_character_keywords: Array[String] = ["goblin", "viking", "knight", "punk_kid_boy", "punk kid"]

## --- Resistance đám đông cho NPC nền (thay cho "push" cũ) ---
## KHÔNG đẩy NPC bay ra mạnh nữa. NPC nền chỉ "nhường" rất nhẹ để không đè lên
## player; cảm giác "khó đi qua đám đông" chủ yếu đến từ việc PLAYER tự bị làm
## chậm theo mật độ NPC quanh nó (xem get_crowd_slowdown(), player.gd gọi hàm
## này mỗi frame để nhân vào speed của chính nó).
## Bán kính tính mật độ NPC quanh player (local units).
@export var crowd_resistance_radius: float = 42.0
## NPC nhường đường tự nhiên khi player đi qua (px/s)
@export var npc_yield_strength: float = 75.0
## Giảm thiểu làm chậm để player di chuyển qua đám đông mượt mà
@export var slowdown_per_npc: float = 0.02
## Tốc độ tối thiểu của player khi đi qua đám đông (85% tốc độ gốc)
@export var min_speed_multiplier: float = 0.85
## Khoảng cách tối thiểu giữa 2 NPC nền (separation)
@export var npc_separation_radius: float = 20.0
## Sức separation giữa NPC với nhau
@export var npc_separation_strength: float = 50.0
@export_group("Tree Collision Config")
## Tỉ lệ chiều rộng va chạm gốc cây so với Tile (Mặc định: 0.36 = 36% rộng tile)
@export var tree_trunk_width_ratio: float = 0.36
## Tỉ lệ chiều cao va chạm gốc cây so me với Tile (Mặc định: 0.26 = 26% cao tile)
@export var tree_trunk_height_ratio: float = 0.26
## Độ lệch Y vị trí chân gốc cây xuống phía dưới (Mặc định: 0.35 = dịch xuống 35%)
@export var tree_trunk_y_offset: float = 0.35

@export_group("VIP Area Config")
@export var enable_vip_area: bool = true
## Số lượng NPC trang trí đứng trong các ô VIP (ví dụ: 300 NPC)
@export var vip_npc_count: int = 300
## Kéo thả các Node VIPZone1, VIPZone2, VIPZone3 (Area2D có CollisionShape2D) để tự chỉnh khung ô VIP trong Editor Viewport
@export var vip_zone_1: NodePath
@export var vip_zone_2: NodePath
@export var vip_zone_3: NodePath
## Backup aliases
@export var vip_zone_left: NodePath
@export var vip_zone_right: NodePath
## Vùng khung mặc định nếu không gán Node (toạ độ CrowdManager local)
@export var default_vip_box_1: Rect2 = Rect2(-245.0, -165.0, 235.0, 290.0)
@export var default_vip_box_2: Rect2 = Rect2(75.0, -165.0, 235.0, 290.0)
@export var default_vip_box_3: Rect2 = Rect2(-85.0, -165.0, 170.0, 290.0)
@export var default_vip_box_left: Rect2 = Rect2(-245.0, -165.0, 235.0, 290.0)
@export var default_vip_box_right: Rect2 = Rect2(75.0, -165.0, 235.0, 290.0)

@export_group("Audience Area Config")
## Kéo thả các Node AudienceZone (Area2D có CollisionShape2D) để tự chỉnh phạm vi khán giả trong Editor Viewport
@export var audience_zone_1: NodePath
@export var audience_zone_2: NodePath
@export var audience_zone_3: NodePath
@export var audience_zone_4: NodePath
@export var audience_zone_5: NodePath
@export var audience_zone_6: NodePath
@export var audience_zone_7: NodePath
## Backup NodePath đơn cũ
@export var audience_zone: NodePath

## Vùng khán giả mặc định nếu không gán Node (toạ độ CrowdManager local)
@export var default_audience_area_1: Rect2 = Rect2(-240.0, 40.0, 210.0, 360.0)
@export var default_audience_area_2: Rect2 = Rect2(30.0, 40.0, 210.0, 360.0)
@export var default_audience_area: Rect2 = Rect2(-260.0, -160.0, 580.0, 410.0)

var interactive_npc_scene = preload("res://Scene/npc_interactive.tscn")

# Hai MultiMeshInstance2D: "back" vẽ SAU Player, "front" vẽ TRƯỚC Player.
# Lý do cần 2 cái: 1 MultiMeshInstance2D là 1 CanvasItem duy nhất, không thể
# tự y-sort TỪNG instance bên trong nó với Player (CharacterBody2D riêng) —
# nên phải chia động NPC nền vào 1 trong 2 buffer này mỗi frame theo vị trí Y
# so với Player để fix lỗi Player luôn nằm sai lớp so với đám đông nền.
var mm_back: MultiMeshInstance2D
var mm_front: MultiMeshInstance2D

# NPC array-of-struct representation in PackedArrays
var positions: PackedVector2Array = PackedVector2Array()
var velocities: PackedVector2Array = PackedVector2Array()
var quest_origin_positions: PackedVector2Array = PackedVector2Array()
var quest_origin_locked: PackedByteArray = PackedByteArray() # 1 = locked, 0 = unlocked
var outfit_ids: PackedInt32Array = PackedInt32Array()
var has_quests: PackedByteArray = PackedByteArray() # 1 = true, 0 = false
var is_vip: PackedByteArray = PackedByteArray() # 1 = VIP NPC (trang trí, không quest), 0 = Normal
var is_promoted: PackedByteArray = PackedByteArray() # 1 = true, 0 = false
var time_offsets: PackedFloat32Array = PackedFloat32Array()
var wander_timers: PackedFloat32Array = PackedFloat32Array()
var directions: PackedFloat32Array = PackedFloat32Array() # 0.0=Down, 1.0=Right, 2.0=Up
var flip_hs: PackedFloat32Array = PackedFloat32Array() # 1.0=flip, 0.0=normal
var is_walking: PackedByteArray = PackedByteArray() # 1=walk, 0=idle
var npc_assigned_zone: PackedInt32Array = PackedInt32Array() # 0 = Zone 1, 1 = Zone 2

# MultiMesh update cache arrays (giảm 85% CPU overhead cho 60 FPS)
var prev_positions: PackedVector2Array = PackedVector2Array()
var prev_directions: PackedFloat32Array = PackedFloat32Array()
var prev_is_walking: PackedByteArray = PackedByteArray()
var prev_buffer_front: PackedByteArray = PackedByteArray()

# Zone Rect Cache (loại bỏ lag khi va chạm đám đông đông đúc)
var _cached_audience_zones: Array[Rect2] = []
var _cached_vip_boxes: Array[Rect2] = []

var outfit_texture_paths: Array[String] = []
var outfit_sprite_frames: Array[SpriteFrames] = []

# Map of npc_index -> NPCQuestData
var quest_data_map: Dictionary = {}

# Object pool of interactive NPCs
var npc_pool: Array[CharacterBody2D] = []
# Map of npc_index -> NPCInteractive node currently active
var promoted_nodes: Dictionary = {}

# Debug Overlay
var debug_label: Label

# Mật độ NPC nền quanh player ở frame gần nhất (dùng cho get_crowd_slowdown())
var _last_crowd_density: int = 0


var barrier_layer: TileMapLayer = null
var object_layer: TileMapLayer = null
var wall_layer: TileMapLayer = null
const TILE_GRID_SIZE: float = 16.0
var blocked_grid_cells: Dictionary = {}
var _time_accum: float = 0.0

func _ready() -> void:
	barrier_layer = get_node_or_null("../barrier")
	object_layer = get_node_or_null("../Object")
	wall_layer = get_node_or_null("../Wall")
	_build_object_tile_rects()
	_create_merged_tilemap_collisions()
	add_to_group("crowd_manager")
	wander_area = get_audience_area()
	# 1. Setup 2 MultiMeshInstance2D (back/front) — xem giải thích ở khai báo var
	mm_back = MultiMeshInstance2D.new()
	mm_back.name = "MultiMeshBack"
	mm_back.z_as_relative = true
	mm_back.z_index = -1
	add_child(mm_back)

	mm_front = MultiMeshInstance2D.new()
	mm_front.name = "MultiMeshFront"
	mm_front.z_as_relative = true
	mm_front.z_index = 1
	add_child(mm_front)

	for mmi in [mm_back, mm_front]:
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.instance_count = npc_count

		var quad = QuadMesh.new()
		quad.size = Vector2(41.6, 41.6) # 32 * 1.3x scale
		mm.mesh = quad

		mmi.multimesh = mm

	# Generate combined atlas texture dynamically (dùng chung cho cả 2 buffer)
	var atlas_tex = _create_dynamic_atlas()
	mm_back.texture = atlas_tex
	mm_front.texture = atlas_tex

	# Set shader material parameters (dùng chung 1 material cho cả 2 buffer)
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("texture_size", Vector2(128.0, 256.0 * outfit_count))
	mm_back.material = mat
	mm_front.material = mat
	
	# 2. Resize internal arrays
	positions.resize(npc_count)
	velocities.resize(npc_count)
	quest_origin_positions.resize(npc_count)
	quest_origin_locked.resize(npc_count)
	outfit_ids.resize(npc_count)
	has_quests.resize(npc_count)
	is_vip.resize(npc_count)
	is_promoted.resize(npc_count)
	time_offsets.resize(npc_count)
	wander_timers.resize(npc_count)
	directions.resize(npc_count)
	flip_hs.resize(npc_count)
	is_walking.resize(npc_count)
	npc_assigned_zone.resize(npc_count)
	prev_positions.resize(npc_count)
	prev_directions.resize(npc_count)
	prev_is_walking.resize(npc_count)
	prev_buffer_front.resize(npc_count)
	prev_buffer_front.fill(255)
	
	# 3. Initialize background NPCs (VIP & General Admission)
	var effective_vip_count = min(vip_npc_count, npc_count) if enable_vip_area else 0
	var vip_boxes = get_vip_boxes()
	var num_vip_boxes = max(1, vip_boxes.size())
	
	for i in range(npc_count):
		var is_vip_npc = (i < effective_vip_count)
		if is_vip_npc:
			is_vip[i] = 1
			has_quests[i] = 0 # VIP NPC chỉ đứng trang trí, KHÔNG giao quest
			npc_assigned_zone[i] = -1
			
			var box_idx = i % num_vip_boxes
			var target_box = vip_boxes[box_idx]
			var idx_in_box = i / num_vip_boxes
			var total_per_box = max(1, (effective_vip_count + num_vip_boxes - 1) / num_vip_boxes)
			
			var cols = max(1, int(sqrt(total_per_box * (target_box.size.x / target_box.size.y))))
			var rows = max(1, int(ceil(float(total_per_box) / float(cols))))
			
			var c = idx_in_box % cols
			var r = idx_in_box / cols
			
			var step_x = target_box.size.x / float(cols)
			var step_y = target_box.size.y / float(rows)
			
			var base_pos = Vector2(
				target_box.position.x + (c + 0.5) * step_x + randf_range(-3.5, 3.5),
				target_box.position.y + (r + 0.5) * step_y + randf_range(-3.5, 3.5)
			)
			positions[i] = base_pos
			
			var init_attempts = 0
			while _is_barrier_tile(positions[i]) and init_attempts < 10:
				positions[i] += Vector2(randf_range(-5.0, 5.0), randf_range(-5.0, 5.0))
				init_attempts += 1
				
			directions[i] = 3.0 # Luôn quay mặt lên sân khấu (Up)
			is_walking[i] = 0 # Đứng yên cổ vũ
			wander_timers[i] = randf_range(5.0, 25.0)
		else:
			is_vip[i] = 0
			var audience_idx = i - effective_vip_count
			var num_aud_zones = max(1, get_audience_zones().size())
			npc_assigned_zone[i] = audience_idx % num_aud_zones
			positions[i] = get_random_position_in_zone(npc_assigned_zone[i])
			var init_attempts = 0
			while (enable_stage_obstacle and stage_obstacle_rect.has_point(positions[i])) \
				or (enable_vip_area and _is_vip_area(positions[i])) \
				or _is_barrier_tile(positions[i]):
				positions[i] = get_random_position_in_zone(npc_assigned_zone[i])
				init_attempts += 1
				if init_attempts >= 15:
					break
					
			# Vùng an toàn xung quanh các Quầy (Kho Ghế, Quầy Đồ Ăn, Quầy Merch): KHÔNG giao quest cho NPC ở đây
			var near_stall = false
			var stall_nodes = get_tree().get_nodes_in_group("chair_source") + get_tree().get_nodes_in_group("food_source") + get_tree().get_nodes_in_group("merch_stall")
			for stall in stall_nodes:
				if is_instance_valid(stall):
					if positions[i].distance_to(to_local(stall.global_position)) < 220.0:
						near_stall = true
						break

			var has_q = (not near_stall) and (randf() < quest_probability)
			has_quests[i] = 1 if has_q else 0
			if has_q:
				_assign_quest(i)
				
			directions[i] = float(randi() % 3)
			is_walking[i] = 0
			wander_timers[i] = randf_range(min_idle_time, max_idle_time)

		quest_origin_positions[i] = positions[i]
		velocities[i] = Vector2.ZERO
		outfit_ids[i] = randi() % outfit_count
		is_promoted[i] = 0
		time_offsets[i] = randf() * 10.0
		flip_hs[i] = 0.0
		
		# Set initial multimesh values — tạm để hết vào buffer "back", frame
		# _process() đầu tiên sẽ tự phân lại đúng buffer theo vị trí Player.
		mm_back.multimesh.set_instance_transform_2d(i, Transform2D(0.0, positions[i]))
		mm_back.multimesh.set_instance_custom_data(i, Color(outfit_ids[i], 0.0, 0.0, time_offsets[i]))
		mm_back.multimesh.set_instance_color(i, Color(0.0, 1.0, 1.0, 1.0))
		mm_front.multimesh.set_instance_transform_2d(i, Transform2D(0.0, Vector2(-999999.0, -999999.0)))

	_setup_vip_physical_barriers()
		
	# 4. Initialize object pool
	_init_pool()
	
	# Khởi tạo sự kiện Trẻ Lạc
	call_deferred("spawn_lost_child_event")
	
	# 5. Initialize debug overlay
	_init_debug_overlay()


func _process(delta: float) -> void:
	_update_cached_zones()
	_time_accum += delta
	var stage_node = get_tree().get_first_node_in_group("concert_stage")
	var is_stage_climax: bool = (stage_node != null and "is_climax_active" in stage_node and stage_node.is_climax_active)
	var view_rect = _get_camera_view_rect()
	var player = get_node_or_null("../Player") as Node2D

	# Y của Player trong local space của CrowdManager — dùng để quyết định mỗi
	# NPC nền nên vẽ trước (mm_front) hay sau (mm_back) Player frame này.
	# Không có Player -> mặc định mọi NPC ở buffer "back".
	var player_local_y: float = INF
	if player:
		player_local_y = to_local(player.global_position).y

	var hidden_xform := Transform2D(0.0, Vector2(-999999.0, -999999.0))

	# Update each background NPC's wander movement
	for i in range(npc_count):
		var qdata: NPCQuestData = quest_data_map.get(i, null)
		var is_active_quest: bool = (qdata != null and qdata.state == NPCQuestData.QuestState.ACTIVE)
		var is_offered_quest: bool = (qdata != null and qdata.state == NPCQuestData.QuestState.OFFERED)

		if is_active_quest:
			# Lần đầu tiên quest chuyển sang ACTIVE -> Chốt ngay vị trí HIỆN TẠI làm vị trí đứng yên (không tele về vị trí lúc spawn)!
			if quest_origin_locked[i] == 0:
				if is_promoted[i] == 1 and promoted_nodes.has(i) and is_instance_valid(promoted_nodes[i]):
					quest_origin_positions[i] = promoted_nodes[i].position
				else:
					quest_origin_positions[i] = positions[i]
				quest_origin_locked[i] = 1

			is_walking[i] = 0
			velocities[i] = Vector2.ZERO
			positions[i] = quest_origin_positions[i]
			if is_promoted[i] == 1 and promoted_nodes.has(i):
				var node = promoted_nodes[i]
				if is_instance_valid(node):
					node.base_position = quest_origin_positions[i]
		elif is_vip[i] == 1:
			wander_timers[i] -= delta
			if wander_timers[i] <= 0.0:
				is_walking[i] = 0
				velocities[i] = Vector2.ZERO
				directions[i] = 3.0 # Always face UP (stage)
				wander_timers[i] = randf_range(5.0, 20.0)
		else:
			quest_origin_locked[i] = 0
			if is_stage_climax:
				# Khi có hiệu ứng cao trào diễn concert: Normal NPCs đứng yên và quay mặt lên sân khấu (Up = 3.0)!
				is_walking[i] = 0
				velocities[i] = Vector2.ZERO
				directions[i] = 3.0
			else:
				wander_timers[i] -= delta
				if wander_timers[i] <= 0.0:
					if is_walking[i] == 1:
						# Transition to idle
						is_walking[i] = 0
						velocities[i] = Vector2.ZERO
						wander_timers[i] = randf_range(min_idle_time, max_idle_time)
					else:
						# Transition to walking
						is_walking[i] = 1
						var angle = randf() * TAU
						var dir_vec = Vector2.from_angle(angle)
						velocities[i] = dir_vec * npc_speed
						wander_timers[i] = randf_range(min_wander_time, max_wander_time)
						
						_update_direction_states(i, dir_vec)
					
		# Fix: Nếu Audience NPC (is_vip == 0) lỡ nằm ở khu vực bị cấm (VIP area / barrier tile / ngoài zone của mình), lập tức đẩy ra ngoài
		if is_vip[i] == 0:
			if enable_vip_area and _is_vip_area(positions[i]):
				_handle_vip_obstacle(i)
			elif _is_barrier_tile(positions[i]):
				positions[i] = _push_out_of_barrier_for_npc(i, positions[i])
				var angle = randf() * TAU
				velocities[i] = Vector2.from_angle(angle) * npc_speed
				_update_direction_states(i, velocities[i])
			elif not is_in_assigned_audience_zone(i, positions[i]):
				positions[i] = _clamp_to_assigned_zone(i, positions[i])
				var angle = randf() * TAU
				velocities[i] = Vector2.from_angle(angle) * npc_speed
				_update_direction_states(i, velocities[i])

		if is_walking[i] == 1:
			var next_pos = positions[i] + velocities[i] * delta
			var is_blocked = _is_barrier_tile(next_pos) \
				or (is_vip[i] == 0 and enable_vip_area and _is_vip_area(next_pos)) \
				or (is_vip[i] == 0 and not is_in_assigned_audience_zone(i, next_pos))
			
			if is_blocked:
				velocities[i] = -velocities[i]
				_update_direction_states(i, velocities[i])
			else:
				positions[i] = next_pos
			
			# Nếu là quest OFFERED (chưa nhận), giới hạn bán kính di chuyển tối đa 35px quanh vị trí ban đầu
			if is_offered_quest:
				var dist_from_origin = positions[i].distance_to(quest_origin_positions[i])
				if dist_from_origin > 35.0:
					positions[i] = quest_origin_positions[i] + (positions[i] - quest_origin_positions[i]).limit_length(35.0)
					velocities[i] = -velocities[i]
					_update_direction_states(i, velocities[i])

			# Boundaries check for assigned Audience Zone
			if is_vip[i] == 0 and not is_in_assigned_audience_zone(i, positions[i]):
				velocities[i] = -velocities[i]
				_update_direction_states(i, velocities[i])

			# Stage obstacle check (chỉ ngăn không cho đi lên sàn sân khấu, đi tự do xung quanh)
			if enable_stage_obstacle and stage_obstacle_rect.has_point(positions[i]):
				_handle_stage_obstacle(i)

	for i in range(npc_count):
		# Skip multimesh instance updates if promoted (since the real Node is rendering it instead)
		if is_promoted[i] == 1:
			continue
			
		# Offscreen optimization & state cache check (giảm 85% C++ calls cho 60 FPS)
		var in_view = view_rect.has_point(positions[i])
		var use_front_buffer: bool = (positions[i].y > player_local_y) and (is_vip[i] == 0)
		var front_flag: int = 1 if use_front_buffer else 0
		
		if not in_view:
			if prev_buffer_front[i] != 255:
				mm_back.multimesh.set_instance_transform_2d(i, hidden_xform)
				mm_front.multimesh.set_instance_transform_2d(i, hidden_xform)
				prev_buffer_front[i] = 255
			continue
			
		var render_pos = positions[i]
		if is_stage_climax:
			var jump_offset = -abs(sin((_time_accum * 6.5) + float(i) * 0.15)) * 6.0
			render_pos.y += jump_offset

		var state_changed = is_stage_climax or (positions[i] != prev_positions[i]) \
			or (directions[i] != prev_directions[i]) \
			or (is_walking[i] != prev_is_walking[i]) \
			or (front_flag != prev_buffer_front[i])
			
		if state_changed:
			prev_positions[i] = positions[i]
			prev_directions[i] = directions[i]
			prev_is_walking[i] = is_walking[i]
			prev_buffer_front[i] = front_flag
			
			var xform := Transform2D(0.0, render_pos)
			var custom_data := Color(outfit_ids[i], float(is_walking[i]), directions[i], time_offsets[i])
			var inst_color := Color(flip_hs[i], 1.0, 1.0, 1.0)

			if use_front_buffer:
				mm_front.multimesh.set_instance_transform_2d(i, xform)
				mm_front.multimesh.set_instance_custom_data(i, custom_data)
				mm_front.multimesh.set_instance_color(i, inst_color)
				mm_back.multimesh.set_instance_transform_2d(i, hidden_xform)
			else:
				mm_back.multimesh.set_instance_transform_2d(i, xform)
				mm_back.multimesh.set_instance_custom_data(i, custom_data)
				mm_back.multimesh.set_instance_color(i, inst_color)
				mm_front.multimesh.set_instance_transform_2d(i, hidden_xform)

	# Tự động xuất hiện Trẻ Lạc ngẫu nhiên định kỳ (45s)
	_lost_child_spawn_timer += delta
	if _lost_child_spawn_timer >= lost_child_interval:
		_lost_child_spawn_timer = 0.0
		if get_tree().get_nodes_in_group("lost_child_npc").is_empty():
			spawn_lost_child_event()

	# Run promotion/demotion logic if the player is active
	if player:
		_check_promote_demote(player)
		_apply_separations(to_local(player.global_position))
		
	# Update debug overlay
	if debug_label:
		debug_label.text = "FPS: %d\nNPCs: %d\nPromoted: %d\nDensity quanh player: %d" % [Engine.get_frames_per_second(), npc_count, promoted_nodes.size(), _last_crowd_density]


const PIXEL_MART_FOODS := [
	{"name": "Chuối tươi", "icon": "res://Sprites/Pixel_Mart/banana.png"},
	{"name": "Bánh Cookies", "icon": "res://Sprites/Pixel_Mart/cookies.png"},
	{"name": "Nước cam ép", "icon": "res://Sprites/Pixel_Mart/orange_juice.png"},
	{"name": "Bim bim khoai tây", "icon": "res://Sprites/Pixel_Mart/potatochip_yellow.png"},
	{"name": "Nước ngọt lon", "icon": "res://Sprites/Pixel_Mart/soft_drink_red.png"},
	{"name": "Kem dâu tây", "icon": "res://Sprites/Pixel_Mart/strawberry_ice_cream.png"},
	{"name": "Socola sữa", "icon": "res://Sprites/Pixel_Mart/milk_chocolate.png"},
	{"name": "Nước suối", "icon": "res://Sprites/Pixel_Mart/water.png"},
	{"name": "Ca cao nóng", "icon": "res://Sprites/Pixel_Mart/hot_cocoa_mix.png"},
	{"name": "Bánh Snack", "icon": "res://Sprites/Pixel_Mart/snack1.png"},
	{"name": "Kẹo cao su", "icon": "res://Sprites/Pixel_Mart/bubble_gum.png"},
	{"name": "Thanh năng lượng", "icon": "res://Sprites/Pixel_Mart/energy_bar.png"},
	{"name": "Sữa chua", "icon": "res://Sprites/Pixel_Mart/plain_yogurt.png"},
	{"name": "Mứt dâu", "icon": "res://Sprites/Pixel_Mart/jam_strawberry.png"},
	{"name": "Kẹo gôm", "icon": "res://Sprites/Pixel_Mart/candy_bar.png"},
	{"name": "Hộp sữa tươi", "icon": "res://Sprites/Pixel_Mart/milk_pack.png"}
]

func _assign_quest(npc_idx: int) -> void:
	var quest = NPCQuestData.new()
	quest.quest_id = "quest_%d" % npc_idx
	
	var quest_roll = randf()
	if quest_roll < 0.50:
		# Quest 1: Food Delivery (50%)
		var food_info: Dictionary = PIXEL_MART_FOODS[randi() % PIXEL_MART_FOODS.size()]
		quest.quest_type = NPCQuestData.QuestType.FOOD_DELIVERY
		quest.is_item_picked_up = false
		quest.title = "Giao %s" % food_info["name"]
		quest.description = "Lấy giúp tôi 1 phần %s từ quầy phục vụ trước khi nguội!" % food_info["name"]
		quest.item_icon_path = food_info["icon"]
		quest.time_limit = randf_range(30.0, 45.0)
	else:
		# Quest 2: Chair Carry (50%)
		quest.quest_type = NPCQuestData.QuestType.SEAT_FINDER
		quest.is_item_picked_up = false
		quest.title = "Cần 1 chiếc ghế #%d" % npc_idx
		quest.description = "Tôi bị mỏi chân quá, hãy chạy qua Kho Ghế lấy 1 chiếc ghế mang tới đây giúp tôi!"
		quest.time_limit = randf_range(30.0, 45.0)
		
	quest_data_map[npc_idx] = quest





func _update_direction_states(i: int, dir_vec: Vector2) -> void:
	if is_vip[i] == 1:
		directions[i] = 3.0 # VIP NPC LUÔN quay mặt lên sân khấu (Up)
		flip_hs[i] = 0.0
		return
		
	if dir_vec.length_squared() < 0.1:
		return # Giữ nguyên hướng nhìn hiện tại khi dừng/idle
		
	if abs(dir_vec.x) > abs(dir_vec.y):
		directions[i] = 1.0 if dir_vec.x > 0.0 else 2.0 # 1.0 = Right, 2.0 = Left
	else:
		directions[i] = 0.0 if dir_vec.y > 0.0 else 3.0 # 0.0 = Down, 3.0 = Up
	flip_hs[i] = 0.0


## Resistance đám đông: NPC nền chỉ nhường RẤT NHẸ (không bị đẩy bay), đồng
## thời đo mật độ NPC quanh player để player.gd tự làm chậm tốc độ chính nó.
func _apply_separations(player_local_pos: Vector2) -> void:
	var dt := get_process_delta_time()
	var density := 0

	# --- 1. Player → NPC: nhường nhẹ + đo mật độ ---
	for i in range(npc_count):
		if is_promoted[i] == 1:
			continue
		var diff: Vector2 = positions[i] - player_local_pos
		var dist: float = diff.length()
		if dist < crowd_resistance_radius and dist > 0.5:
			density += 1
			var nudge: float = (1.0 - dist / crowd_resistance_radius) * npc_yield_strength
			var push_dir = diff / dist
			var new_pos = positions[i] + push_dir * nudge * dt
			
			if is_vip[i] == 1:
				positions[i] = new_pos
				if not _is_vip_area(positions[i]):
					_handle_vip_obstacle(i)
			else:
				positions[i] = _clamp_to_assigned_zone(i, new_pos)
				if enable_vip_area and _is_vip_area(positions[i]):
					_handle_vip_obstacle(i)

	_last_crowd_density = density

	# --- 2. O(1) Spatial Hash Grid: NPC ↔ NPC Giãn cách & Steer-Right tự nhiên ---
	var cell_size: float = 24.0 # Kích thước ô lưới cá nhân
	var grid: Dictionary = {} # Key Vector2i -> Array[int]
	
	for i in range(npc_count):
		if is_promoted[i] == 1:
			continue
		var gx = int(floor(positions[i].x / cell_size))
		var gy = int(floor(positions[i].y / cell_size))
		var key = Vector2i(gx, gy)
		if not grid.has(key):
			grid[key] = []
		grid[key].append(i)

	var max_separation: float = 20.0 # Bán kính né tránh tự nhiên (20px)
	
	for key in grid.keys():
		var cell_npcs: Array = grid[key]
		var neighbor_keys = [
			key,
			key + Vector2i(1, 0), key + Vector2i(0, 1), key + Vector2i(1, 1), key + Vector2i(-1, 1)
		]
		for nkey in neighbor_keys:
			if not grid.has(nkey):
				continue
			var neighbor_npcs: Array = grid[nkey]
			for i in cell_npcs:
				for j in neighbor_npcs:
					if i >= j:
						continue
						
					var diff: Vector2 = positions[i] - positions[j]
					var dist: float = diff.length()
					
					if dist < max_separation and dist > 0.1:
						var push_dir: Vector2 = diff / dist
						var force: float = (max_separation - dist) * 22.0 * dt
						var push: Vector2 = push_dir * force
						
						# Logic nhường đường né sang bên phải khi 2 NPC đi đâm đầu vào nhau
						if is_walking[i] == 1 and is_walking[j] == 1:
							var move_i = velocities[i].normalized()
							var move_j = velocities[j].normalized()
							if move_i.dot(move_j) < -0.2: # Đối đầu nhau
								var steer_right = Vector2(-push_dir.y, push_dir.x) * 10.0 * dt
								push += steer_right

						# Đẩy nhẹ 2 NPC ra xa nhau, không cho đè đè lớp lên nhau
						if is_vip[i] == 0:
							var next_i = positions[i] + push
							if not _is_barrier_tile(next_i):
								positions[i] = _clamp_to_assigned_zone(i, next_i)
						if is_vip[j] == 0:
							var next_j = positions[j] - push
							if not _is_barrier_tile(next_j):
								positions[j] = _clamp_to_assigned_zone(j, next_j)

	# --- 3. NPC Tương tác (Promoted NPC) dạt NPC đám đông ra xung quanh ---
	for p_idx in promoted_nodes.keys():
		var p_node = promoted_nodes[p_idx]
		if is_instance_valid(p_node) and p_node.visible:
			var p_pos = p_node.position
			var gx = int(floor(p_pos.x / cell_size))
			var gy = int(floor(p_pos.y / cell_size))
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var key = Vector2i(gx + dx, gy + dy)
					if grid.has(key):
						for i in grid[key]:
							var diff = positions[i] - p_pos
							var dist = diff.length()
							if dist < 22.0 and dist > 0.1:
								var push = (diff / dist) * (22.0 - dist) * 18.0 * dt
								if is_vip[i] == 0:
									var next_i = positions[i] + push
									if not _is_barrier_tile(next_i):
										positions[i] = _clamp_to_assigned_zone(i, next_i)


## Gọi bởi player.gd mỗi frame để biết phải đi chậm bao nhiêu khi ở giữa đám
## đông NPC nền. 1.0 = tốc độ bình thường, nhỏ hơn = chậm hơn (không chặn cứng).
func get_crowd_slowdown() -> float:
	return clamp(1.0 - float(_last_crowd_density) * slowdown_per_npc, min_speed_multiplier, 1.0)


func get_random_outfit_sprite_frames() -> SpriteFrames:
	if outfit_sprite_frames.size() > 0:
		var valid_frames: Array[SpriteFrames] = []
		for sf in outfit_sprite_frames:
			if sf != null:
				valid_frames.append(sf)
		if valid_frames.size() > 0:
			return valid_frames[randi() % valid_frames.size()]
	return null



func _get_camera_view_rect() -> Rect2:
	var viewport = get_viewport()
	if viewport == null:
		return Rect2(-1000, -1000, 2000, 2000)
		
	var screen_rect = viewport.get_visible_rect()
	var canvas_transform = viewport.canvas_transform
	var screen_to_world = canvas_transform.affine_inverse()
	
	var top_left_world = screen_to_world * Vector2.ZERO
	var bottom_right_world = screen_to_world * screen_rect.size
	
	# Convert world coordinates to local coordinates of CrowdManager
	var top_left = to_local(top_left_world)
	var bottom_right = to_local(bottom_right_world)
	
	return Rect2(top_left, bottom_right - top_left).grow(200.0)


func _get_character_texture_paths() -> Array[String]:
	var paths: Array[String] = []
	var base_dir = "res://Sprites/RPG Top Down Characters"
	var dir = DirAccess.open(base_dir)
	if dir:
		dir.list_dir_begin()
		var sub_name = dir.get_next()
		while sub_name != "":
			if dir.current_is_dir() and not sub_name.begins_with("."):
				var sub_lower = sub_name.to_lower()
				var is_excluded = false
				for kw in excluded_character_keywords:
					if not kw.is_empty() and sub_lower.contains(kw.to_lower()):
						is_excluded = true
						break
						
				if not is_excluded:
					var sub_path = base_dir + "/" + sub_name
					var sub_dir = DirAccess.open(sub_path)
					if sub_dir:
						sub_dir.list_dir_begin()
						var file_name = sub_dir.get_next()
						while file_name != "":
							if not sub_dir.current_is_dir() and file_name.ends_with(".png") and not file_name.ends_with("_shadow.png") and not file_name.ends_with(".import"):
								paths.append(sub_path + "/" + file_name)
								break
							file_name = sub_dir.get_next()
						sub_dir.list_dir_end()
			sub_name = dir.get_next()
		dir.list_dir_end()
			
	paths.sort()
	return paths


func _build_sprite_frames_from_texture(char_tex: Texture2D) -> SpriteFrames:
	var sf = SpriteFrames.new()
	sf.remove_animation("default")
	
	# RPG Top Down Characters PNG row layout (8 rows of 32px):
	# Row 0 (y=0): Down, Row 1 (y=32): Right, Row 2 (y=64): Left, Row 3 (y=96): Up
	# Row 4 (y=128): Walk Down, Row 5 (y=160): Walk Right, Row 6 (y=192): Walk Left, Row 7 (y=224): Walk Up
	var anims = {
		"idle_down": 0,
		"idle_right": 32,
		"idle_left": 64,
		"idle_up": 96,
		"walk_down": 128,
		"walk_right": 160,
		"walk_left": 192,
		"walk_up": 224,
	}
	
	for anim_name in anims.keys():
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, 6.0)
		sf.set_animation_loop(anim_name, true)
		
		var y_pos = anims[anim_name]
		for col in range(4):
			var atlas_sub = AtlasTexture.new()
			atlas_sub.atlas = char_tex
			atlas_sub.region = Rect2(col * 32, y_pos, 32, 32)
			sf.add_frame(anim_name, atlas_sub)
			
	return sf


func _create_dynamic_atlas() -> Texture2D:
	outfit_texture_paths = _get_character_texture_paths()
	outfit_sprite_frames.clear()
	
	if outfit_texture_paths.size() > 0:
		outfit_count = outfit_texture_paths.size()
	
	var atlas_height = 256 * outfit_count
	var atlas_img = Image.create(128, atlas_height, false, Image.FORMAT_RGBA8)
	
	var src_width = 128
	
	for outfit_id in range(outfit_count):
		var char_path = ""
		if outfit_id < outfit_texture_paths.size():
			char_path = outfit_texture_paths[outfit_id]
			
		var char_tex: Texture2D = null
		if not char_path.is_empty() and ResourceLoader.exists(char_path):
			char_tex = load(char_path)
			
		# Fallback to default asset sheet if needed
		if char_tex == null:
			var fallback_path = "res://16x32/16x32 Idle-Sheet.png"
			if ResourceLoader.exists(fallback_path):
				char_tex = load(fallback_path)
				
		if char_tex == null:
			push_error("Failed to load spritesheet for outfit %d" % outfit_id)
			outfit_sprite_frames.append(null)
			continue
			
		# Store pre-built SpriteFrames for promoted interactive NPCs
		var sf = _build_sprite_frames_from_texture(char_tex)
		outfit_sprite_frames.append(sf)
		
		var char_img = char_tex.get_image()
		var y_offset = outfit_id * 256
		
		# Copy all 8 rows (256px) directly from char_img into atlas_img (0=Down, 1=Right, 2=Left, 3=Up, 4=WkDn, 5=WkRt, 6=WkLf, 7=WkUp)
		var copy_height = min(256, char_img.get_height())
		var copy_width = min(src_width, char_img.get_width())
		atlas_img.blit_rect(char_img, Rect2i(0, 0, copy_width, copy_height), Vector2i(0, y_offset))
			
	var texture = ImageTexture.create_from_image(atlas_img)
	return texture


func _init_pool() -> void:
	for i in range(pool_size):
		var npc = interactive_npc_scene.instantiate()
		add_child(npc)
		
		npc.visible = false
		npc.process_mode = Node.PROCESS_MODE_DISABLED
		npc.collision_layer = 0
		npc.collision_mask = 0
		
		npc_pool.append(npc)


func _get_node_from_pool() -> CharacterBody2D:
	for npc in npc_pool:
		if npc.process_mode == Node.PROCESS_MODE_DISABLED:
			return npc
	# Expand pool dynamically if full
	var npc = interactive_npc_scene.instantiate()
	add_child(npc)
	npc_pool.append(npc)
	return npc


func _return_node_to_pool(npc: CharacterBody2D) -> void:
	npc.visible = false
	npc.process_mode = Node.PROCESS_MODE_DISABLED
	npc.collision_layer = 0
	npc.collision_mask = 0


var merch_buyers_map: Dictionary = {}
var lost_child_parents_map: Dictionary = {}
var _lost_child_spawn_timer: float = 0.0
@export var lost_child_interval: float = 45.0

func setup_parents_for_child(child: LostChildNPC) -> void:
	if not child or not is_instance_valid(child):
		return
		
	var child_local_pos = to_local(child.global_position)
	var parent_candidates: Array[int] = []
	for i in range(npc_count):
		if has_quests[i] == 0 and is_vip[i] == 0:
			var d = positions[i].distance_to(child_local_pos)
			if d >= 220.0 and d <= 650.0:
				parent_candidates.append(i)
				
	var parent_idx = -1
	if parent_candidates.size() > 0:
		parent_idx = parent_candidates[randi() % parent_candidates.size()]
		lost_child_parents_map[parent_idx] = true
		child.parent_npc_idx = parent_idx
		child.parent_global_pos = to_global(positions[parent_idx])
		if child.quest_data:
			child.quest_data.parent_npc_idx = parent_idx
			child.quest_data.parent_global_pos = child.parent_global_pos
			
		_promote_npc(parent_idx)
		print("[CrowdManager] Đã gắn Ba Mẹ cho Trẻ Lạc tại vị trí: ", child.parent_global_pos)

func spawn_lost_child_event() -> void:
	if get_tree().get_nodes_in_group("lost_child_npc").size() > 0:
		return

	var child_scene = load("res://Scene/lost_child_npc.tscn")
	if not child_scene:
		return
		
	var player = get_tree().get_first_node_in_group("player") as Node2D
	var spawn_pos = get_random_position_in_zone(0)
	if player:
		var p_local = to_local(player.global_position)
		var num_zones = max(1, get_audience_zones().size())
		for attempt in range(30):
			var rand_zone = randi() % num_zones
			var pos = get_random_position_in_zone(rand_zone)
			var d = pos.distance_to(p_local)
			if d >= 180.0 and d <= 500.0 and not _is_barrier_tile(pos):
				spawn_pos = pos
				break

	var child_instance = child_scene.instantiate() as LostChildNPC
	var world_node = get_parent()
	if world_node:
		child_instance.scale = Vector2(3, 3)
		world_node.add_child(child_instance)
		child_instance.global_position = to_global(spawn_pos)
	else:
		add_child(child_instance)
		child_instance.global_position = to_global(spawn_pos)

	setup_parents_for_child(child_instance)
	print("[CrowdManager] Đã xuất hiện Trẻ Lạc ngẫu nhiên tại vị trí Global: ", child_instance.global_position)

func assign_merch_buyers(quest: NPCQuestData, count: int) -> void:
	merch_buyers_map.clear()
	var candidates: Array[int] = []
	var player = get_tree().get_first_node_in_group("player") as Node2D
	var player_local_pos = to_local(player.global_position) if player else Vector2.ZERO
	
	for i in range(npc_count):
		if has_quests[i] == 0 and is_vip[i] == 0:
			# Không biến các NPC đang đứng ngay sát bên Player thành người mua merch để tránh mua luôn lập tức
			if player == null or positions[i].distance_to(player_local_pos) > 150.0:
				candidates.append(i)
	candidates.shuffle()
	
	var assigned_count = min(count, candidates.size())
	for k in range(assigned_count):
		var npc_idx = candidates[k]
		merch_buyers_map[npc_idx] = true
		quest.merch_buyer_indices.append(npc_idx)
		
		# Nếu NPC này đang được promote -> Cập nhật trực tiếp
		if is_promoted[npc_idx] == 1 and promoted_nodes.has(npc_idx):
			var node = promoted_nodes[npc_idx]
			if is_instance_valid(node):
				node.is_merch_buyer = true
				node.update_quest_indicator()

func clear_merch_buyer(npc_idx: int) -> void:
	merch_buyers_map.erase(npc_idx)
	if is_promoted[npc_idx] == 1 and promoted_nodes.has(npc_idx):
		var node = promoted_nodes[npc_idx]
		if is_instance_valid(node):
			node.is_merch_buyer = false
			node.update_quest_indicator()

func _check_promote_demote(player: Node2D) -> void:
	var player_local_pos = to_local(player.global_position)
	
	# 1. Promote NPCs with quests OR marked as merch buyers OR parents of lost child close to the player
	for i in range(npc_count):
		if (has_quests[i] == 1 or merch_buyers_map.has(i) or lost_child_parents_map.has(i)) and is_promoted[i] == 0:
			var dist = positions[i].distance_to(player_local_pos)
			if dist < promote_radius:
				_promote_npc(i)
				
	# 2. Demote promoted NPCs that are far from the player (and not yet interacted with)
	var promoted_indices = promoted_nodes.keys()
	for i in promoted_indices:
		var npc_node = promoted_nodes[i]
		if is_instance_valid(npc_node):
			var dist = npc_node.position.distance_to(player_local_pos)
			if dist > demote_radius:
				if not npc_node.is_interacted and not npc_node.is_merch_buyer and not npc_node.is_parent_npc:
					_demote_npc(i)


func _promote_npc(i: int) -> void:
	var npc_node = _get_node_from_pool()
	if npc_node == null:
		push_warning("No available NPC node in pool!")
		return
		
	# Match local position (since both CrowdManager and npc_node are in the same local space)
	if _is_barrier_tile(positions[i]):
		positions[i] = _push_out_of_barrier(positions[i])
	npc_node.position = positions[i]
	
	# Determine direction and flip
	var dir_str = "down"
	var flip = false
	if is_vip[i] == 1:
		dir_str = "up"
	elif directions[i] == 1.0:
		dir_str = "right"
	elif directions[i] == 2.0:
		dir_str = "left"
	elif directions[i] == 3.0:
		dir_str = "up"
	elif directions[i] == 0.0:
		dir_str = "down"
	
	var quest_data = quest_data_map.get(i, null)
	var is_buyer = merch_buyers_map.get(i, false)
	var is_parent = lost_child_parents_map.get(i, false)
	var sf = outfit_sprite_frames[outfit_ids[i]] if (outfit_ids[i] >= 0 and outfit_ids[i] < outfit_sprite_frames.size()) else null
	npc_node.setup(i, outfit_ids[i], has_quests[i] == 1, quest_data, dir_str, flip, sf)
	npc_node.is_merch_buyer = is_buyer
	npc_node.is_parent_npc = is_parent
	npc_node.update_quest_indicator()

	
	# Reconnect interaction signal cleanly
	if npc_node.interacted.is_connected(_on_npc_interacted):
		npc_node.interacted.disconnect(_on_npc_interacted)
	npc_node.interacted.connect(_on_npc_interacted)
	
	# Activate
	npc_node.visible = true
	npc_node.process_mode = Node.PROCESS_MODE_INHERIT
	npc_node.collision_layer = 2
	npc_node.collision_mask = 7
	
	promoted_nodes[i] = npc_node
	is_promoted[i] = 1
	
	# Hide from background multimesh by moving instance far off screen (cả 2 buffer)
	mm_back.multimesh.set_instance_transform_2d(i, Transform2D(0.0, Vector2(-999999.0, -999999.0)))
	mm_front.multimesh.set_instance_transform_2d(i, Transform2D(0.0, Vector2(-999999.0, -999999.0)))
	print("[CrowdManager] Promoted NPC %d at local pos %s" % [i, positions[i]])


func _demote_npc(i: int) -> void:
	var npc_node = promoted_nodes.get(i, null)
	if npc_node:
		if npc_node.interacted.is_connected(_on_npc_interacted):
			npc_node.interacted.disconnect(_on_npc_interacted)
			
		if _is_barrier_tile(npc_node.position):
			positions[i] = _push_out_of_barrier(npc_node.position)
		else:
			positions[i] = npc_node.position

		_return_node_to_pool(npc_node)
		promoted_nodes.erase(i)
		is_promoted[i] = 0
		
		# Hiện lại NPC ngay vào đúng buffer (trước/sau Player) — không chờ
		# frame _process() tiếp theo mới phân lại, tránh nhấp nháy 1 frame.
		var player = get_node_or_null("../Player") as Node2D
		var player_local_y: float = INF
		if player:
			player_local_y = to_local(player.global_position).y

		var xform := Transform2D(0.0, positions[i])
		var hidden_xform := Transform2D(0.0, Vector2(-999999.0, -999999.0))
		var use_front_buffer: bool = (positions[i].y > player_local_y) and (is_vip[i] == 0)
		if use_front_buffer:
			mm_front.multimesh.set_instance_transform_2d(i, xform)
			mm_back.multimesh.set_instance_transform_2d(i, hidden_xform)
		else:
			mm_back.multimesh.set_instance_transform_2d(i, xform)
			mm_front.multimesh.set_instance_transform_2d(i, hidden_xform)
		print("[CrowdManager] Demoted NPC %d back to background" % i)


func _on_npc_interacted(npc_idx: int) -> void:
	print("[CrowdManager] NPC %d was interacted! Stays promoted." % npc_idx)

func get_interactive_node(npc_idx: int) -> CharacterBody2D:
	return promoted_nodes.get(npc_idx, null)

func get_quest_data(i: int) -> NPCQuestData:
	return quest_data_map.get(i, null)

func _init_debug_overlay() -> void:
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	debug_label = Label.new()
	canvas_layer.add_child(debug_label)
	
	debug_label.position = Vector2(20, 20)
	var settings = LabelSettings.new()
	var custom_font = load("res://0307-LNTH-TwistyPixel.ttf")
	if custom_font:
		settings.font = custom_font
	settings.font_size = 18
	settings.font_color = Color.GREEN_YELLOW
	settings.outline_size = 4
	settings.outline_color = Color.BLACK
	debug_label.label_settings = settings

# ─── FIGHT EVENT INTEGRATION ───────────────────────────────────────────────────

## Tìm vị trí spawn ẩu đả từ 1 NPC nền ngẫu nhiên NẰM TRONG Audience Zone (chưa promoted, chưa có quest, không trong VIP)
func get_fight_spawn_position() -> Vector2:
	var aud_area = get_audience_area()
	var box_l = get_vip_box_left()
	var box_r = get_vip_box_right()
	
	var valid_indices: Array[int] = []
	for i in range(npc_count):
		if is_promoted[i] == 0 and has_quests[i] == 0 and is_vip[i] == 0:
			var pos = positions[i]
			if aud_area.has_point(pos) and not box_l.has_point(pos) and not box_r.has_point(pos):
				valid_indices.append(i)
			
	if valid_indices.size() > 0:
		var pick_idx = valid_indices[randi() % valid_indices.size()]
		return to_global(positions[pick_idx])
		
	# Fallback: lấy 1 điểm ngẫu nhiên an toàn trong Audience Zone
	var rand_x = randf_range(aud_area.position.x + 30.0, aud_area.position.x + aud_area.size.x - 30.0)
	var rand_y = randf_range(aud_area.position.y + 30.0, aud_area.position.y + aud_area.size.y - 30.0)
	return to_global(Vector2(rand_x, rand_y))

## Khóa và ẩn các NPC nền xung quanh vị trí ẩu đả để chuyển giao cho FightEvent
func occupy_crowd_for_fight(global_center_pos: Vector2, radius: float = 60.0, max_count: int = 10) -> Array[int]:
	var local_center = to_local(global_center_pos)
	var occupied: Array[int] = []
	var hidden_xform := Transform2D(0.0, Vector2(-999999.0, -999999.0))
	
	for i in range(npc_count):
		if is_promoted[i] == 0 and has_quests[i] == 0 and is_vip[i] == 0:
			if positions[i].distance_to(local_center) <= radius:
				is_promoted[i] = 1
				occupied.append(i)
				mm_back.multimesh.set_instance_transform_2d(i, hidden_xform)
				mm_front.multimesh.set_instance_transform_2d(i, hidden_xform)
				if occupied.size() >= max_count:
					break
					
	return occupied

## Trả lại các NPC nền về lại MultiMesh nền sau khi vụ ẩu đả kết thúc
func release_fight_crowd(occupied_indices: Array[int], new_global_positions: Array = []) -> void:
	var player = get_node_or_null("../Player") as Node2D
	var player_local_y: float = INF
	if player:
		player_local_y = to_local(player.global_position).y
		
	for i in range(occupied_indices.size()):
		var idx: int = occupied_indices[i]
		if idx >= 0 and idx < npc_count:
			if i < new_global_positions.size():
				positions[idx] = to_local(new_global_positions[i])
				
			if is_vip[idx] == 0:
				if enable_vip_area and _is_vip_area(positions[idx]):
					_handle_vip_obstacle(idx)
				elif _is_barrier_tile(positions[idx]):
					positions[idx] = _push_out_of_barrier(positions[idx])
				
			is_promoted[idx] = 0
			is_walking[idx] = 0
			velocities[idx] = Vector2.ZERO
			
			var xform := Transform2D(0.0, positions[idx])
			var hidden_xform := Transform2D(0.0, Vector2(-999999.0, -999999.0))
			var use_front_buffer: bool = (positions[idx].y > player_local_y) and (is_vip[idx] == 0)
			if use_front_buffer:
				mm_front.multimesh.set_instance_transform_2d(idx, xform)
				mm_back.multimesh.set_instance_transform_2d(idx, hidden_xform)
			else:
				mm_back.multimesh.set_instance_transform_2d(idx, xform)
				mm_front.multimesh.set_instance_transform_2d(idx, hidden_xform)

## Xử lý đẩy NPC nền ra khỏi rìa gần nhất của Sân Khấu khi lỡ đi vào
func _handle_stage_obstacle(idx: int) -> void:
	if not enable_stage_obstacle or not stage_obstacle_rect.has_point(positions[idx]):
		return
	
	var pos: Vector2 = positions[idx]
	var dist_left: float = pos.x - stage_obstacle_rect.position.x
	var dist_right: float = (stage_obstacle_rect.position.x + stage_obstacle_rect.size.x) - pos.x
	var dist_top: float = pos.y - stage_obstacle_rect.position.y
	var dist_bottom: float = (stage_obstacle_rect.position.y + stage_obstacle_rect.size.y) - pos.y
	
	var min_dist: float = minf(minf(dist_left, dist_right), minf(dist_top, dist_bottom))
	
	if min_dist == dist_bottom:
		positions[idx].y = stage_obstacle_rect.position.y + stage_obstacle_rect.size.y + 2.0
	elif min_dist == dist_top:
		positions[idx].y = stage_obstacle_rect.position.y - 2.0
	elif min_dist == dist_left:
		positions[idx].x = stage_obstacle_rect.position.x - 2.0
	else:
		positions[idx].x = stage_obstacle_rect.position.x + stage_obstacle_rect.size.x + 2.0

	var angle: float = randf() * TAU
	velocities[idx] = Vector2.from_angle(angle) * npc_speed
	_update_direction_states(idx, velocities[idx])


func _is_vip_area(local_pos: Vector2) -> bool:
	if not enable_vip_area:
		return false
	var boxes = get_vip_boxes()
	for box in boxes:
		if box.has_point(local_pos):
			return true
	return false

func _handle_vip_obstacle(idx: int) -> void:
	if not enable_vip_area:
		return
	var boxes = get_vip_boxes()
	
	for box in boxes:
		if box.has_point(positions[idx]):
			var dist_left: float = positions[idx].x - box.position.x
			var dist_right: float = (box.position.x + box.size.x) - positions[idx].x
			var dist_top: float = positions[idx].y - box.position.y
			var dist_bottom: float = (box.position.y + box.size.y) - positions[idx].y
			
			var min_dist: float = minf(minf(dist_left, dist_right), minf(dist_top, dist_bottom))
			
			if min_dist == dist_bottom:
				positions[idx].y = box.position.y + box.size.y + 6.0
			elif min_dist == dist_top:
				positions[idx].y = box.position.y - 6.0
			elif min_dist == dist_left:
				positions[idx].x = box.position.x - 6.0
			else:
				positions[idx].x = box.position.x + box.size.x + 6.0
				
			var angle: float = randf() * TAU
			velocities[idx] = Vector2.from_angle(angle) * npc_speed
			_update_direction_states(idx, velocities[idx])


func _build_object_tile_rects() -> void:
	blocked_grid_cells.clear()
	for layer_path in ["../Object", "../Wall", "../barrier", "../tree", "../Tree", "../trees", "../Trees"]:
		var layer = get_node_or_null(layer_path) as TileMapLayer
		if layer == null:
			continue
			
		var is_tree_layer: bool = ("tree" in layer_path.to_lower())
		var tile_size = Vector2(layer.tile_set.tile_size) if layer.tile_set else Vector2(16.0, 16.0)
		var real_size = tile_size * layer.scale
		
		for cell in layer.get_used_cells():
			var cell_center_local = layer.map_to_local(cell)
			var cell_center_global = layer.to_global(cell_center_local)
			var cell_center_crowd = to_local(cell_center_global)
			
			var min_pos: Vector2
			var max_pos: Vector2
			
			if is_tree_layer:
				# Với Cây Cối: Tính va chạm ở GỐC CÂY theo tỉ lệ được cấu hình trong Editor Inspector
				var half_w = (real_size.x * tree_trunk_width_ratio) / 2.0
				var half_h = (real_size.y * tree_trunk_height_ratio) / 2.0
				var center_y = cell_center_crowd.y + (real_size.y * tree_trunk_y_offset)
				
				min_pos = Vector2(cell_center_crowd.x - half_w, center_y - half_h)
				max_pos = Vector2(cell_center_crowd.x + half_w, center_y + half_h)
			else:
				min_pos = cell_center_crowd - real_size / 2.0
				max_pos = cell_center_crowd + real_size / 2.0
			
			var min_gx = int(floor(min_pos.x / TILE_GRID_SIZE))
			var max_gx = int(floor(max_pos.x / TILE_GRID_SIZE))
			var min_gy = int(floor(min_pos.y / TILE_GRID_SIZE))
			var max_gy = int(floor(max_pos.y / TILE_GRID_SIZE))
			
			for gx in range(min_gx, max_gx + 1):
				for gy in range(min_gy, max_gy + 1):
					blocked_grid_cells[Vector2i(gx, gy)] = true

	_build_standalone_obstacle_cells()

func _build_standalone_obstacle_cells() -> void:
	var obstacle_nodes: Array[Node] = []
	if is_inside_tree():
		for n in get_tree().get_nodes_in_group("static_obstacle"):
			if not obstacle_nodes.has(n):
				obstacle_nodes.append(n)
			
	for path in ["../Flaggg", "../Flag", "../flag"]:
		var node = get_node_or_null(path)
		if node != null and not obstacle_nodes.has(node):
			obstacle_nodes.append(node)
			
	for node in obstacle_nodes:
		_register_node_obstacle_cells(node)

func _register_node_obstacle_cells(node: Node) -> void:
	if node == null:
		return
	var col_shapes = _find_collision_shapes(node)
	for cs in col_shapes:
		var shape2d = cs.shape
		if shape2d is RectangleShape2D:
			var rect_size: Vector2 = shape2d.size
			var half_size: Vector2 = rect_size / 2.0
			
			var g_tl: Vector2 = cs.to_global(-half_size)
			var g_br: Vector2 = cs.to_global(half_size)
			var g_tr: Vector2 = cs.to_global(Vector2(half_size.x, -half_size.y))
			var g_bl: Vector2 = cs.to_global(Vector2(-half_size.x, half_size.y))
			
			var l_tl: Vector2 = to_local(g_tl)
			var l_br: Vector2 = to_local(g_br)
			var l_tr: Vector2 = to_local(g_tr)
			var l_bl: Vector2 = to_local(g_bl)
			
			var min_pos = Vector2(min(min(l_tl.x, l_br.x), min(l_tr.x, l_bl.x)), min(min(l_tl.y, l_br.y), min(l_tr.y, l_bl.y)))
			var max_pos = Vector2(max(max(l_tl.x, l_br.x), max(l_tr.x, l_bl.x)), max(max(l_tl.y, l_br.y), max(l_tr.y, l_bl.y)))
			
			var min_gx = int(floor(min_pos.x / TILE_GRID_SIZE))
			var max_gx = int(floor(max_pos.x / TILE_GRID_SIZE))
			var min_gy = int(floor(min_pos.y / TILE_GRID_SIZE))
			var max_gy = int(floor(max_pos.y / TILE_GRID_SIZE))
			
			for gx in range(min_gx, max_gx + 1):
				for gy in range(min_gy, max_gy + 1):
					blocked_grid_cells[Vector2i(gx, gy)] = true

func _find_collision_shapes(parent: Node) -> Array[CollisionShape2D]:
	var shapes: Array[CollisionShape2D] = []
	if parent is CollisionShape2D:
		shapes.append(parent as CollisionShape2D)
	for child in parent.get_children():
		shapes.append_array(_find_collision_shapes(child))
	return shapes

func _create_merged_tilemap_collisions() -> void:
	for layer_path in ["../Object", "../Wall", "../barrier"]:
		var layer = get_node_or_null(layer_path) as TileMapLayer
		if layer == null:
			continue
			
		if layer.has_node("TileColliders"):
			continue
			
		var used_cells = layer.get_used_cells()
		if used_cells.size() == 0:
			continue
			
		var rows: Dictionary = {}
		for cell in used_cells:
			var y = cell.y
			if not rows.has(y):
				rows[y] = []
			rows[y].append(cell.x)
			
		var static_body = StaticBody2D.new()
		static_body.name = "TileColliders"
		layer.add_child(static_body)
		
		var raw_tile_size = Vector2(layer.tile_set.tile_size) if layer.tile_set else Vector2(16.0, 16.0)
		
		for y in rows.keys():
			var xs: Array = rows[y]
			xs.sort()
			
			var start_x = xs[0]
			var count = 1
			
			for k in range(1, xs.size()):
				if xs[k] == xs[k - 1] + 1:
					count += 1
				else:
					_add_strip_shape(layer, static_body, y, start_x, count, raw_tile_size)
					start_x = xs[k]
					count = 1
					
			_add_strip_shape(layer, static_body, y, start_x, count, raw_tile_size)

func _add_strip_shape(layer: TileMapLayer, static_body: StaticBody2D, y: int, start_x: int, count: int, tile_size: Vector2) -> void:
	var is_tree_layer: bool = ("tree" in layer.name.to_lower())
	var first_center = layer.map_to_local(Vector2i(start_x, y))
	var last_center = layer.map_to_local(Vector2i(start_x + count - 1, y))
	var center = (first_center + last_center) / 2.0
	var strip_width = tile_size.x * count
	var strip_height = tile_size.y
	
	var col_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	
	if is_tree_layer:
		shape.size = Vector2(strip_width * tree_trunk_width_ratio, strip_height * tree_trunk_height_ratio)
		col_shape.position = Vector2(center.x, center.y + strip_height * tree_trunk_y_offset)
	else:
		shape.size = Vector2(strip_width, strip_height)
		col_shape.position = center
		
	col_shape.shape = shape
	static_body.add_child(col_shape)

func _is_barrier_tile(local_pos: Vector2) -> bool:
	var gx = int(floor(local_pos.x / TILE_GRID_SIZE))
	var gy = int(floor(local_pos.y / TILE_GRID_SIZE))
	return blocked_grid_cells.has(Vector2i(gx, gy))

func _push_out_of_barrier(local_pos: Vector2) -> Vector2:
	if not _is_barrier_tile(local_pos):
		return local_pos
		
	for dist in [16.0, 32.0, 48.0, 64.0, 96.0, 128.0, 160.0]:
		for angle_deg in [0, 45, 90, 135, 180, 225, 270, 315]:
			var rad = deg_to_rad(float(angle_deg))
			var candidate = local_pos + Vector2(cos(rad), sin(rad)) * dist
			if not _is_barrier_tile(candidate) and not _is_vip_area(candidate) and is_in_any_audience_zone(candidate):
				return candidate
				
	return local_pos

func _push_out_of_barrier_for_npc(idx: int, local_pos: Vector2) -> Vector2:
	if not _is_barrier_tile(local_pos):
		return local_pos
		
	for dist in [16.0, 32.0, 48.0, 64.0, 96.0, 128.0, 160.0]:
		for angle_deg in [0, 45, 90, 135, 180, 225, 270, 315]:
			var rad = deg_to_rad(float(angle_deg))
			var candidate = local_pos + Vector2(cos(rad), sin(rad)) * dist
			if not _is_barrier_tile(candidate) and not _is_vip_area(candidate) and is_in_assigned_audience_zone(idx, candidate):
				return candidate
				
	return get_random_position_in_zone(npc_assigned_zone[idx])


func _update_cached_zones() -> void:
	_cached_audience_zones = _fetch_audience_zones_internal()
	_cached_vip_boxes = _fetch_vip_boxes_internal()

func _fetch_audience_zones_internal() -> Array[Rect2]:
	var zones: Array[Rect2] = []
	
	var paths = [
		audience_zone_1, audience_zone_2, audience_zone_3,
		audience_zone_4, audience_zone_5, audience_zone_6, audience_zone_7
	]
	
	for path in paths:
		if path != null and not path.is_empty():
			var node = get_node_or_null(path)
			if node:
				zones.append_array(_get_zone_rects_from_node(node))
				
	# Dynamic search for any AudienceZone subnodes under CrowdManager if paths not assigned
	if zones.size() == 0:
		for child in get_children():
			if child.name.begins_with("AudienceZone"):
				zones.append_array(_get_zone_rects_from_node(child))
				
	# Fallback to single audience_zone if unassigned
	if zones.size() == 0 and audience_zone != null and not audience_zone.is_empty():
		var node = get_node_or_null(audience_zone)
		if node:
			zones.append_array(_get_zone_rects_from_node(node))
			
	# Fallback to default rects if no nodes assigned
	if zones.size() == 0:
		zones.append(default_audience_area_1)
		zones.append(default_audience_area_2)
		
	return zones

func get_audience_zones() -> Array[Rect2]:
	if _cached_audience_zones.size() == 0:
		_cached_audience_zones = _fetch_audience_zones_internal()
	return _cached_audience_zones

func _fetch_vip_boxes_internal() -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	for path in [vip_zone_1, vip_zone_2, vip_zone_3, vip_zone_left, vip_zone_right]:
		if path != null and not path.is_empty():
			var node = get_node_or_null(path)
			if node:
				var rects = _get_zone_rects_from_node(node)
				for r in rects:
					if not boxes.has(r):
						boxes.append(r)
						
	if boxes.size() == 0:
		boxes.append(default_vip_box_1)
		boxes.append(default_vip_box_2)
		boxes.append(default_vip_box_3)
		
	return boxes

func get_vip_boxes() -> Array[Rect2]:
	if _cached_vip_boxes.size() == 0:
		_cached_vip_boxes = _fetch_vip_boxes_internal()
	return _cached_vip_boxes

func _setup_vip_physical_barriers() -> void:
	if not enable_vip_area:
		return
		
	var existing = get_node_or_null("VIPPhysicalBarriers")
	if existing:
		existing.queue_free()
		
	var vip_barrier_parent = Node2D.new()
	vip_barrier_parent.name = "VIPPhysicalBarriers"
	add_child(vip_barrier_parent)
	
	var boxes = get_vip_boxes()
	for i in range(boxes.size()):
		var box = boxes[i]
		var static_body = StaticBody2D.new()
		static_body.name = "VIPStaticBarrier_%d" % i
		static_body.collision_layer = 1
		static_body.collision_mask = 0
		
		var col_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = box.size
		col_shape.shape = rect_shape
		col_shape.position = box.position + box.size / 2.0
		
		static_body.add_child(col_shape)
		vip_barrier_parent.add_child(static_body)

func _get_zone_rects_from_node(node: Node) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if node == null:
		return rects
		
	var shape_nodes = node.find_children("", "CollisionShape2D", true, false)
	for shape_node in shape_nodes:
		var col_shape = shape_node as CollisionShape2D
		if col_shape and col_shape.shape is RectangleShape2D:
			var rect_shape = col_shape.shape as RectangleShape2D
			var sz = rect_shape.size
			var gpos = col_shape.global_position
			var lpos = to_local(gpos)
			rects.append(Rect2(lpos - sz / 2.0, sz))
			
	if rects.size() == 0 and node is Node2D:
		var lpos = to_local(node.global_position)
		rects.append(Rect2(lpos - Vector2(100, 100), Vector2(200, 200)))
		
	return rects

func is_in_any_audience_zone(local_pos: Vector2) -> bool:
	var zones = get_audience_zones()
	for zone in zones:
		if zone.has_point(local_pos):
			return true
	return false

func is_in_assigned_audience_zone(npc_idx: int, local_pos: Vector2) -> bool:
	if is_vip[npc_idx] == 1:
		return true
	var zones = get_audience_zones()
	if zones.size() == 0:
		return true
	var zone_idx = clamp(npc_assigned_zone[npc_idx], 0, zones.size() - 1)
	return zones[zone_idx].has_point(local_pos)

func _clamp_to_assigned_zone(idx: int, local_pos: Vector2) -> Vector2:
	if is_vip[idx] == 1:
		return local_pos
	var zones = get_audience_zones()
	if zones.size() == 0:
		return local_pos
	var zone_idx = clamp(npc_assigned_zone[idx], 0, zones.size() - 1)
	var rect = zones[zone_idx]
	var clamped_x = clamp(local_pos.x, rect.position.x + 5.0, rect.position.x + rect.size.x - 5.0)
	var clamped_y = clamp(local_pos.y, rect.position.y + 5.0, rect.position.y + rect.size.y - 5.0)
	return Vector2(clamped_x, clamped_y)

func get_random_position_in_zone(zone_idx: int) -> Vector2:
	var zones = get_audience_zones()
	if zones.size() == 0:
		return Vector2.ZERO
		
	var safe_idx = clamp(zone_idx, 0, zones.size() - 1)
	var target_box = zones[safe_idx]
	var rand_x = randf_range(target_box.position.x + 10.0, target_box.position.x + target_box.size.x - 10.0)
	var rand_y = randf_range(target_box.position.y + 10.0, target_box.position.y + target_box.size.y - 10.0)
	return Vector2(rand_x, rand_y)

func get_random_audience_position() -> Vector2:
	var zones = get_audience_zones()
	if zones.size() == 0:
		return Vector2.ZERO
		
	var target_box = zones[randi() % zones.size()]
	var rand_x = randf_range(target_box.position.x + 10.0, target_box.position.x + target_box.size.x - 10.0)
	var rand_y = randf_range(target_box.position.y + 10.0, target_box.position.y + target_box.size.y - 10.0)
	return Vector2(rand_x, rand_y)

func get_audience_area() -> Rect2:
	var zones = get_audience_zones()
	if zones.size() > 0:
		return zones[0]
	return default_audience_area

func get_vip_box_left() -> Rect2:
	var boxes = get_vip_boxes()
	if boxes.size() > 0:
		return boxes[0]
	return default_vip_box_left

func get_vip_box_right() -> Rect2:
	var boxes = get_vip_boxes()
	if boxes.size() > 1:
		return boxes[1]
	return default_vip_box_right

func _get_zone_rect(node: Node) -> Rect2:
	var shape_node = node.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		var rect_shape = shape_node.shape as RectangleShape2D
		var sz = rect_shape.size
		var gpos = shape_node.global_position
		var lpos = to_local(gpos)
		return Rect2(lpos - sz / 2.0, sz)
	if node is Node2D:
		var lpos = to_local(node.global_position)
		return Rect2(lpos - Vector2(100, 100), Vector2(200, 200))
	return default_vip_box_left
