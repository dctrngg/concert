extends CanvasLayer
class_name HUD

@onready var stamina_bar: ProgressBar = $Control/StatsPanel/VBoxContainer/StaminaContainer/StaminaBar
@onready var stress_bar: ProgressBar = $Control/StatsPanel/VBoxContainer/StressContainer/StressBar
@onready var quest_list_container: VBoxContainer = $Control/QuestListContainer
@onready var timer_label: Label = $Control/TopCenterPanel/VBox/TimerLabel
@onready var score_label: Label = $Control/TopCenterPanel/VBox/ScoreLabel

var _quest_item_scene: PackedScene = preload("res://Scene/quest_hud_item.tscn")
var _active_hud_items: Dictionary = {}  # quest_id -> QuestHudItem node

@onready var fever_panel: PanelContainer = $Control/FeverPanel
@onready var fever_label: Label = $Control/FeverPanel/VBox/FeverLabel
@onready var combo_bar: ProgressBar = $Control/FeverPanel/VBox/ComboBar

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

	# Kết nối GameManager signals
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.score_changed.connect(_on_score_changed)
		gm.level_timer_updated.connect(_on_level_timer_updated)
		if gm.has_signal("fever_state_changed"):
			gm.fever_state_changed.connect(_on_fever_state_changed)
		if gm.has_signal("combo_updated"):
			gm.combo_updated.connect(_on_combo_updated)
			
		var lvl_data = gm.get_current_level_data()
		_on_score_changed(gm.current_score, lvl_data["star_thresholds"])
		_on_level_timer_updated(gm.time_remaining, lvl_data["time_limit"])
		if not gm.is_level_active:
			gm.start_level(lvl_data["level_id"])

	# Kết nối inventory_changed để cập nhật trạng thái mang vác
	if player and player.get("inventory"):
		player.inventory.inventory_changed.connect(_on_inventory_changed)

	# Kết nối MobileToggleButton
	var mobile_btn = get_node_or_null("Control/MobileToggleButton") as Button
	if mobile_btn:
		mobile_btn.pressed.connect(_on_mobile_toggle_pressed)

func _on_fever_state_changed(is_fever: bool, multiplier: int) -> void:
	if fever_panel:
		fever_panel.visible = is_fever
	if fever_label:
		fever_label.text = "🔥 FEVER MODE x%d MULTIPLIER! 🔥" % multiplier

func _on_combo_updated(combo_count: int, multiplier: int, time_left: float) -> void:
	if combo_count >= 2:
		if fever_panel:
			fever_panel.visible = true
		if fever_label:
			var title_str = "🔥 FEVER x%d (COMBO %d!) 🔥" % [multiplier, combo_count]
			if multiplier >= 4:
				title_str = "⚡ MAX DISCO FEVER x4 (COMBO %d!) ⚡" % combo_count
			fever_label.text = title_str
		if combo_bar:
			combo_bar.max_value = 14.0
			combo_bar.value = time_left
	else:
		if fever_panel:
			fever_panel.visible = false

# ─── Stamina & Stress ───────────────────────────────────────────────────────

func _on_stamina_changed(current: float, max_val: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_val
		stamina_bar.value = current

func _on_stress_changed(current: float, max_val: float) -> void:
	if stress_bar:
		stress_bar.max_value = max_val
		stress_bar.value = current

# ─── Level Timer & Score ───────────────────────────────────────────────────

func _on_level_timer_updated(time_left: float, _limit: float) -> void:
	if timer_label:
		var mins = int(time_left) / 60
		var secs = int(time_left) % 60
		timer_label.text = "⏱️ %02d:%02d" % [mins, secs]

func _on_score_changed(current: int, thresholds: Array) -> void:
	if score_label:
		var stars_str = "☆☆☆"
		if current >= thresholds[2]:
			stars_str = "★★★"
		elif current >= thresholds[1]:
			stars_str = "★★☆"
		elif current >= thresholds[0]:
			stars_str = "★☆☆"
		score_label.text = "🏆 Điểm: %d (%s)" % [current, stars_str]

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
