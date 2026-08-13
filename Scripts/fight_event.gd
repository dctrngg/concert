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

@onready var fighter1: AnimatedSprite2D = $Fighters/Fighter1
@onready var fighter2: AnimatedSprite2D = $Fighters/Fighter2
@onready var clash_label: Label = $ClashLabel
@onready var prompt_label: Label = $PromptLabel
@onready var spectators_container: Node2D = $Spectators

# Mini-game UI Nodes
@onready var minigame_ui: Control = $MinigameUI
@onready var green_bar: Control = $MinigameUI/TrackBg/GreenBar
@onready var chaos_target: Control = $MinigameUI/TrackBg/ChaosTarget
@onready var peace_bar: ProgressBar = $MinigameUI/PeaceBar

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
	z_index = 100
	z_as_relative = false
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
	prompt_label.visible = false
	
	_setup_fighters()
	_create_spectator_circle()

	# Khóa và ẩn các NPC đám đông nền tương ứng ở khu vực này
	var crowd_manager = get_tree().get_first_node_in_group("crowd_manager")
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

func _process(delta: float) -> void:
	_anim_time += delta
	
	if not is_resolved:
		# Hiệu ứng 2 fighter ẩu đả lắc rùng
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
	else:
		# Đã dẹp xong -> Các NPC tản ra di chuyển bình thường
		_disperse_timer += delta
		var speed = 40.0
		var crowd_mgr = get_tree().get_first_node_in_group("crowd_manager")
		
		if fighter1 and _wander_directions.size() > 0:
			var next_p = fighter1.position + _wander_directions[0] * speed * delta
			var global_next = to_global(next_p)
			if crowd_mgr and crowd_mgr.has_method("_is_barrier_tile") and crowd_mgr._is_barrier_tile(crowd_mgr.to_local(global_next)):
				_wander_directions[0] = -_wander_directions[0]
			else:
				fighter1.position = next_p
				
		if fighter2 and _wander_directions.size() > 1:
			var next_p = fighter2.position + _wander_directions[1] * speed * delta
			var global_next = to_global(next_p)
			if crowd_mgr and crowd_mgr.has_method("_is_barrier_tile") and crowd_mgr._is_barrier_tile(crowd_mgr.to_local(global_next)):
				_wander_directions[1] = -_wander_directions[1]
			else:
				fighter2.position = next_p
			
		for i in range(_spectator_sprites.size()):
			var spec = _spectator_sprites[i]
			var idx = 2 + i
			if is_instance_valid(spec) and idx < _wander_directions.size():
				var next_p = spec.position + _wander_directions[idx] * speed * delta
				var global_next = to_global(next_p)
				if crowd_mgr and crowd_mgr.has_method("_is_barrier_tile") and crowd_mgr._is_barrier_tile(crowd_mgr.to_local(global_next)):
					_wander_directions[idx] = -_wander_directions[idx]
				else:
					spec.position = next_p
				
		if _disperse_timer > 3.5:
			modulate.a = move_toward(modulate.a, 0.0, delta * 0.8)
			if modulate.a <= 0.0:
				_release_crowd_and_free()

func _release_crowd_and_free() -> void:
	var crowd_manager = get_tree().get_first_node_in_group("crowd_manager")
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
	
	# Reset màu sắc sprite về nguyên bản gốc
	if fighter1:
		fighter1.modulate = Color.WHITE
		if fighter1.sprite_frames and fighter1.sprite_frames.has_animation("walk_left"):
			fighter1.play("walk_left")
			fighter1.flip_h = false
		else:
			fighter1.play("walk_right")
			fighter1.flip_h = true
			
	if fighter2:
		fighter2.modulate = Color.WHITE
		fighter2.play("walk_right")
		fighter2.flip_h = false
		
	# Tạo hướng tản ra cho các NPC
	_wander_directions.clear()
	_wander_directions.append(Vector2(-1.0, randf_range(-0.5, 0.5)).normalized())
	_wander_directions.append(Vector2(1.0, randf_range(-0.5, 0.5)).normalized())
	
	for i in range(_spectator_sprites.size()):
		var spec = _spectator_sprites[i]
		if is_instance_valid(spec):
			spec.modulate = Color.WHITE
			var angle = (float(i) / _spectator_sprites.size()) * TAU
			var dir = Vector2(cos(angle), sin(angle)).normalized()
			_wander_directions.append(dir)
			
			if abs(dir.x) > abs(dir.y):
				if dir.x < 0:
					if spec.sprite_frames and spec.sprite_frames.has_animation("walk_left"):
						spec.play("walk_left")
						spec.flip_h = false
					else:
						spec.play("walk_right")
						spec.flip_h = true
				else:
					spec.play("walk_right")
					spec.flip_h = false
			else:
				spec.play("walk_down" if dir.y > 0 else "walk_up")
				spec.flip_h = false
		
	var quest_manager = get_node_or_null("/root/QuestManager")
	if quest_manager:
		quest_data.is_item_picked_up = true
		quest_manager.complete_quest(quest_data)
		print("[FightEvent] Hoàn thành mini-game Stardew Ngang! Đã dẹp xong ẩu đả.")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and not is_resolved:
		is_player_inside = true
		prompt_label.visible = true
		prompt_label.text = "Ấn [E] hoặc Click chuột để bắt đầu cản đánh nhau!"

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_inside = false
		if not is_resolved:
			prompt_label.visible = false
			minigame_active = false
			minigame_ui.visible = false
			if active_minigame == self:
				active_minigame = null
