extends Node2D

@export var shader: Shader = preload("res://Scene/crowd_npc.gdshader")
@export var npc_count: int = 500
@export var quest_probability: float = 0.1
@export var promote_radius: float = 200.0
@export var demote_radius: float = 250.0
@export var outfit_count: int = 1
@export var npc_speed: float = 50.0
@export var wander_area: Rect2 = Rect2(-500, -500, 1000, 1000)

@export var min_wander_time: float = 1.0
@export var max_wander_time: float = 4.0
@export var min_idle_time: float = 2.0
@export var max_idle_time: float = 6.0

@export var pool_size: int = 30

## --- Resistance đám đông cho NPC nền (thay cho "push" cũ) ---
## KHÔNG đẩy NPC bay ra mạnh nữa. NPC nền chỉ "nhường" rất nhẹ để không đè lên
## player; cảm giác "khó đi qua đám đông" chủ yếu đến từ việc PLAYER tự bị làm
## chậm theo mật độ NPC quanh nó (xem get_crowd_slowdown(), player.gd gọi hàm
## này mỗi frame để nhân vào speed của chính nó).
## Bán kính tính mật độ NPC quanh player (local units).
@export var crowd_resistance_radius: float = 45.0
## NPC chỉ nhường nhẹ với tốc độ này (px/s) — nhỏ hơn push_strength cũ rất nhiều
@export var npc_yield_strength: float = 18.0
## Mỗi NPC nằm trong crowd_resistance_radius làm player chậm thêm bấy nhiêu (0.08 = chậm 8%)
@export var slowdown_per_npc: float = 0.08
## Tốc độ tối thiểu của player khi đám đông dày nhất (không bao giờ chặn cứng = 0)
@export var min_speed_multiplier: float = 0.45
## Khoảng cách tối thiểu giữa 2 NPC nền (separation)
@export var npc_separation_radius: float = 20.0
## Sức separation giữa NPC với nhau
@export var npc_separation_strength: float = 50.0
## Bật/tắt NPC↔NPC separation (tắt mặc định vì O(n²) tốn CPU)
@export var enable_npc_separation: bool = false

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
var outfit_ids: PackedInt32Array = PackedInt32Array()
var has_quests: PackedByteArray = PackedByteArray() # 1 = true, 0 = false
var is_promoted: PackedByteArray = PackedByteArray() # 1 = true, 0 = false
var time_offsets: PackedFloat32Array = PackedFloat32Array()
var wander_timers: PackedFloat32Array = PackedFloat32Array()
var directions: PackedFloat32Array = PackedFloat32Array() # 0.0=Down, 1.0=Right, 2.0=Up
var flip_hs: PackedFloat32Array = PackedFloat32Array() # 1.0=flip, 0.0=normal
var is_walking: PackedByteArray = PackedByteArray() # 1=walk, 0=idle

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


func _ready() -> void:
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
		quad.size = Vector2(32, 32)
		mm.mesh = quad

		mmi.multimesh = mm

	# Generate combined atlas texture dynamically (dùng chung cho cả 2 buffer)
	var atlas_tex = _create_dynamic_atlas()
	mm_back.texture = atlas_tex
	mm_front.texture = atlas_tex

	# Set shader material parameters (dùng chung 1 material cho cả 2 buffer)
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("texture_size", Vector2(128.0, 192.0 * outfit_count))
	mm_back.material = mat
	mm_front.material = mat
	
	# 2. Resize internal arrays
	positions.resize(npc_count)
	velocities.resize(npc_count)
	outfit_ids.resize(npc_count)
	has_quests.resize(npc_count)
	is_promoted.resize(npc_count)
	time_offsets.resize(npc_count)
	wander_timers.resize(npc_count)
	directions.resize(npc_count)
	flip_hs.resize(npc_count)
	is_walking.resize(npc_count)
	
	# 3. Initialize background NPCs
	for i in range(npc_count):
		positions[i] = Vector2(
			randf_range(wander_area.position.x, wander_area.position.x + wander_area.size.x),
			randf_range(wander_area.position.y, wander_area.position.y + wander_area.size.y)
		)
		velocities[i] = Vector2.ZERO
		outfit_ids[i] = randi() % outfit_count
		
		# Assign quest using weighted random
		var has_q = randf() < quest_probability
		has_quests[i] = 1 if has_q else 0
		if has_q:
			_assign_quest(i)
			
		is_promoted[i] = 0
		time_offsets[i] = randf() * 10.0
		wander_timers[i] = randf_range(min_idle_time, max_idle_time)
		directions[i] = 0.0 # Down
		flip_hs[i] = 0.0
		is_walking[i] = 0 # Idle
		
		# Set initial multimesh values — tạm để hết vào buffer "back", frame
		# _process() đầu tiên sẽ tự phân lại đúng buffer theo vị trí Player.
		mm_back.multimesh.set_instance_transform_2d(i, Transform2D(0.0, positions[i]))
		mm_back.multimesh.set_instance_custom_data(i, Color(outfit_ids[i], 0.0, 0.0, time_offsets[i]))
		mm_back.multimesh.set_instance_color(i, Color(0.0, 1.0, 1.0, 1.0))
		mm_front.multimesh.set_instance_transform_2d(i, Transform2D(0.0, Vector2(-999999.0, -999999.0)))
		
	# 4. Initialize object pool
	_init_pool()
	
	# 5. Initialize debug overlay
	_init_debug_overlay()


func _process(delta: float) -> void:
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
				
		if is_walking[i] == 1:
			positions[i] += velocities[i] * delta
			
			# Boundaries check & clamp
			if not wander_area.has_point(positions[i]):
				positions[i].x = clamp(positions[i].x, wander_area.position.x, wander_area.position.x + wander_area.size.x)
				positions[i].y = clamp(positions[i].y, wander_area.position.y, wander_area.position.y + wander_area.size.y)
				# Reverse velocity to steer away from boundary
				velocities[i] = -velocities[i]
				_update_direction_states(i, velocities[i])
				
		# Skip multimesh instance updates if promoted (since the real Node is rendering it instead)
		if is_promoted[i] == 1:
			continue
			
		# Offscreen optimization: skip detailed mesh updates if outside camera viewport
		var in_view = view_rect.has_point(positions[i])
		if in_view:
			var xform := Transform2D(0.0, positions[i])
			var custom_data := Color(outfit_ids[i], float(is_walking[i]), directions[i], time_offsets[i])
			var inst_color := Color(flip_hs[i], 1.0, 1.0, 1.0)

			# NPC có Y LỚN HƠN Player (đứng thấp hơn trên màn hình -> gần
			# camera hơn theo quy ước top-down) -> phải vẽ ĐÈ LÊN Player.
			if positions[i].y > player_local_y:
				mm_front.multimesh.set_instance_transform_2d(i, xform)
				mm_front.multimesh.set_instance_custom_data(i, custom_data)
				mm_front.multimesh.set_instance_color(i, inst_color)
				mm_back.multimesh.set_instance_transform_2d(i, hidden_xform)
			else:
				mm_back.multimesh.set_instance_transform_2d(i, xform)
				mm_back.multimesh.set_instance_custom_data(i, custom_data)
				mm_back.multimesh.set_instance_color(i, inst_color)
				mm_front.multimesh.set_instance_transform_2d(i, hidden_xform)
		else:
			# Hide off-screen instances by pushing far off the visible area
			mm_back.multimesh.set_instance_transform_2d(i, hidden_xform)
			mm_front.multimesh.set_instance_transform_2d(i, hidden_xform)

	# Run promotion/demotion logic if the player is active
	if player:
		_check_promote_demote(player)
		_apply_separations(to_local(player.global_position))
		
	# Update debug overlay
	if debug_label:
		debug_label.text = "FPS: %d\nNPCs: %d\nPromoted: %d\nDensity quanh player: %d" % [Engine.get_frames_per_second(), npc_count, promoted_nodes.size(), _last_crowd_density]


func _assign_quest(npc_idx: int) -> void:
	var quest = NPCQuestData.new()
	quest.quest_id = "quest_%d" % npc_idx
	quest.title = "Giao đồ ăn #%d" % npc_idx
	quest.description = "Giao đồ ăn nhanh từ quầy phục vụ cho tôi trước khi nguội!"
	quest.quest_type = NPCQuestData.QuestType.FOOD_DELIVERY
	quest.time_limit = 35.0
	quest_data_map[npc_idx] = quest


func _update_direction_states(i: int, dir_vec: Vector2) -> void:
	if abs(dir_vec.x) > abs(dir_vec.y):
		directions[i] = 1.0 # Right
		flip_hs[i] = 1.0 if dir_vec.x < 0.0 else 0.0
	else:
		directions[i] = 0.0 if dir_vec.y > 0.0 else 2.0 # Down or Up
		flip_hs[i] = 0.0


## Resistance đám đông: NPC nền chỉ nhường RẤT NHẸ (không bị đẩy bay), đồng
## thời đo mật độ NPC quanh player để player.gd tự làm chậm tốc độ chính nó.
func _apply_separations(player_local_pos: Vector2) -> void:
	var dt := get_process_delta_time()
	var density := 0

	# --- Player → NPC: nhường nhẹ + đo mật độ ---
	for i in range(npc_count):
		if is_promoted[i] == 1:
			continue
		var diff: Vector2 = positions[i] - player_local_pos
		var dist: float = diff.length()
		if dist < crowd_resistance_radius and dist > 0.5:
			density += 1
			# Nhường rất nhẹ, tỉ lệ nghịch với khoảng cách (càng gần càng nhường nhiều)
			var nudge: float = (1.0 - dist / crowd_resistance_radius) * npc_yield_strength
			positions[i] += diff.normalized() * nudge * dt
			# Giữ NPC trong wander_area
			positions[i].x = clamp(
				positions[i].x,
				wander_area.position.x,
				wander_area.position.x + wander_area.size.x
			)
			positions[i].y = clamp(
				positions[i].y,
				wander_area.position.y,
				wander_area.position.y + wander_area.size.y
			)

	_last_crowd_density = density

	# --- NPC ↔ NPC separation (tắt mặc định, O(n²)) ---
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


## Gọi bởi player.gd mỗi frame để biết phải đi chậm bao nhiêu khi ở giữa đám
## đông NPC nền. 1.0 = tốc độ bình thường, nhỏ hơn = chậm hơn (không chặn cứng).
func get_crowd_slowdown() -> float:
	return clamp(1.0 - float(_last_crowd_density) * slowdown_per_npc, min_speed_multiplier, 1.0)



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


func _create_dynamic_atlas() -> Texture2D:
	var atlas_height = 192 * outfit_count
	var atlas_img = Image.create(128, atlas_height, false, Image.FORMAT_RGBA8)
	
	var src_width = 128
	var row_height = 32
	
	for outfit_id in range(outfit_count):
		var idle_path = "res://16x32/%d_Idle-Sheet.png" % outfit_id
		var walk_path = "res://16x32/%d_Walk-Sheet.png" % outfit_id
		
		# Fallback to default asset sheets
		if not ResourceLoader.exists(idle_path) or not ResourceLoader.exists(walk_path):
			idle_path = "res://16x32/16x32 Idle-Sheet.png"
			walk_path = "res://16x32/16x32 Walk-Sheet.png"
			
		var idle_tex = load(idle_path)
		var walk_tex = load(walk_path)
		if idle_tex == null or walk_tex == null:
			push_error("Failed to load spritesheets for outfit %d" % outfit_id)
			continue
			
		var idle_img = idle_tex.get_image()
		var walk_img = walk_tex.get_image()
		
		var y_offset = outfit_id * 192
		
		# Copy Idle animation rows: Down (y=0), Right (y=64), Up (y=128)
		atlas_img.blit_rect(idle_img, Rect2i(0, 0, src_width, row_height), Vector2i(0, y_offset + 0))
		atlas_img.blit_rect(idle_img, Rect2i(0, 64, src_width, row_height), Vector2i(0, y_offset + 32))
		atlas_img.blit_rect(idle_img, Rect2i(0, 128, src_width, row_height), Vector2i(0, y_offset + 64))
		
		# Copy Walk animation rows: Down (y=0), Right (y=64), Up (y=128)
		atlas_img.blit_rect(walk_img, Rect2i(0, 0, src_width, row_height), Vector2i(0, y_offset + 96))
		atlas_img.blit_rect(walk_img, Rect2i(0, 64, src_width, row_height), Vector2i(0, y_offset + 128))
		atlas_img.blit_rect(walk_img, Rect2i(0, 128, src_width, row_height), Vector2i(0, y_offset + 160))
		
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


func _check_promote_demote(player: Node2D) -> void:
	var player_local_pos = to_local(player.global_position)
	
	# 1. Promote NPCs with quests that are close to the player
	for i in range(npc_count):
		if has_quests[i] == 1 and is_promoted[i] == 0:
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
				if not npc_node.is_interacted:
					_demote_npc(i)


func _promote_npc(i: int) -> void:
	var npc_node = _get_node_from_pool()
	if npc_node == null:
		push_warning("No available NPC node in pool!")
		return
		
	# Match local position (since both CrowdManager and npc_node are in the same local space)
	npc_node.position = positions[i]
	
	# Determine direction and flip
	var dir_str = "down"
	if directions[i] == 1.0:
		dir_str = "right"
	elif directions[i] == 2.0:
		dir_str = "up"
	var flip = flip_hs[i] > 0.5
	
	var quest_data = quest_data_map.get(i, null)
	npc_node.setup(i, outfit_ids[i], true, quest_data, dir_str, flip)
	
	# Reconnect interaction signal cleanly
	if npc_node.interacted.is_connected(_on_npc_interacted):
		npc_node.interacted.disconnect(_on_npc_interacted)
	npc_node.interacted.connect(_on_npc_interacted)
	
	# Activate
	npc_node.visible = true
	npc_node.process_mode = Node.PROCESS_MODE_INHERIT
	npc_node.collision_layer = 2
	npc_node.collision_mask = 3
	
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
		if positions[i].y > player_local_y:
			mm_front.multimesh.set_instance_transform_2d(i, xform)
			mm_back.multimesh.set_instance_transform_2d(i, hidden_xform)
		else:
			mm_back.multimesh.set_instance_transform_2d(i, xform)
			mm_front.multimesh.set_instance_transform_2d(i, hidden_xform)
		print("[CrowdManager] Demoted NPC %d back to background" % i)


func _on_npc_interacted(npc_idx: int) -> void:
	print("[CrowdManager] NPC %d was interacted! Stays promoted." % npc_idx)


func _init_debug_overlay() -> void:
	var canvas_layer = CanvasLayer.new()
	add_child(canvas_layer)
	
	debug_label = Label.new()
	canvas_layer.add_child(debug_label)
	
	debug_label.position = Vector2(20, 20)
	var settings = LabelSettings.new()
	settings.font_size = 18
	settings.font_color = Color.GREEN_YELLOW
	settings.outline_size = 4
	settings.outline_color = Color.BLACK
	debug_label.label_settings = settings
