extends CharacterBody2D
## Player top-down 4 hướng, tự đổi animation theo hướng di chuyển + đi bộ/chạy.
## Node con cần có: AnimatedSprite2D (tên "AnimatedSprite2D") với các animation:
## idle_down, idle_up, idle_right, walk_down, walk_up, walk_right, run_down, run_up, run_right
## (Không có animation "_left" -> dùng flip_h để lật animation "_right" khi đi sang trái)
##
## Cách xác định hướng nhìn khi đi chéo (giống Stardew Valley):
## Vì input_vector đã normalize() nên khi đi chéo, abs(x) luôn bằng abs(y) -> so sánh độ lớn
## trục sẽ luôn ưu tiên 1 trục cố định, không tự nhiên. Thay vào đó, ta lưu lại THỨ TỰ phím
## di chuyển đang được giữ -> hướng nhìn = phím vừa bấm gần nhất còn đang giữ. Ví dụ: đang giữ
## "phải", bấm thêm "lên" -> quay mặt lên (vẫn di chuyển chéo); thả "lên" ra -> quay lại "phải".

@export var walk_speed: float = 200.0
@export var run_speed: float = 300.0
## Tốc độ còn lại (tỉ lệ) khi player đang ép vào 1 NPC promoted — KHÔNG đẩy
## NPC bay ra nữa, player tự đi chậm lại giống chen vào người thật.
@export var contact_slowdown_factor: float = 0.88

@export_group("Player Light")
@export var light_energy: float = 0.8:
	set(val):
		light_energy = val
		if is_node_ready() and _point_light:
			_point_light.energy = val
@export var light_scale: float = 3.0:
	set(val):
		light_scale = val
		if is_node_ready() and _point_light:
			_point_light.texture_scale = val

@export_group("Intro Camera Config")
## Mức zoom ban đầu khi mới vào game (ví dụ: 5.0 là cận cảnh x5, 3.0 là x3)
@export var intro_zoom_start: float = 5.0
## Mức zoom đích sau khi thu nhỏ góc nhìn (mặc định: 1.0)
@export var intro_zoom_end: float = 1.0
## Thời gian tạm dừng cận cảnh trước khi bắt đầu thu nhỏ (giây)
@export var intro_zoom_delay: float = 0.5
## Thời gian thu nhỏ góc nhìn từ start -> end (giây)
@export var intro_zoom_duration: float = 2.5

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _point_light: PointLight2D = get_node_or_null("PointLight2D")


## Tham chiếu CrowdManager để hỏi get_crowd_slowdown() (mật độ NPC nền quanh player)
var crowd_manager: Node = null

## Hệ số tốc độ áp dụng cho FRAME KẾ TIẾP — vì slide collision của frame hiện
## tại chỉ biết được SAU KHI move_and_slide() đã chạy.
var _next_frame_contact_mult: float = 1.0

var stats: PlayerStats = null
var inventory: PlayerInventory = null

func _ready() -> void:
	add_to_group("player")
	if _point_light:
		_point_light.energy = light_energy
		_point_light.texture_scale = light_scale
	crowd_manager = get_node_or_null("../CrowdManager")
	
	stats = get_node_or_null("PlayerStats")
	if not stats:
		stats = PlayerStats.new()
		stats.name = "PlayerStats"
		add_child(stats)

	inventory = get_node_or_null("PlayerInventory")
	if not inventory:
		inventory = PlayerInventory.new()
		inventory.name = "PlayerInventory"
		add_child(inventory)
		
	inventory.inventory_changed.connect(update_carrying_visuals)

	# Nạp nhân vật chính (main_cha.png) cho Main Player
	_load_player_character()

	# Khởi tạo Sprite placeholder cho vật phẩm mang vác để sau này User cấu hình
	var carrying_sprite = Sprite2D.new()
	carrying_sprite.name = "CarryingVisual"
	carrying_sprite.position = Vector2(0, -22)
	carrying_sprite.visible = false
	add_child(carrying_sprite)
	
	_start_camera_intro()
	_setup_light_occluder()

func _setup_light_occluder() -> void:
	if has_node("PlayerLightOccluder"):
		return
	var occluder = LightOccluder2D.new()
	occluder.name = "PlayerLightOccluder"
	var occ_poly = OccluderPolygon2D.new()
	occ_poly.polygon = PackedVector2Array([
		Vector2(-7, 6),
		Vector2(7, 6),
		Vector2(5, 12),
		Vector2(-5, 12)
	])
	occluder.occluder = occ_poly
	add_child(occluder)

signal camera_intro_finished

func _start_camera_intro() -> void:
	is_camera_intro_active = false
	var cam = get_node_or_null("Camera2D") as Camera2D
	if not cam:
		return
		
	cam.enabled = true
	cam.make_current()
	cam.zoom = Vector2(intro_zoom_start, intro_zoom_start)

## Kích hoạt hiệu ứng di chuyển Camera về giữa -> Đợi 3 giây -> Thu nhỏ góc nhìn Zoom về 1.0 khi bấm BẮT ĐẦU CHƠI
func start_play_camera_transition() -> void:
	var cam = get_node_or_null("Camera2D") as Camera2D
	if not cam:
		is_intro_locked = false
		camera_intro_finished.emit()
		return
		
	var tween = create_tween()
	# Bước 1: Trượt camera position & offset về lại chính giữa Player (0, 0) trong 0.65s (giữ nguyên zoom 3.0)
	tween.parallel().tween_property(cam, "position", Vector2.ZERO, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(cam, "offset", Vector2.ZERO, 0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	# Bước 2: Dừng giữ nguyên góc nhìn cận cảnh trong 3.0 giây
	tween.tween_interval(3.0)
	
	# Bước 3: Mượt mà thu nhỏ góc nhìn Camera zoom từ 3.0 về 1.0 trong 2.5 giây
	tween.tween_property(cam, "zoom", Vector2(intro_zoom_end, intro_zoom_end), intro_zoom_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	tween.tween_callback(func():
		is_intro_locked = false
		camera_intro_finished.emit()
		var tree = get_tree()
		var stage_node = tree.get_first_node_in_group("concert_stage") if tree else null
		if stage_node and stage_node.has_method("burst_confetti"):
			stage_node.burst_confetti()
	)

func _load_player_character() -> void:
	var char_path = "res://Sprites/RPG Top Down Characters/main_cha.png"
	if not ResourceLoader.exists(char_path):
		char_path = "res://Sprites/RPG Top Down Characters/Soldier/soldier.png"
		if not ResourceLoader.exists(char_path):
			return
		
	var tex = load(char_path) as Texture2D
	if not tex or not animated_sprite:
		return
		
	var sf = SpriteFrames.new()
	sf.remove_animation("default")
	
	# main_cha.png: 8 rows of 32x32 frames
	var row_map = {
		"idle_down": 0,
		"idle_left": 32,
		"idle_right": 64,
		"idle_up": 96,
		"walk_down": 128,
		"walk_left": 160,
		"walk_right": 192,
		"walk_up": 224,
		"run_down": 128,
		"run_left": 160,
		"run_right": 192,
		"run_up": 224
	}
	
	for anim_name in row_map.keys():
		sf.add_animation(anim_name)
		var is_run = anim_name.begins_with("run")
		sf.set_animation_speed(anim_name, 12.0 if is_run else 8.0)
		sf.set_animation_loop(anim_name, true)
		
		var y_pos = row_map[anim_name]
		for col in range(4):
			var atlas_sub = AtlasTexture.new()
			atlas_sub.atlas = tex
			atlas_sub.region = Rect2(col * 32, y_pos, 32, 32)
			sf.add_frame(anim_name, atlas_sub)
			
	animated_sprite.sprite_frames = sf
	animated_sprite.scale = Vector2(1.35, 1.35)

var is_intro_locked: bool = false
var is_camera_intro_active: bool = false
var is_chat_typing: bool = false
var _camera_zoom_finished: bool = false
var _dialogue_intro_finished: bool = false

# Map tên action di chuyển -> tên animation tương ứng + có cần flip_h hay không
const DIRECTION_MAP := {
	"move_up": {"anim": "up", "flip": false},
	"move_down": {"anim": "down", "flip": false},
	"move_right": {"anim": "right", "flip": false},
	"move_left": {"anim": "left", "flip": false},
}

# Stack các phím di chuyển đang giữ, phần tử đầu (index 0) = phím bấm gần nhất
var held_directions: Array[String] = []

# Lưu hướng/flip cuối cùng để biết đứng yên (idle) thì quay mặt hướng nào
var last_direction: String = "down"
var last_flip: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if is_intro_locked or is_camera_intro_active or is_chat_typing:
		return

	for action in DIRECTION_MAP.keys():
		if event.is_action_pressed(action):
			held_directions.erase(action)  # tránh trùng nếu auto-repeat input
			held_directions.push_front(action)
		elif event.is_action_released(action):
			held_directions.erase(action)

	var is_interact_press = false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_interact_press = true
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		is_interact_press = true

	if is_interact_press:
		_try_interact()

var _last_interact_msec: int = 0

func _try_interact() -> void:
	# Cooldown 350ms ngăn nhấp đúp tương tác quá nhanh gây vừa nhận vừa hoàn thành quest
	var now_msec = Time.get_ticks_msec()
	if now_msec - _last_interact_msec < 350:
		return
	_last_interact_msec = now_msec

	# Nếu đang trong mini-game fight_event thì không kích hoạt thêm tương tác mới
	var fight_event_script = load("res://Scripts/fight_event.gd")
	if fight_event_script and fight_event_script.get("active_minigame") != null:
		var active_fight = fight_event_script.active_minigame
		if is_instance_valid(active_fight) and active_fight.get("minigame_active"):
			return

	var candidates: Array[Dictionary] = []
	var max_dist = 120.0 # Bán kính tương tác tối đa (pixel)

	# 1. NPC Tương Tác (Bao gồm cả Trẻ Lạc & Khán Giả)
	for npc in get_tree().get_nodes_in_group("npc_interactive"):
		var dist = global_position.distance_to(npc.global_position)
		if dist <= max_dist or npc.get("is_player_nearby") == true:
			candidates.append({"node": npc, "dist": dist})

	# 2. Sự Cố Ẩu Đả (Fight Event - Ưu tiên hàng đầu khi đang diễn ra)
	for fight in get_tree().get_nodes_in_group("fight_event"):
		if not fight.get("is_resolved"):
			var dist = global_position.distance_to(fight.global_position)
			if dist <= 150.0 or fight.get("is_player_inside") == true:
				candidates.append({"node": fight, "dist": dist})

	# 3. Quầy Đồ Ăn (Food Source)
	for food in get_tree().get_nodes_in_group("food_source"):
		if food.get("is_player_nearby") == true:
			var dist = global_position.distance_to(food.global_position)
			if dist <= max_dist:
				candidates.append({"node": food, "dist": dist})

	# 4. Kho Ghế (Chair Source)
	for chair in get_tree().get_nodes_in_group("chair_source"):
		if chair.get("is_player_nearby") == true:
			var dist = global_position.distance_to(chair.global_position)
			if dist <= max_dist:
				candidates.append({"node": chair, "dist": dist})

	# 5. Quầy Merchandise (Merch Stall)
	for merch in get_tree().get_nodes_in_group("merch_stall"):
		if merch.get("is_player_nearby") == true:
			var dist = global_position.distance_to(merch.global_position)
			if dist <= max_dist:
				candidates.append({"node": merch, "dist": dist})

	# 6. Khu Vực Ghế (Seat Area)
	for seat in get_tree().get_nodes_in_group("seat_area"):
		if seat.get("is_player_nearby") == true:
			var dist = global_position.distance_to(seat.global_position)
			if dist <= max_dist:
				candidates.append({"node": seat, "dist": dist})

	if candidates.size() == 0:
		return

	# Kiểm tra nhu cầu lấy đồ & trạng thái đã có vật phẩm từ các quest đang kích hoạt
	var needs_chair = false
	var needs_food = false
	var needs_merch = false
	var has_any_picked_up_item = false
	var has_chair_picked_up = false

	if inventory:
		for q in inventory.get_active_quests():
			if q.is_item_picked_up:
				has_any_picked_up_item = true
				if q.quest_type == NPCQuestData.QuestType.SEAT_FINDER:
					has_chair_picked_up = true
			else:
				if q.quest_type == NPCQuestData.QuestType.SEAT_FINDER:
					needs_chair = true
				elif q.quest_type == NPCQuestData.QuestType.FOOD_DELIVERY:
					needs_food = true
				elif q.quest_type == NPCQuestData.QuestType.MERCH_SELLING:
					needs_merch = true

	var calc_bonus = func(node: Node) -> float:
		# 1. Sự cố ẩu đả luôn ưu tiên khẩn cấp hàng đầu (-180.0)
		if node.is_in_group("fight_event"):
			return -180.0
			
		# 2. ƯU TIÊN TRẢ NHIỆM VỤ (Quest Turn-In Targets) -> Bonus -140.0
		if node.is_in_group("npc_interactive"):
			var is_turn_in_target = false
			
			# NPC giao nhiệm vụ đang đợi nhận đồ ăn / ghế (hiển thị "?")
			if node.get("has_quest") == true and node.get("quest_data") != null:
				var q_data = node.get("quest_data") as NPCQuestData
				if q_data and q_data.state == NPCQuestData.QuestState.ACTIVE and q_data.is_item_picked_up:
					is_turn_in_target = true
			
			# Khán giả đang chờ mua Merch (hiển thị "🛍️")
			if node.get("is_merch_buyer") == true:
				is_turn_in_target = true
				
			# Phụ huynh đang chờ tìm con lạc (hiển thị "👨‍👩‍👧")
			if node.get("is_parent_npc") == true:
				is_turn_in_target = true
				
			if is_turn_in_target:
				return -140.0

		# Trả nhiệm vụ đặt ghế tại Khu vực ghế khi đã mang ghế trong tay
		if node.is_in_group("seat_area") and has_chair_picked_up:
			return -140.0

		# 3. ƯU TIÊN LẤY ĐỒ (Item Pickup Sources) -> Bonus -90.0
		if needs_chair and node.is_in_group("chair_source"):
			return -90.0
		if needs_food and node.is_in_group("food_source"):
			return -90.0
		if needs_merch and node.is_in_group("merch_stall"):
			return -90.0

		# 4. NPC MỜI NHẬN QUEST MỚI (New Quest Offer "!")
		if node.is_in_group("npc_interactive"):
			if node.get("has_quest") == true and node.get("quest_data") != null:
				var q_data = node.get("quest_data") as NPCQuestData
				if q_data and q_data.state == NPCQuestData.QuestState.OFFERED:
					if inventory and not inventory.has_free_slot():
						return 50.0 # Túi đầy: hạ thấp ưu tiên để tránh vô tình bấm nhầm
					elif has_any_picked_up_item:
						return -10.0 # Đang đi trả đồ: giảm ưu tiên nhận quest mới
					else:
						return -30.0 # Trạng thái rảnh rỗi

		# 5. Các đối tượng tương tác thông thường khác
		if node.is_in_group("npc_interactive"):
			return -15.0
			
		return 0.0

	candidates.sort_custom(func(a, b):
		var bonus_a = calc_bonus.call(a["node"])
		var bonus_b = calc_bonus.call(b["node"])
		return (a["dist"] + bonus_a) < (b["dist"] + bonus_b)
	)

	var closest_node = candidates[0]["node"] as Node
	if closest_node and closest_node.has_method("interact"):
		closest_node.interact()
		get_viewport().set_input_as_handled()



var shake_amount: float = 0.0
var _shake_time: float = 0.0

func apply_camera_shake(intensity: float = 8.0) -> void:
	shake_amount = max(shake_amount, intensity)

func _process(delta: float) -> void:
	_update_camera_shake(delta)

var _stage_node: Node = null

func _get_stage_node() -> Node:
	if not is_instance_valid(_stage_node):
		var tree = get_tree()
		if tree:
			_stage_node = tree.get_first_node_in_group("concert_stage")
	return _stage_node

func _update_camera_shake(delta: float) -> void:
	var cam = get_node_or_null("Camera2D") as Camera2D
	if not cam:
		return
		
	var stage_node = _get_stage_node()
	var climax_w: float = 0.0
	if stage_node and "climax_weight" in stage_node:
		climax_w = float(stage_node.get("climax_weight"))
	elif stage_node and "is_climax_active" in stage_node and stage_node.is_climax_active:
		climax_w = 1.0

	# Lực rung dồn nén tức thời từ shake_amount (bắn pháo hoa hoặc tương tác)
	var extra_shake = Vector2.ZERO
	if shake_amount > 0.0:
		shake_amount = lerp(shake_amount, 0.0, delta * 8.0)
		extra_shake = Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)

	if climax_w > 0.01:
		_shake_time += delta * lerp(12.0, 28.0, climax_w)
		# Rung nhún nhảy bùng nổ tăng/giảm mượt mà theo climax_weight (0.0 -> 1.0)
		var bass_shake = sin(_shake_time) * lerp(0.0, 6.5, climax_w)
		var random_shake = Vector2(
			randf_range(-4.5 * climax_w, 4.5 * climax_w),
			randf_range(-4.5 * climax_w, 4.5 * climax_w)
		)
		cam.offset = random_shake + Vector2(0, bass_shake) + extra_shake
	elif shake_amount > 0.0:
		cam.offset = extra_shake
	else:
		cam.offset = lerp(cam.offset, Vector2.ZERO, delta * 8.0)

var mobile_input_vector: Vector2 = Vector2.ZERO
var is_chat_typing: bool = false

func _physics_process(_delta: float) -> void:
	if is_intro_locked or is_camera_intro_active or is_chat_typing or (stats and stats.is_fainted):
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(Vector2.ZERO, false)
		if stats and stats.is_fainted:
			apply_camera_shake(1.5)
		return

	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	
	if mobile_input_vector != Vector2.ZERO:
		input_vector += mobile_input_vector
		
	input_vector = input_vector.limit_length(1.0)

	var is_running := Input.is_action_pressed("run")
	
	# Kiểm tra stamina để cho phép/ngăn sprint
	if is_running and stats:
		if stats.stamina < stats.min_stamina_to_sprint and not stats.is_sprinting:
			is_running = false
		elif stats.stamina <= 0.0:
			is_running = false
			
	if stats:
		stats.is_sprinting = is_running and input_vector != Vector2.ZERO

	var speed := run_speed if is_running else walk_speed

	# 1) Chậm theo mật độ NPC nền quanh player (resistance đám đông mượt mà)
	var crowd_mult := 1.0
	if crowd_manager and crowd_manager.has_method("get_crowd_slowdown"):
		crowd_mult = crowd_manager.get_crowd_slowdown()
		if is_running:
			# Khi Sprint (giữ nút chạy): Player chủ động rẽ đám đông -> giảm 50% ảnh hưởng cản!
			crowd_mult = lerp(crowd_mult, 1.0, 0.5)

	# 2) Chậm nhẹ khi đang ép vào NPC promoted (mượt hơn)
	var contact_mult := _next_frame_contact_mult
	_next_frame_contact_mult = 1.0

	# 3) Chậm mượt mà khi sân khấu Cao Trào (Concert Stage Climax Slowdown)
	var climax_mult := 1.0
	var stage_node = _get_stage_node()
	if stage_node:
		var climax_w = 0.0
		if "climax_weight" in stage_node:
			climax_w = float(stage_node.get("climax_weight"))
		elif "is_climax_active" in stage_node and stage_node.is_climax_active:
			climax_w = 1.0
		climax_mult = lerp(1.0, 0.62, climax_w)

	velocity = input_vector * speed * crowd_mult * contact_mult * climax_mult
	move_and_slide()

	# Khi va vào NPC promoted: KHÔNG đẩy NPC bay, chỉ báo nó "nhường nhẹ" +
	# player tự chậm lại ở frame sau (giống chen qua người thật ngoài đời)
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var collider := col.get_collider()
		if collider != null and collider.is_in_group("npc_interactive"):
			if collider.has_method("receive_press"):
				collider.receive_press(-col.get_normal())
			_next_frame_contact_mult = min(_next_frame_contact_mult, contact_slowdown_factor)

	# Đảm bảo Player không thể đi vào Khu vực VIP
	if crowd_manager and "enable_vip_area" in crowd_manager and crowd_manager.enable_vip_area:
		var p_local = crowd_manager.to_local(global_position)
		if crowd_manager.has_method("_is_vip_area") and crowd_manager._is_vip_area(p_local):
			var boxes = crowd_manager.get_vip_boxes()
			for box in boxes:
				if box.has_point(p_local):
					var dist_l = p_local.x - box.position.x
					var dist_r = (box.position.x + box.size.x) - p_local.x
					var dist_t = p_local.y - box.position.y
					var dist_b = (box.position.y + box.size.y) - p_local.y
					var min_d = minf(minf(dist_l, dist_r), minf(dist_t, dist_b))
					if min_d == dist_b:
						p_local.y = box.position.y + box.size.y + 8.0
					elif min_d == dist_t:
						p_local.y = box.position.y - 8.0
					elif min_d == dist_l:
						p_local.x = box.position.x - 8.0
					else:
						p_local.x = box.position.x + box.size.x + 8.0
					global_position = crowd_manager.to_global(p_local)

	_update_animation(input_vector, is_running)


func _update_animation(input_vector: Vector2, is_running: bool) -> void:
	# Không di chuyển -> idle theo hướng cuối cùng
	if input_vector == Vector2.ZERO:
		animated_sprite.flip_h = last_flip
		animated_sprite.play("idle_%s" % last_direction)
		return

	# Lọc bỏ phím đã ghi nhận nhưng thực tế không còn được giữ (đề phòng input bị
	# mất đồng bộ, ví dụ alt-tab/mất focus khi đang giữ phím)
	held_directions = held_directions.filter(
		func(action: String) -> bool: return Input.is_action_pressed(action)
	)

	var direction: String
	var flip: bool

	if held_directions.size() > 0:
		# Hướng nhìn = phím di chuyển vừa bấm gần nhất còn đang giữ
		var data: Dictionary = DIRECTION_MAP[held_directions[0]]
		direction = data["anim"]
		flip = data["flip"]
	else:
		# Fallback hiếm khi xảy ra (ví dụ input từ joystick analog không qua action
		# press/release rõ ràng) -> dùng logic theo độ lớn trục như cũ
		if abs(input_vector.x) > abs(input_vector.y):
			direction = "right" if input_vector.x > 0 else "left"
			flip = false
		else:
			direction = "down" if input_vector.y > 0 else "up"
			flip = false

	last_direction = direction
	last_flip = flip
	animated_sprite.flip_h = flip

	var prefix := "run" if is_running else "walk"
	animated_sprite.play("%s_%s" % [prefix, direction])


func update_carrying_visuals() -> void:
	var carrying_node = get_node_or_null("CarryingVisual") as Sprite2D
	if carrying_node:
		carrying_node.visible = false

## Hiển thị Bong Bóng Chat (Speech Bubble) trên đầu Player
func say(text: String) -> void:
	var clean = text.strip_edges()
	if clean.is_empty():
		return
		
	var old_bubble = get_node_or_null("OverheadPlayerChatBubble")
	if old_bubble:
		old_bubble.queue_free()
		
	var container = PanelContainer.new()
	container.name = "OverheadPlayerChatBubble"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.98, 0.96, 0.92, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.15, 0.55, 0.95, 1) # Blue vibrancy
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	container.add_theme_stylebox_override("panel", style)
	
	var label = Label.new()
	label.text = clean
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	var font_res = load("res://0307-LNTH-TwistyPixel.ttf") as Font
	if font_res:
		label.add_theme_font_override("font", font_res)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.1, 0.15, 0.35, 1))
	
	container.add_child(label)
	container.position = Vector2(-60, -58)
	container.z_index = 100
	
	add_child(container)
	
	container.scale = Vector2(0.6, 0.6)
	container.pivot_offset = Vector2(60, 30)
	var tween = create_tween().set_parallel(true)
	tween.tween_property(container, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(container, "modulate:a", 1.0, 0.2)
	
	var fade_tween = create_tween()
	fade_tween.tween_interval(4.0)
	fade_tween.tween_property(container, "modulate:a", 0.0, 0.5)
	fade_tween.finished.connect(func():
		if is_instance_valid(container):
			container.queue_free()
	)
