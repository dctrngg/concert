extends Area2D
class_name FoodSource

var is_player_nearby: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _input(event: InputEvent) -> void:
	if is_player_nearby:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_try_pickup_food()
			get_viewport().set_input_as_handled()

func _try_pickup_food() -> void:
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
		if quest.quest_type == NPCQuestData.QuestType.FOOD_DELIVERY and not quest.is_item_picked_up:
			quest.is_item_picked_up = true
			picked_up_any = true
			print("[FoodSource] Đã lấy đồ ăn cho quest: ", quest.title)
			
	if picked_up_any:
		inventory.inventory_changed.emit()
		# Cập nhật hiển thị indicator trên đầu các NPC
		get_tree().call_group("npc_interactive", "update_quest_indicator")
	else:
		print("[FoodSource] Bạn không có nhiệm vụ giao đồ ăn nào cần lấy hàng!")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true
		print("[FoodSource] Click chuột trái để lấy đồ ăn.")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
