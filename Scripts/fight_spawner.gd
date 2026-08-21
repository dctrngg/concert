extends Node2D
class_name FightSpawner

@export var initial_delay: float = 15.0 # Lần đầu xuất hiện sau 15 giây khởi chạy
@export var min_spawn_interval: float = 35.0 # Khoảng thời gian ngẫu nhiên 35-65s
@export var max_spawn_interval: float = 65.0
@export var enable_fights: bool = false # Tạm thời ẩn các vụ ẩu đả

var fight_scene: PackedScene = preload("res://Scene/fight_event.tscn")
var timer: Timer = null

func _ready() -> void:
	if not enable_fights:
		return

	timer = Timer.new()
	timer.one_shot = true
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	
	# Bắt đầu đếm ngược thời gian chờ lần đầu tiên
	timer.start(initial_delay)
	print("[FightSpawner] Khởi chạy! Vụ ẩu đả đầu tiên sẽ xuất hiện sau %.1fs." % initial_delay)

func _on_timer_timeout() -> void:
	if not enable_fights:
		return
	_try_spawn_fight()
	
	# Hẹn giờ ngẫu nhiên cho vụ ẩu đả tiếp theo
	var next_interval = randf_range(min_spawn_interval, max_spawn_interval)
	timer.start(next_interval)
	print("[FightSpawner] Vụ ẩu đả tiếp theo dự kiến sau %.1fs." % next_interval)

func _try_spawn_fight() -> void:
	var tree = get_tree()
	if not tree:
		return
	var existing_fights = tree.get_nodes_in_group("fight_event")
	for fight in existing_fights:
		if not fight.get("is_resolved"):
			# Đang có vụ ẩu đả chưa dẹp -> Không spawn thêm
			return
			
	# Spawn vụ ẩu đả tại vị trí của khán giả đám đông nền
	var crowd_manager = tree.get_first_node_in_group("crowd_manager")
	var spawn_pos: Vector2
	if crowd_manager and crowd_manager.has_method("get_fight_spawn_position"):
		spawn_pos = crowd_manager.get_fight_spawn_position()
	else:
		spawn_pos = Vector2(randf_range(-250.0, 350.0), randf_range(-150.0, 250.0))
	
	var fight_instance = fight_scene.instantiate() as FightEvent
	fight_instance.scale = Vector2(3, 3)
	
	var world = get_tree().current_scene
	if world:
		world.add_child(fight_instance)
		fight_instance.global_position = spawn_pos
		print("[FightSpawner] 🔥 Đã xuất hiện vụ ẩu đả mới tại vị trí global: ", spawn_pos)
