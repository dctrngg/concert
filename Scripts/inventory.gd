extends Node
class_name PlayerInventory

signal inventory_changed()

@export var inventory_slots: int = 3
var slots: Array[NPCQuestData] = []

func _ready() -> void:
	slots.resize(inventory_slots)
	slots.fill(null)

func has_free_slot() -> bool:
	for slot in slots:
		if slot == null:
			return true
	return false

func assign_slot(quest_data: NPCQuestData) -> bool:
	for i in range(inventory_slots):
		if slots[i] == null:
			slots[i] = quest_data
			inventory_changed.emit()
			return true
	return false

func free_slot(quest_data: NPCQuestData) -> bool:
	for i in range(inventory_slots):
		if slots[i] == quest_data:
			slots[i] = null
			inventory_changed.emit()
			return true
	return false

# Tiện ích để UI kiểm tra trạng thái túi đồ
func get_active_quests() -> Array[NPCQuestData]:
	var active: Array[NPCQuestData] = []
	for slot in slots:
		if slot != null:
			active.append(slot)
	return active
