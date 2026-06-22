extends Node

signal quest_accepted(quest: NPCQuestData)
signal quest_completed(quest: NPCQuestData)
signal quest_failed(quest: NPCQuestData)
signal quest_timer_updated(quest: NPCQuestData, time_left: float)

var active_quests: Array[NPCQuestData] = []

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
	quest.is_item_picked_up = false
	
	active_quests.append(quest)
	inventory.assign_slot(quest)
	quest_accepted.emit(quest)
	return true

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
	# Cần duyệt ngược để xóa phần tử an toàn khi hết giờ
	for i in range(active_quests.size() - 1, -1, -1):
		var quest = active_quests[i]
		quest.time_remaining -= delta
		quest_timer_updated.emit(quest, quest.time_remaining)
		
		if quest.time_remaining <= 0.0:
			fail_quest(quest)
