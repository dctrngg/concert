extends Area2D
class_name SeatArea

@export var seat_id: String = "Khu A - Ghế 1"

var is_player_nearby: bool = false

@onready var label: Label = $Label

func _ready() -> void:
	add_to_group("seat_area")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_update_label()

func _update_label() -> void:
	if label:
		label.text = "🪑 " + seat_id

func interact() -> void:
	_try_confirm_seat()

func _try_confirm_seat() -> void:
	var quest_manager = get_node_or_null("/root/QuestManager")
	if not quest_manager:
		return
	var player = quest_manager.get_player()
	if not player or not player.get("inventory"):
		return
		
	var inventory = player.inventory
	var active_quests = inventory.get_active_quests()
	
	var confirmed_any = false
	for quest in active_quests:
		if quest.quest_type == NPCQuestData.QuestType.SEAT_FINDER and not quest.is_item_picked_up:
			# So sánh seat_id (hoặc tự động xác nhận ghế nếu khớp khu vực)
			if quest.target_seat_id == seat_id or quest.target_seat_id == "" or seat_id.begins_with(quest.target_seat_id.split("-")[0].strip_edges()):
				quest.is_item_picked_up = true
				confirmed_any = true
				print("[SeatArea] Đã tìm và xác nhận đúng vị trí ghế: ", seat_id)
				break
			
	if confirmed_any:
		inventory.inventory_changed.emit()
		get_tree().call_group("npc_interactive", "update_quest_indicator")
	else:
		print("[SeatArea] Không có khán giả nào cần dẫn đến ghế ", seat_id)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true
		print("[SeatArea] Ấn [E] hoặc Click chuột trái để xác nhận vị trí ghế: ", seat_id)

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
