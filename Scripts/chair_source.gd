extends Area2D
class_name ChairSource

var is_player_nearby: bool = false

func _ready() -> void:
	add_to_group("chair_source")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func interact() -> void:
	_try_pickup_chair()

func _try_pickup_chair() -> void:
	var quest_manager = get_node_or_null("/root/QuestManager")
	if not quest_manager:
		return
	var player = quest_manager.get_player()
	if not player or not player.get("inventory"):
		return
		
	var inventory = player.inventory
	var active_quests = inventory.get_active_quests()
	
	var picked_up_any = false
	for quest in active_quests:
		if quest.quest_type == NPCQuestData.QuestType.SEAT_FINDER and not quest.is_item_picked_up:
			quest.is_item_picked_up = true
			picked_up_any = true
			print("[ChairSource] Đã lấy ghế từ kho cho quest: ", quest.title)
			
	if picked_up_any:
		inventory.inventory_changed.emit()
		var tree = get_tree()
		if tree:
			tree.call_group("npc_interactive", "update_quest_indicator")
		var sound_mgr = get_node_or_null("/root/SoundManager")
		if not sound_mgr and tree:
			sound_mgr = tree.get_first_node_in_group("sound_manager")
		if sound_mgr and sound_mgr.has_method("play_chair_pickup_sfx"):
			sound_mgr.play_chair_pickup_sfx()
	else:
		print("[ChairSource] Bạn không có nhiệm vụ mượn/lấy ghế nào cần lấy hàng!")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true
		print("[ChairSource] Ấn [E] hoặc Click chuột trái để lấy ghế.")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
