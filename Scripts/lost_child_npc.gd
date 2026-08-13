extends CharacterBody2D
class_name LostChildNPC

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var quest_indicator: Label = $QuestIndicator

var quest_data: NPCQuestData = null
var is_player_nearby: bool = false
var is_following: bool = false
var player: CharacterBody2D = null

var parent_npc_idx: int = -1
var parent_global_pos: Vector2 = Vector2.INF

@export var follow_speed: float = 165.0
@export var follow_distance: float = 38.0

var _indicator_time: float = 0.0

func _ready() -> void:
	add_to_group("npc_interactive")
	add_to_group("lost_child_npc")
	
	var area = get_node_or_null("InteractionArea") as Area2D
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
		
	_load_punk_kid_boy_sprite()
	_setup_quest_data()

func _load_punk_kid_boy_sprite() -> void:
	var sprite_path = "res://Sprites/RPG Top Down Characters/Punk Kid Boy/punk_kid_boy.png"
	if not ResourceLoader.exists(sprite_path):
		return
		
	var tex = load(sprite_path) as Texture2D
	if not tex or not animated_sprite:
		return
		
	var sf = SpriteFrames.new()
	sf.remove_animation("default")
	
	var anims = {
		"idle_down": 0, "idle_right": 32, "idle_left": 64, "idle_up": 96,
		"walk_down": 128, "walk_right": 160, "walk_left": 192, "walk_up": 224,
	}
	
	for anim_name in anims.keys():
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, 6.0)
		sf.set_animation_loop(anim_name, true)
		
		var y_pos = anims[anim_name]
		for col in range(4):
			var atlas_sub = AtlasTexture.new()
			atlas_sub.atlas = tex
			atlas_sub.region = Rect2(col * 32, y_pos, 32, 32)
			sf.add_frame(anim_name, atlas_sub)
			
	animated_sprite.sprite_frames = sf
	animated_sprite.scale = Vector2(1.2, 1.2)
	animated_sprite.play("idle_down")

func _setup_quest_data() -> void:
	quest_data = NPCQuestData.new()
	quest_data.quest_id = "lost_child_%d" % randi()
	quest_data.quest_type = NPCQuestData.QuestType.LOST_CHILD
	quest_data.title = "Dắt Trẻ Lạc Về Ba Mẹ"
	quest_data.description = "Bé trai bị lạc trong đám đông. Hãy dắt bé theo Mũi Tên Chỉ Đường về gặp Ba Mẹ!"
	quest_data.time_limit = 65.0
	quest_data.reward_points = 120
	quest_data.item_icon_path = "res://Sprites/RPG Top Down Characters/Punk Kid Boy/punk_kid_boy.png"
	quest_data.is_item_picked_up = true # Đã có em bé đi theo!
	
	update_indicator()

func update_indicator() -> void:
	if not quest_indicator:
		return
		
	if quest_data.state == NPCQuestData.QuestState.OFFERED:
		quest_indicator.text = "👶"
		quest_indicator.visible = true
	elif is_following:
		quest_indicator.text = "👶"
		quest_indicator.visible = true
	else:
		quest_indicator.visible = false

func interact() -> void:
	if quest_data.state == NPCQuestData.QuestState.OFFERED:
		var crowd_mgr = get_node_or_null("/root/World/CrowdManager")
		if crowd_mgr and crowd_mgr.has_method("setup_parents_for_child"):
			crowd_mgr.setup_parents_for_child(self)

		var quest_mgr = get_node_or_null("/root/QuestManager")
		if quest_mgr:
			quest_data.parent_global_pos = parent_global_pos
			quest_data.parent_npc_idx = parent_npc_idx
			quest_data.is_item_picked_up = true
			if quest_mgr.accept_quest(quest_data):
				quest_data.is_item_picked_up = true
				player = quest_mgr.get_player() as CharacterBody2D
				is_following = true
				update_indicator()
				
				if crowd_mgr and parent_npc_idx >= 0 and crowd_mgr.has_method("_promote_npc"):
					crowd_mgr._promote_npc(parent_npc_idx)
						
				var sound_mgr = get_node_or_null("/root/SoundManager")
				if sound_mgr and sound_mgr.has_method("play_chair_pickup_sfx"):
					sound_mgr.play_chair_pickup_sfx()
					
				print("[LostChild] Đã nhận nhiệm vụ dắt trẻ lạc về với Ba Mẹ!")

func _physics_process(delta: float) -> void:
	_indicator_time += delta
	if quest_indicator and quest_indicator.visible:
		quest_indicator.position.y = -34.0 + sin(_indicator_time * 6.0) * 3.0

	if not player:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D
		
	if player and not is_following:
		var d = global_position.distance_to(player.global_position)
		is_player_nearby = (d <= 110.0)

	if not is_following or not player:
		return
		
	var dist_to_player = global_position.distance_to(player.global_position)
	if dist_to_player > follow_distance:
		var dir = (player.global_position - global_position).normalized()
		velocity = dir * follow_speed
		move_and_slide()
		_update_walk_animation(dir)
	else:
		velocity = Vector2.ZERO
		_update_idle_animation()

	# Kiểm tra khi dắt bé đến gần vị trí Ba Mẹ
	if parent_global_pos != Vector2.INF:
		var dist_to_parent = global_position.distance_to(parent_global_pos)
		if dist_to_parent <= 68.0:
			_reunite_with_parents()

func _update_walk_animation(dir: Vector2) -> void:
	if not animated_sprite:
		return
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			animated_sprite.play("walk_right")
			animated_sprite.flip_h = false
		else:
			animated_sprite.play("walk_right")
			animated_sprite.flip_h = true
	else:
		if dir.y > 0:
			animated_sprite.play("walk_down")
		else:
			animated_sprite.play("walk_up")

func _update_idle_animation() -> void:
	if not animated_sprite:
		return
	var current_anim = animated_sprite.animation
	if current_anim.begins_with("walk_"):
		var idle_anim = current_anim.replace("walk_", "idle_")
		if animated_sprite.sprite_frames.has_animation(idle_anim):
			animated_sprite.play(idle_anim)

func _reunite_with_parents() -> void:
	is_following = false
	velocity = Vector2.ZERO
	quest_indicator.text = "❤️"
	
	var quest_mgr = get_node_or_null("/root/QuestManager")
	if quest_mgr and quest_data:
		quest_mgr.complete_quest(quest_data)
		print("[LostChild] Bé đã đoàn tụ với Ba Mẹ! Hoàn thành xuất sắc nhiệm vụ.")
		
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_chair_pickup_sfx"):
		sound_mgr.play_chair_pickup_sfx()
		
	# Despawn em bé sau khi hoàn thành nhiệm vụ
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.8)
	tween.tween_callback(queue_free)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
