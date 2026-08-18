extends Area2D
class_name FightEvent

@export var required_peace_progress: float = 100.0

var is_resolved: bool = false
var is_player_inside: bool = false
var quest_data: NPCQuestData = null

# Stardew Horizontal Mini-game State
static var active_minigame: FightEvent = null

var minigame_active: bool = false
var peace_progress: float = 0.0
var occupied_crowd_indices: Array[int] = []

func interact() -> void:
	start_minigame()

func start_minigame() -> void:
	if is_resolved:
		return
	if active_minigame != null and active_minigame != self and is_instance_valid(active_minigame) and active_minigame.minigame_active:
		return
	_ensure_quest_accepted()
	minigame_active = true
	active_minigame = self

const TRACK_WIDTH: float = 100.0
const BAR_WIDTH: float = 36.0 # Rộng hơn để dễ chơi hơn
const TARGET_WIDTH: float = 12.0

var bar_x: float = 30.0
var bar_velocity: float = 0.0

var target_x: float = 50.0
var target_velocity: float = 0.0
var target_timer: float = 0.0

@onready var fighter1: AnimatedSprite2D = find_child("Fighter1", true, false) as AnimatedSprite2D
@onready var fighter2: AnimatedSprite2D = find_child("Fighter2", true, false) as AnimatedSprite2D
@onready var clash_label: Label = find_child("ClashLabel", true, false) as Label
@onready var prompt_panel: Control = find_child("PromptPanel", true, false) as Control
@onready var prompt_label: Label = find_child("PromptLabel", true, false) as Label
@onready var spectators_container: Node2D = find_child("Spectators", true, false) as Node2D

# Mini-game UI Nodes
@onready var minigame_ui: Control = find_child("MinigameUI", true, false) as Control
@onready var green_bar: Control = find_child("GreenBar", true, false) as Control
@onready var chaos_target: Control = find_child("ChaosTarget", true, false) as Control
@onready var peace_bar: ProgressBar = find_child("PeaceBar", true, false) as ProgressBar

var _anim_time: float = 0.0
var _spectator_sprites: Array[AnimatedSprite2D] = []
var _wander_directions: Array[Vector2] = []
var _disperse_timer: float = 0.0

static var _cached_sprite_frames: SpriteFrames = null

static func get_npc_sprite_frames() -> SpriteFrames:
	var main_tree = Engine.get_main_loop() as SceneTree
	if main_tree:
		var crowd_managers = main_tree.get_nodes_in_group("crowd_manager")
		if crowd_managers.size() > 0 and crowd_managers[0].has_method("get_random_outfit_sprite_frames"):
			var sf = crowd_managers[0].get_random_outfit_sprite_frames()
			if sf != null:
				return sf

	if _cached_sprite_frames == null:
		var player_scene = load("res://Scene/Player.tscn")
		if player_scene:
			var player_instance = player_scene.instantiate()
			var player_sprite = player_instance.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if player_sprite and player_sprite.sprite_frames:
				_cached_sprite_frames = player_sprite.sprite_frames.duplicate()
			player_instance.queue_free()
	return _cached_sprite_frames

func _ready() -> void:
	add_to_group("fight_event")
	y_sort_enabled = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if quest_data == null:
		quest_data = NPCQuestData.new()
		quest_data.quest_id = "fight_%d" % randi()
		quest_data.quest_type = NPCQuestData.QuestType.INTERVENTION
		quest_data.title = "Cản cuộc đánh nhau!"
		quest_data.description = "Giữ phím [E] để di chuyển Thanh Xanh trùm lên biểu tượng 💥!"
		quest_data.time_limit = 40.0
		quest_data.reward_points = 70
		
	minigame_ui.visible = false
	if prompt_panel:
		prompt_panel.visible = false
	if prompt_label:
		prompt_label.visible = false
	
	_setup_fighters()
	_create_spectator_circle()

	# Khóa và ẩn các NPC đám đông nền tương ứng ở khu vực này
	var tree = get_tree()
	var crowd_manager = tree.get_first_node_in_group("crowd_manager") if tree else null
	if crowd_manager and crowd_manager.has_method("occupy_crowd_for_fight"):
		occupied_crowd_indices = crowd_manager.occupy_crowd_for_fight(global_position, 65.0, 10)

func _setup_fighters() -> void:
	var sf1 = get_npc_sprite_frames()
	var sf2 = get_npc_sprite_frames()
	if sf1 and fighter1:
		fighter1.sprite_frames = sf1
		fighter1.scale = Vector2(1.3, 1.3)
		var anim1 = "walk_right" if sf1.has_animation("walk_right") else ("run_right" if sf1.has_animation("run_right") else "idle_right")
		fighter1.play(anim1)
		fighter1.modulate = Color.WHITE
	if sf2 and fighter2:
		fighter2.sprite_frames = sf2
		fighter2.scale = Vector2(1.3, 1.3)
		var anim2 = "walk_right" if sf2.has_animation("walk_right") else ("run_right" if sf2.has_animation("run_right") else "idle_right")
		fighter2.play(anim2)
		fighter2.flip_h = true
		fighter2.modulate = Color.WHITE

func _create_spectator_circle() -> void:
	var radius = 45.0
	var count = 8
	for i in range(count):
		var sf = get_npc_sprite_frames()
		if sf == null:
			continue
			
		var angle = (float(i) / count) * TAU
		var pos = Vector2(cos(angle), sin(angle)) * radius
		
		var spec = AnimatedSprite2D.new()
		spec.y_sort_enabled = true
		spec.sprite_frames = sf
		spec.scale = Vector2(1.3, 1.3)
		spec.position = pos
		spec.modulate = Color.WHITE
		
		if abs(pos.x) > abs(pos.y):
			if pos.x > 0:
				if sf.has_animation("idle_left"):
					spec.play("idle_left")
					spec.flip_h = false
				else:
					spec.play("idle_right")
					spec.flip_h = true
			else:
				spec.play("idle_right")
				spec.flip_h = false
		else:
			spec.play("idle_down" if pos.y < 0 else "idle_up")
			spec.flip_h = false
			
		spectators_container.add_child(spec)
		_spectator_sprites.append(spec)

var _cached_player: Node2D = null

func _get_player_node() -> Node2D:
	if not is_instance_valid(_cached_player):
		var tree = get_tree()
		_cached_player = tree.get_first_node_in_group("player") as Node2D if tree else null
	return _cached_player

func _process(delta: float) -> void:
	_anim_time += delta
	
	# Cập nhật vị trí Screen Space chuẩn cho UICanvas UIContainer (100% khớp bong bóng chat)
	var ui_container = find_child("UIContainer", true, false) as Control
	if ui_container:
		var canvas_transform = get_canvas_transform()
		var screen_pos = canvas_transform * global_position
		ui_container.global_position = screen_pos
		
	if not is_resolved:
		# 1. Tăng Chaos Concert nhẹ nhàng khi có ẩu đả chưa được giải quyết (Dễ chịu hơn)
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("add_chaos"):
			gm.add_chaos(delta * 0.8)

		# 2. Tăng Stress vừa phải cho Player khi đứng gần khu vực ẩu đả
		if is_player_inside:
			var player = _get_player_node()
			if player and player.get("stats"):
				player.stats.add_stress(delta * 2.5)

		# Hiệu ứng 2 fighter ẩu đả lắc rung
		var shake = sin(_anim_time * 25.0) * 5.0
		if fighter1:
			fighter1.position.x = -10.0 + shake
		if fighter2:
			fighter2.position.x = 10.0 - shake
			
		if clash_label and clash_label.visible:
			clash_label.scale = Vector2.ONE * (1.0 + sin(_anim_time * 15.0) * 0.15)
			
		# Xử lý Mini-game Stardew Chiều Ngang
		if is_player_inside and minigame_active and active_minigame == self:
			_update_horizontal_stardew_minigame(delta)

func _release_crowd_and_free() -> void:
	var tree = get_tree()
	var crowd_manager = tree.get_first_node_in_group("crowd_manager") if tree else null
	if crowd_manager and crowd_manager.has_method("release_fight_crowd"):
		var final_positions: Array[Vector2] = []
		if fighter1: final_positions.append(fighter1.global_position)
		if fighter2: final_positions.append(fighter2.global_position)
		for spec in _spectator_sprites:
			if is_instance_valid(spec):
				final_positions.append(spec.global_position)
		crowd_manager.release_fight_crowd(occupied_crowd_indices, final_positions)
	queue_free()

func _update_horizontal_stardew_minigame(delta: float) -> void:
	minigame_ui.visible = true
	prompt_label.text = "Giữ [E] trượt Thanh Xanh theo 💥"
	
	# 1. Vật lý Thanh Xanh Chiều Ngang (Player Control Bar)
	var is_pressing = Input.is_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	# Nhấn [E]: Trượt sang PHẢI. Thả [E]: Trượt về TRÁI.
	var accel = 380.0 if is_pressing else -320.0
	bar_velocity += accel * delta
	bar_velocity = clamp(bar_velocity, -220.0, 220.0)
	
	bar_x += bar_velocity * delta
	if bar_x <= 0.0:
		bar_x = 0.0
		bar_velocity = 0.0
	elif bar_x >= TRACK_WIDTH - BAR_WIDTH:
		bar_x = TRACK_WIDTH - BAR_WIDTH
		bar_velocity = 0.0
		
	# 2. Xử lý di chuyển êm ái của biểu tượng Chaos (💥)
	target_timer -= delta
	if target_timer <= 0.0:
		target_timer = randf_range(0.6, 1.2)
		target_velocity = randf_range(-75.0, 75.0) # Di chuyển nhẹ nhàng hơn
		
	target_x += target_velocity * delta
	if target_x <= 0.0:
		target_x = 0.0
		target_velocity = abs(target_velocity)
	elif target_x >= TRACK_WIDTH - TARGET_WIDTH:
		target_x = TRACK_WIDTH - TARGET_WIDTH
		target_velocity = -abs(target_velocity)
		
	# 3. Cập nhật vị trí UI ngang
	green_bar.position.x = bar_x
	chaos_target.position.x = target_x
	
	# 4. Kiểm tra Thanh Xanh trùm lên biểu tượng Chaos (💥)
	var target_center = target_x + TARGET_WIDTH * 0.5
	var is_overlapping = (target_center >= bar_x and target_center <= bar_x + BAR_WIDTH)
	
	if is_overlapping:
		peace_progress += delta * 45.0 # Tăng phần trăm nhanh hơn (dễ hơn)
		green_bar.modulate = Color(0.4, 1.0, 0.4, 1.0)
	else:
		peace_progress = max(0.0, peace_progress - delta * 12.0) # Tụt chậm hơn (dễ thở hơn)
		green_bar.modulate = Color(0.9, 0.4, 0.4, 1.0)
		
	peace_bar.value = peace_progress
	
	# 5. Kiểm tra Hoàn Thành 100%
	if peace_progress >= required_peace_progress:
		_complete_minigame_and_hide_ui()

func _complete_minigame_and_hide_ui() -> void:
	# Ẩn ngay lập tức toàn bộ UI mini-game và nhãn văn bản!
	minigame_ui.visible = false
	if prompt_panel:
		prompt_panel.visible = false
	if prompt_label:
		prompt_label.visible = false
	if clash_label:
		clash_label.visible = false
	if active_minigame == self:
		active_minigame = null
		
	_resolve_fight()

func _ensure_quest_accepted() -> void:
	var quest_manager = get_node_or_null("/root/QuestManager")
	if quest_manager and quest_data not in quest_manager.active_quests:
		var inventory = quest_manager.get_player_inventory()
		if inventory and inventory.has_free_slot():
			quest_manager.accept_quest(quest_data)

func _resolve_fight() -> void:
	is_resolved = true
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("reduce_chaos"):
		gm.reduce_chaos(20.0)
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_camera_shake"):
		player.apply_camera_shake(14.0)

	_spawn_shockwave_effect(global_position)
	
	var quest_manager = get_node_or_null("/root/QuestManager")
	if quest_manager:
		quest_data.is_item_picked_up = true
		quest_manager.complete_quest(quest_data)
		print("[FightEvent] Hoàn thành mini-game Stardew Ngang! Đã dẹp xong ẩu đả.")

	# Mờ dần và giải phóng NPC đám đông lập tức (Không tản di chuyển)
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.4)
	tween.finished.connect(_release_crowd_and_free)

func _spawn_shockwave_effect(pos: Vector2) -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = pos
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.amount = 36
	particles.lifetime = 0.55
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 140.0
	particles.initial_velocity_max = 260.0
	particles.scale_amount_min = 4.0
	particles.scale_amount_max = 8.0
	particles.color = Color(0.15, 0.9, 1.0, 0.95) # Cyan shockwave
	
	var scene = get_tree().current_scene
	if scene:
		scene.add_child(particles)
		particles.emitting = true
		get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_resolved:
		is_player_inside = true
		if prompt_panel:
			prompt_panel.visible = true
		if prompt_label:
			prompt_label.visible = true
			prompt_label.text = "Ấn [E] để cản đánh nhau!"

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_inside = false
		if not is_resolved:
			if prompt_panel:
				prompt_panel.visible = false
			if prompt_label:
				prompt_label.visible = false
			minigame_active = false
			minigame_ui.visible = false
			if active_minigame == self:
				active_minigame = null
