extends CanvasLayer
class_name HUD

@onready var stamina_bar: ProgressBar = $Control/VBoxContainer/StaminaContainer/StaminaBar
@onready var stress_bar: ProgressBar = $Control/VBoxContainer/StressContainer/StressBar
@onready var quest_list_container: VBoxContainer = $Control/QuestListContainer

var _quest_item_scene: PackedScene = preload("res://Scene/quest_hud_item.tscn")
var _active_hud_items: Dictionary = {}  # quest_id -> QuestHudItem node

func _ready() -> void:
	await get_tree().process_frame

	# Kết nối PlayerStats
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("stats"):
		var stats: PlayerStats = player.stats
		stats.stamina_changed.connect(_on_stamina_changed)
		stats.stress_changed.connect(_on_stress_changed)
		_on_stamina_changed(stats.stamina, stats.max_stamina)
		_on_stress_changed(stats.stress, stats.max_stress)
	else:
		push_warning("HUD: Không tìm thấy Player hoặc PlayerStats!")

	# Kết nối QuestManager signals
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		qm.quest_accepted.connect(_on_quest_accepted)
		qm.quest_completed.connect(_on_quest_ended)
		qm.quest_failed.connect(_on_quest_ended)
		qm.quest_timer_updated.connect(_on_quest_timer_updated)
	else:
		push_warning("HUD: Không tìm thấy QuestManager Autoload!")

	# Kết nối inventory_changed để cập nhật trạng thái mang vác
	if player and player.get("inventory"):
		player.inventory.inventory_changed.connect(_on_inventory_changed)

# ─── Stamina & Stress ───────────────────────────────────────────────────────

func _on_stamina_changed(current: float, max_val: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_val
		stamina_bar.value = current

func _on_stress_changed(current: float, max_val: float) -> void:
	if stress_bar:
		stress_bar.max_value = max_val
		stress_bar.value = current

# ─── Quest HUD Stack ─────────────────────────────────────────────────────────

func _on_quest_accepted(quest: NPCQuestData) -> void:
	if not quest_list_container:
		return
	if _active_hud_items.has(quest.quest_id):
		return

	var item = _quest_item_scene.instantiate()
	quest_list_container.add_child(item)
	item.setup(quest)
	_active_hud_items[quest.quest_id] = item

func _on_quest_timer_updated(quest: NPCQuestData, time_left: float) -> void:
	var item = _active_hud_items.get(quest.quest_id, null)
	if item:
		item.update_timer(time_left)

func _on_quest_ended(quest: NPCQuestData) -> void:
	var item = _active_hud_items.get(quest.quest_id, null)
	if item:
		_active_hud_items.erase(quest.quest_id)
		item.queue_free()

func _on_inventory_changed() -> void:
	# Cập nhật trạng thái mang vác cho tất cả hud items đang hiển thị
	var player = get_tree().get_first_node_in_group("player")
	if not player or not player.get("inventory"):
		return
	for quest in player.inventory.get_active_quests():
		var item = _active_hud_items.get(quest.quest_id, null)
		if item:
			item.update_status(quest.is_item_picked_up)
