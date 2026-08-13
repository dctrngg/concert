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

	# Nạp tạm nhân vật Soldier cho Main Player
	_load_soldier_character()

	# Khởi tạo Sprite placeholder cho vật phẩm mang vác để sau này User cấu hình
	var carrying_sprite = Sprite2D.new()
	carrying_sprite.name = "CarryingVisual"
	carrying_sprite.visible = false
	carrying_sprite.position = Vector2(0, -20)
	carrying_sprite.texture = load("res://icon.svg")
	carrying_sprite.scale = Vector2(0.15, 0.15)
	add_child(carrying_sprite)

	call_deferred("_play_intro_camera_zoom")

var is_camera_intro_active: bool = false
var _camera_zoom_finished: bool = false
var _dialogue_intro_finished: bool = false

func _play_intro_camera_zoom() -> void:
	var cam: Camera2D = get_node_or_null("Camera2D") as Camera2D
	if not cam:
		cam = get_viewport().get_camera_2d()
	if not cam:
		return
		
	# 🎥 Khóa di chuyển nhân vật ngắn trong lúc Camera Zoom
	is_camera_intro_active = true
	cam.zoom = Vector2(intro_zoom_start, intro_zoom_start)
	
	# 🎬 Tween zoom-out mượt từ start -> end
	var tween = create_tween()
	tween.set_parallel(false)
	if intro_zoom_delay > 0.0:
		tween.tween_interval(intro_zoom_delay)
	tween.tween_property(cam, "zoom", Vector2(intro_zoom_end, intro_zoom_end), intro_zoom_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Mở khóa di chuyển ngay khi Camera Zoom kết thúc để người chơi tự do vừa chơi vừa xem hướng dẫn
	tween.tween_callback(func():
		is_camera_intro_active = false
	)

func _load_soldier_character() -> void:
	var soldier_path = "res://Sprites/RPG Top Down Characters/Soldier/soldier.png"
	if not ResourceLoader.exists(soldier_path):
		return
		
	var tex = load(soldier_path) as Texture2D
	if not tex or not animated_sprite:
		return
		
	var sf = SpriteFrames.new()
	sf.remove_animation("default")
	
	# soldier.png: 8 rows of 32x32 frames
	var row_map = {
		"idle_down": 0,
		"idle_right": 32,
		"idle_left": 64,
		"idle_up": 96,
		"walk_down": 128,
		"walk_right": 160,
		"walk_left": 192,
		"walk_up": 224,
		"run_down": 128,
		"run_right": 160,
		"run_left": 192,
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
	if is_camera_intro_active:
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

	# 1. NPC Tương Tác
	for npc in get_tree().get_nodes_in_group("npc_interactive"):
		if npc.get("is_player_nearby") == true:
			var dist = global_position.distance_to(npc.global_position)
			if dist <= max_dist:
				candidates.append({"node": npc, "dist": dist})

	# 2. Sự Cố Ẩu Đả (Fight Event)
	for fight in get_tree().get_nodes_in_group("fight_event"):
		if fight.get("is_player_inside") == true and not fight.get("is_resolved"):
			var dist = global_position.distance_to(fight.global_position)
			if dist <= max_dist:
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

	# Sắp xếp để chọn đối tượng GẦN PLAYER NHẤT
	candidates.sort_custom(func(a, b): return a["dist"] < b["dist"])

	var closest_node = candidates[0]["node"] as Node
	if closest_node and closest_node.has_method("interact"):
		closest_node.interact()
		get_viewport().set_input_as_handled()



func _physics_process(_delta: float) -> void:
	if is_camera_intro_active:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(Vector2.ZERO, false)
		return

	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")
	input_vector = input_vector.normalized()

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

	velocity = input_vector * speed * crowd_mult * contact_mult
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
			direction = "right"
			flip = input_vector.x < 0
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
