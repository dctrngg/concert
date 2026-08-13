extends Node

signal quest_accepted(quest: NPCQuestData)
signal quest_completed(quest: NPCQuestData)
signal quest_failed(quest: NPCQuestData)
signal quest_timer_updated(quest: NPCQuestData, time_left: float)

var active_quests: Array[NPCQuestData] = []

var _popup_merch_timer: float = 0.0
@export var auto_merch_popup_interval: float = 40.0

func get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

func get_player_stats() -> PlayerStats:
	var player = get_player()
	return player.get("stats") if player else null

func get_player_inventory() -> PlayerInventory:
	var player = get_player()
	return player.get("inventory") if player else null

func accept_quest(quest: NPCQuestData) -> bool:
	var inventory = get_player_inventory()
	if not inventory or not inventory.has_free_slot():
		push_warning("QuestManager: Không thể nhận quest, túi đồ đầy hoặc không tìm thấy inventory!")
		return false
	
	if quest in active_quests:
		return false
		
	quest.state = NPCQuestData.QuestState.ACTIVE
	quest.time_remaining = quest.time_limit
	quest.set_meta("just_accepted", true)
	
	# MỌI nhiệm vụ (trừ Trẻ Lạc LOST_CHILD) khi vừa nhận ĐỀU chưa có item
	if quest.quest_type == NPCQuestData.QuestType.LOST_CHILD:
		quest.is_item_picked_up = true
	else:
		quest.is_item_picked_up = false
	
	active_quests.append(quest)
	inventory.assign_slot(quest)
	quest_accepted.emit(quest)
	return true

## Tạo và nhận ngay nhiệm vụ pop-up bán Merchandise trực tiếp
func spawn_popup_merch_quest(target_count: int = 5, time_limit: float = 50.0) -> bool:
	for q in active_quests:
		if q.quest_type == NPCQuestData.QuestType.MERCH_SELLING:
			return false

	var merch_quest = NPCQuestData.new()
	merch_quest.quest_id = "merch_popup_%d" % randi()
	merch_quest.quest_type = NPCQuestData.QuestType.MERCH_SELLING
	merch_quest.merch_target_count = target_count
	merch_quest.merch_sold_count = 0
	merch_quest.is_item_picked_up = false
	merch_quest.title = "Bán %d Merchandise" % target_count
	merch_quest.description = "Nhiệm vụ đột xuất! Hãy qua Quầy Merch lấy hàng rồi tìm khán giả có icon (🛍️) để bán!"
	merch_quest.time_limit = time_limit
	
	var success = accept_quest(merch_quest)
	if success:
		print("[QuestManager] Nhiệm vụ đột xuất Bán Merchandise tự động xuất hiện!")
	return success

func complete_quest(quest: NPCQuestData) -> void:
	if not (quest in active_quests):
		return
		
	quest.state = NPCQuestData.QuestState.COMPLETED
	active_quests.erase(quest)
	
	var inventory = get_player_inventory()
	if inventory:
		inventory.free_slot(quest)
		
	var stats = get_player_stats()
	if stats:
		stats.reduce_stress(10.0) # stress_decay_on_success

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.add_score(quest.reward_points)
		
	quest_completed.emit(quest)

func fail_quest(quest: NPCQuestData) -> void:
	if not (quest in active_quests):
		return
		
	quest.state = NPCQuestData.QuestState.FAILED
	active_quests.erase(quest)
	
	var inventory = get_player_inventory()
	if inventory:
		inventory.free_slot(quest)
		
	var stats = get_player_stats()
	if stats:
		stats.add_stress(20.0) # stress_per_timeout
		
	quest_failed.emit(quest)

func _process(delta: float) -> void:
	# 1. Quản lý tự động phát sinh nhiệm vụ đột xuất Bán Merch định kỳ (40s)
	_popup_merch_timer += delta
	if _popup_merch_timer >= auto_merch_popup_interval:
		_popup_merch_timer = 0.0
		spawn_popup_merch_quest()

	# 2. Duyệt ngược để cập nhật đếm ngược thời gian và xử lý quá giờ nhiệm vụ
	for i in range(active_quests.size() - 1, -1, -1):
		var quest = active_quests[i]
		quest.time_remaining -= delta
		quest_timer_updated.emit(quest, quest.time_remaining)
		
		if quest.time_remaining <= 0.0:
			fail_quest(quest)
