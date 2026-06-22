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
@export var contact_slowdown_factor: float = 0.4

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

## Tham chiếu CrowdManager để hỏi get_crowd_slowdown() (mật độ NPC nền quanh player)
var crowd_manager: Node = null

## Hệ số tốc độ áp dụng cho FRAME KẾ TIẾP — vì slide collision của frame hiện
## tại chỉ biết được SAU KHI move_and_slide() đã chạy.
var _next_frame_contact_mult: float = 1.0

var stats: PlayerStats = null
var inventory: PlayerInventory = null

func _ready() -> void:
	add_to_group("player")
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

	# Khởi tạo Sprite placeholder cho vật phẩm mang vác để sau này User cấu hình
	var carrying_sprite = Sprite2D.new()
	carrying_sprite.name = "CarryingVisual"
	carrying_sprite.visible = false
	carrying_sprite.position = Vector2(0, -20)
	carrying_sprite.texture = load("res://icon.svg")
	carrying_sprite.scale = Vector2(0.15, 0.15)
	add_child(carrying_sprite)

# Map tên action di chuyển -> tên animation tương ứng + có cần flip_h hay không
const DIRECTION_MAP := {
	"move_up": {"anim": "up", "flip": false},
	"move_down": {"anim": "down", "flip": false},
	"move_right": {"anim": "right", "flip": false},
	"move_left": {"anim": "right", "flip": true}, # dùng animation "right" lật ngược
}

# Stack các phím di chuyển đang giữ, phần tử đầu (index 0) = phím bấm gần nhất
var held_directions: Array[String] = []

# Lưu hướng/flip cuối cùng để biết đứng yên (idle) thì quay mặt hướng nào
var last_direction: String = "down"
var last_flip: bool = false


func _unhandled_input(event: InputEvent) -> void:
	for action in DIRECTION_MAP.keys():
		if event.is_action_pressed(action):
			held_directions.erase(action)  # tránh trùng nếu auto-repeat input
			held_directions.push_front(action)
		elif event.is_action_released(action):
			held_directions.erase(action)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_try_interact()

func _try_interact() -> void:
	var npcs = get_tree().get_nodes_in_group("npc_interactive")
	var closest_npc = null
	var min_dist = 120.0 # Bán kính tối đa tính bằng pixel phù hợp với scale nhân vật 3x3
	
	for npc in npcs:
		if npc.get("is_player_nearby") == true:
			var dist = global_position.distance_to(npc.global_position)
			if dist < min_dist:
				min_dist = dist
				closest_npc = npc
				
	if closest_npc:
		closest_npc.interact()
		get_viewport().set_input_as_handled()



func _physics_process(_delta: float) -> void:
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

	# 1) Chậm theo mật độ NPC nền quanh player (resistance đám đông, không chặn cứng)
	var crowd_mult := 1.0
	if crowd_manager and crowd_manager.has_method("get_crowd_slowdown"):
		crowd_mult = crowd_manager.get_crowd_slowdown()

	# 2) Chậm khi đang ép vào NPC promoted (set ở cuối frame trước, xem dưới)
	var contact_mult := _next_frame_contact_mult
	_next_frame_contact_mult = 1.0  # reset, sẽ bị set lại nếu vẫn còn va chạm

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
	var carrying_node = get_node_or_null("CarryingVisual")
	if not carrying_node:
		return
	
	var is_carrying = false
	if inventory:
		for quest in inventory.get_active_quests():
			if quest.is_item_picked_up:
				is_carrying = true
				break
	
	carrying_node.visible = is_carrying
