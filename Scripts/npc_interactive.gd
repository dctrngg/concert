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

func _physics_process(delta: float) -> void:
	if _being_pressed:
		_yield_offset = (_yield_offset + _press_dir * yield_speed * delta).limit_length(yield_max_offset)
	else:
		_yield_offset = _yield_offset.move_toward(Vector2.ZERO, yield_speed * delta)

	position = base_position + _yield_offset
	_being_pressed = false  # player sẽ gọi lại receive_press() mỗi frame nếu vẫn còn ép vào

## Gọi bởi player.gd mỗi frame khi player đang va vào NPC này (qua slide
## collision). NPC chỉ nhường nhẹ theo direction, KHÔNG bị bắn bay như cũ.
func receive_press(direction: Vector2) -> void:
	_being_pressed = true
	_press_dir = direction

func setup(p_npc_index: int, p_outfit_id: int, p_has_quest: bool, p_quest_data: NPCQuestData, dir_str: String, flip_h: bool) -> void:
	npc_index = p_npc_index
	outfit_id = p_outfit_id
	has_quest = p_has_quest
	quest_data = p_quest_data
	is_interacted = false
	is_player_nearby = false

	# Reset trạng thái "nhường nhẹ" mỗi lần được promote lại (position lúc này
	# đã được CrowdManager set = positions[i] TRƯỚC khi gọi setup())
	base_position = position
	_yield_offset = Vector2.ZERO
	_being_pressed = false

	# Match the background NPC's animation direction and flip
	animated_sprite.flip_h = flip_h
	animated_sprite.play("idle_" + dir_str)
	
	update_quest_indicator()

func update_quest_indicator() -> void:
	if quest_indicator:
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
	if not has_quest or quest_data == null:
		return
		
	match quest_data.state:
		NPCQuestData.QuestState.OFFERED:
			var quest_manager = get_node_or_null("/root/QuestManager")
			if quest_manager:
				var inventory = quest_manager.get_player_inventory()
				if inventory and inventory.has_free_slot():
					var success = quest_manager.accept_quest(quest_data)
					if success:
						print("[Quest] Accepted: ", quest_data.title)
						update_quest_indicator()
				else:
					print("[Quest] Inventory full!")
		
		NPCQuestData.QuestState.ACTIVE:
			if quest_data.is_item_picked_up:
				var quest_manager = get_node_or_null("/root/QuestManager")
				if quest_manager:
					quest_manager.complete_quest(quest_data)
					print("[Quest] Completed: ", quest_data.title)
			else:
				print("[Quest] Please collect the item first!")
	
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
