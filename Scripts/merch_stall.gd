extends Area2D
class_name MerchStall

var is_player_nearby: bool = false

func _ready() -> void:
	add_to_group("merch_stall")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func interact() -> void:
	_try_accept_merch_quest()

func _try_accept_merch_quest() -> void:
	var quest_manager = get_node_or_null("/root/QuestManager")
	if not quest_manager:
		return
	var player = quest_manager.get_player()
	if not player or not player.get("inventory"):
		return
		
	var inventory = player.inventory
	var active_quests = inventory.get_active_quests()
	
	# Kiểm tra xem đã nhận quest bán merch chưa
	for quest in active_quests:
		if quest.quest_type == NPCQuestData.QuestType.MERCH_SELLING and not quest.is_item_picked_up:
			print("[MerchStall] Bạn đang có nhiệm vụ bán Merchandise (%d/%d)! Hãy đến gặp khán giả để bán." % [quest.merch_sold_count, quest.merch_target_count])
			return
			
	# Chưa có quest -> Tạo và nhận quest mới nếu túi đồ còn chỗ
	if not inventory.has_free_slot():
		print("[MerchStall] Túi đồ đã đầy, không thể nhận thêm nhiệm vụ bán Merch!")
		return
		
	var merch_quest = NPCQuestData.new()
	merch_quest.quest_id = "merch_%d" % randi()
	merch_quest.quest_type = NPCQuestData.QuestType.MERCH_SELLING
	merch_quest.merch_target_count = 5
	merch_quest.merch_sold_count = 0
	merch_quest.is_item_picked_up = true # Đã lấy hàng sẵn sàng đi bán!
	merch_quest.title = "Bán 5 Merchandise"
	merch_quest.description = "Hãy tìm các khán giả có biểu tượng túi đồ (🛍️) trên đầu để bán hàng!"
	merch_quest.time_limit = 45.0
	
	var success = quest_manager.accept_quest(merch_quest)
	if success:
		var crowd_manager = get_node_or_null("/root/World/CrowdManager")
		if crowd_manager and crowd_manager.has_method("assign_merch_buyers"):
			crowd_manager.assign_merch_buyers(merch_quest, 7)
		print("[MerchStall] Đã nhận nhiệm vụ bán 5 Merchandise! Hãy tìm các khán giả có biểu tượng 🛍️ trên đầu để bán hàng.")


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = true
		print("[MerchStall] Ấn [E] hoặc Click chuột trái để nhận nhiệm vụ bán Merchandise.")

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_nearby = false
