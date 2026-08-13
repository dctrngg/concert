extends CharacterBody2D

signal interacted(npc_index: int)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var quest_indicator: Label = $QuestIndicator

var npc_index: int = -1
var outfit_id: int = 0
var has_quest: bool = false
var quest_data: NPCQuestData = null
var is_interacted: bool = false
var is_player_nearby: bool = false

## --- Nhường nhẹ khi player chen vào (thay cho push_velocity cũ) ---
## NPC KHÔNG bị đẩy bay nữa; chỉ lệch RẤT NHẸ rồi tự về vị trí gốc, giống
## người thật nhường đường. base_position được set lại mỗi lần promote (setup()).
@export var yield_max_offset: float = 6.0  # NPC chỉ nhường tối đa 6px
@export var yield_speed: float = 40.0       # tốc độ nhường / trả lại RẤT chậm

var base_position: Vector2 = Vector2.ZERO
var _yield_offset: Vector2 = Vector2.ZERO
var _being_pressed: bool = false
var _press_dir: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("npc_interactive")
	# Dynamically load sprite frames from the Player scene to reuse assets and avoid duplication
	if animated_sprite and (animated_sprite.sprite_frames == null or not animated_sprite.sprite_frames.has_animation("idle_down")):
		var player_scene = load("res://Scene/Player.tscn")
		if player_scene:
			var player_instance = player_scene.instantiate()
			var player_sprite = player_instance.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
			if player_sprite and player_sprite.sprite_frames:
				animated_sprite.sprite_frames = player_sprite.sprite_frames
			player_instance.queue_free()
	update_quest_indicator()
	
	var quest_manager = get_node_or_null("/root/QuestManager")
	if quest_manager:
		if not quest_manager.quest_failed.is_connected(_on_quest_ended):
			quest_manager.quest_failed.connect(_on_quest_ended)
		if not quest_manager.quest_completed.is_connected(_on_quest_ended):
			quest_manager.quest_completed.connect(_on_quest_ended)


func _on_quest_ended(p_quest_data: NPCQuestData) -> void:
	if p_quest_data == quest_data:
		has_quest = false
		update_quest_indicator()

var _indicator_time: float = 0.0

func _physics_process(delta: float) -> void:
	_indicator_time += delta
	if quest_indicator and quest_indicator.visible:
		quest_indicator.position.y = -26.0 + sin(_indicator_time * 6.0) * 3.0

	if _being_pressed:
		_yield_offset = (_yield_offset + _press_dir * yield_speed * delta).limit_length(yield_max_offset)
	else:
		_yield_offset = _yield_offset.move_toward(Vector2.ZERO, yield_speed * delta)

	var target_pos = base_position + _yield_offset
	var crowd_mgr = get_tree().get_first_node_in_group("crowd_manager")
	if crowd_mgr and crowd_mgr.has_method("_is_barrier_tile"):
		var local_pos = crowd_mgr.to_local(to_global(target_pos))
		if crowd_mgr._is_barrier_tile(local_pos):
			_yield_offset = Vector2.ZERO
			target_pos = base_position

	position = target_pos
	_being_pressed = false  # player sẽ gọi lại receive_press() mỗi frame nếu vẫn còn ép vào


## Gọi bởi player.gd mỗi frame khi player đang va vào NPC này (qua slide
## collision). NPC chỉ nhường nhẹ theo direction, KHÔNG bị bắn bay như cũ.
func receive_press(direction: Vector2) -> void:
	_being_pressed = true
	_press_dir = direction

var is_merch_buyer: bool = false

func setup(p_npc_index: int, p_outfit_id: int, p_has_quest: bool, p_quest_data: NPCQuestData, dir_str: String, flip_h: bool, p_sprite_frames: SpriteFrames = null) -> void:
	npc_index = p_npc_index
	outfit_id = p_outfit_id
	has_quest = p_has_quest
	quest_data = p_quest_data
	is_interacted = (p_quest_data != null and p_quest_data.state == NPCQuestData.QuestState.ACTIVE)
	is_player_nearby = false
	is_merch_buyer = false

	# Reset trạng thái "nhường nhẹ" mỗi lần được promote lại
	base_position = position
	_yield_offset = Vector2.ZERO
	_being_pressed = false

	if animated_sprite == null:
		animated_sprite = $AnimatedSprite2D
	if quest_indicator == null:
		quest_indicator = $QuestIndicator

	if p_sprite_frames != null and animated_sprite:
		animated_sprite.sprite_frames = p_sprite_frames
	elif animated_sprite and (animated_sprite.sprite_frames == null or not animated_sprite.sprite_frames.has_animation("idle_down")):
		var player_scene = load("res://Scene/Player.tscn")
		if player_scene:
			var dummy_player = player_scene.instantiate()
			var player_sprite = dummy_player.get_node_or_null("AnimatedSprite2D")
			if player_sprite and player_sprite.sprite_frames:
				animated_sprite.sprite_frames = player_sprite.sprite_frames
			dummy_player.queue_free()

	if animated_sprite:
		animated_sprite.scale = Vector2(1.3, 1.3)

	# Match the background NPC's animation direction and flip
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("idle_" + dir_str):
			animated_sprite.flip_h = flip_h
			animated_sprite.play("idle_" + dir_str)
		elif dir_str == "left" and animated_sprite.sprite_frames.has_animation("idle_right"):
			animated_sprite.flip_h = true
			animated_sprite.play("idle_right")
	
	update_quest_indicator()

func update_quest_indicator() -> void:
	if quest_indicator:
		if is_parent_npc:
			quest_indicator.text = "👨‍👩‍👧"
			quest_indicator.visible = true
			return

		if is_merch_buyer:
			quest_indicator.text = "🛍️"
			quest_indicator.visible = true
			return

		if not has_quest or quest_data == null:
			quest_indicator.visible = false
			return
		
		match quest_data.state:
			NPCQuestData.QuestState.OFFERED:
				quest_indicator.text = "!"
				quest_indicator.visible = true
			NPCQuestData.QuestState.ACTIVE:
				if quest_data.is_item_picked_up:
					quest_indicator.text = "?"
					quest_indicator.visible = true
				else:
					quest_indicator.text = "..."
					quest_indicator.visible = true
			_:
				quest_indicator.visible = false

func interact() -> void:
	var quest_manager = get_node_or_null("/root/QuestManager")
	
	# 1. Kiểm tra xem NPC này có phải Khán Giả Muốn Mua Merch hay không
	if is_merch_buyer and quest_manager:
		var inventory = quest_manager.get_player_inventory()
		if inventory:
			for q in inventory.get_active_quests():
				if q.quest_type == NPCQuestData.QuestType.MERCH_SELLING:
					is_merch_buyer = false
					q.merch_sold_count += 1
					
					# Gỡ bỏ NPC khỏi danh sách người mua trong CrowdManager
					var crowd_manager = get_node_or_null("/root/World/CrowdManager")
					if crowd_manager and crowd_manager.has_method("clear_merch_buyer"):
						crowd_manager.clear_merch_buyer(npc_index)
						
					_spawn_floating_text("+1 Bán Hàng! 👕💵", Color(0.2, 0.9, 0.4))
					print("[Merch] Đã bán 1 sản phẩm cho khán giả %d! (%d/%d)" % [npc_index, q.merch_sold_count, q.merch_target_count])
					
					var sound_mgr = get_node_or_null("/root/SoundManager")
					if not sound_mgr:
						sound_mgr = get_tree().get_first_node_in_group("sound_manager")
					if sound_mgr and sound_mgr.has_method("play_merch_sell_sfx"):
						sound_mgr.play_merch_sell_sfx()
					
					inventory.inventory_changed.emit()
					update_quest_indicator()
					
					if q.merch_sold_count >= q.merch_target_count:
						q.is_item_picked_up = true
						quest_manager.complete_quest(q)
						print("[Merch] Hoàn thành xuất sắc chỉ tiêu bán Merchandise!")
						
					interacted.emit(npc_index)
					return


	# 2. Xử lý nhiệm vụ do chính NPC này giao (Giao đồ ăn / Mang ghế)
	if not has_quest or quest_data == null:
		return
		
	match quest_data.state:
		NPCQuestData.QuestState.OFFERED:
			if quest_manager:
				var inventory = quest_manager.get_player_inventory()
				if inventory and inventory.has_free_slot():
					var success = quest_manager.accept_quest(quest_data)
					if success:
						is_interacted = true
						print("[Quest] Accepted: ", quest_data.title)
						update_quest_indicator()
				else:
					print("[Quest] Inventory full!")
		
		NPCQuestData.QuestState.ACTIVE:
			if quest_data.has_meta("just_accepted") and quest_data.get_meta("just_accepted") == true:
				quest_data.remove_meta("just_accepted")
				interacted.emit(npc_index)
				return
				
			if quest_data.is_item_picked_up:
				if quest_manager:
					quest_manager.complete_quest(quest_data)
					print("[Quest] Completed: ", quest_data.title)
			else:
				if quest_data.quest_type == NPCQuestData.QuestType.FOOD_DELIVERY:
					print("[Quest] Vui lòng qua quầy đồ ăn lấy đồ trước!")
				elif quest_data.quest_type == NPCQuestData.QuestType.SEAT_FINDER:
					print("[Quest] Vui lòng qua kho lấy ghế trước!")
	
	interacted.emit(npc_index)


func _on_detection_area_body_entered(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		is_player_nearby = true
		# We can also display a simple interact label or console message
		print("[NPC %d] Player nearby. Click Left Mouse to interact." % npc_index)

func _on_detection_area_body_exited(body: Node2D) -> void:
	if body.name == "Player" or body.is_in_group("player"):
		is_player_nearby = false
		print("[NPC %d] Player left." % npc_index)

func _spawn_floating_text(text_msg: String, color: Color) -> void:
	var label = Label.new()
	label.text = text_msg
	label.position = Vector2(-40, -36)
	var pixel_font = load("res://0307-LNTH-TwistyPixel.ttf")
	if pixel_font:
		label.add_theme_font_override("font", pixel_font)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 16)
	add_child(label)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 20.0, 1.2)
	tween.tween_property(label, "modulate:a", 0.0, 1.2).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)

