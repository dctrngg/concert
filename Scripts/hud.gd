extends CanvasLayer
class_name HUD

@onready var stamina_bar: ProgressBar = find_child("StaminaBar", true, false) as ProgressBar
@onready var stress_bar: ProgressBar = find_child("StressBar", true, false) as ProgressBar
@onready var chaos_bar: ProgressBar = find_child("ChaosBar", true, false) as ProgressBar
@onready var quest_list_container: VBoxContainer = find_child("QuestListContainer", true, false) as VBoxContainer
@onready var timer_label: Label = find_child("TimerLabel", true, false) as Label
@onready var score_label: Label = find_child("ScoreLabel", true, false) as Label
@onready var top_center_panel: PanelContainer = find_child("TopCenterPanel", true, false) as PanelContainer
@onready var stats_panel: PanelContainer = find_child("StatsPanel", true, false) as PanelContainer

var _quest_item_scene: PackedScene = preload("res://Scene/quest_hud_item.tscn")
var _active_hud_items: Dictionary = {}  # quest_id -> QuestHudItem node

func _ready() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or get_tree() == null:
		return
		
	var tree = get_tree()

	# Kết nối PlayerStats
	var player = tree.get_first_node_in_group("player")
	if player and player.get("stats"):
		var stats: PlayerStats = player.stats
		stats.stamina_changed.connect(_on_stamina_changed)
		stats.stress_changed.connect(_on_stress_changed)
		if stats.has_signal("player_fainted"):
			stats.player_fainted.connect(_on_player_fainted)
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
		if gm.has_signal("chaos_changed"):
			gm.chaos_changed.connect(_on_chaos_changed)
			_on_chaos_changed(gm.current_chaos, gm.max_chaos)
		var lvl_data = gm.get_current_level_data()
		_on_score_changed(gm.current_score, lvl_data["star_thresholds"])
		_on_level_timer_updated(gm.time_remaining, lvl_data["time_limit"])

	# Xử lý ẩn TOÀN BỘ UI HUD (Thanh thể lực/stress, Đếm ngược, Nút touch UI) khi LevelStartDialog xuất hiện ở đầu màn
	var main_control = get_node_or_null("Control") as Control
	var start_dialog = tree.get_first_node_in_group("level_start_dialog")
	if start_dialog:
		if main_control:
			main_control.visible = false
		if start_dialog.has_signal("play_pressed"):
			start_dialog.play_pressed.connect(func():
				if main_control:
					main_control.visible = true
				if gm and gm.has_method("start_gameplay"):
					gm.start_gameplay()
			)
	else:
		if main_control:
			main_control.visible = true
		if gm and gm.has_method("start_gameplay"):
			gm.start_gameplay()

	# Kết nối inventory_changed để cập nhật trạng thái mang vác
	if player and player.get("inventory"):
		player.inventory.inventory_changed.connect(_on_inventory_changed)

	# Kết nối MobileToggleButton
	var mobile_btn = get_node_or_null("Control/MobileToggleButton") as Button
	if mobile_btn:
		mobile_btn.pressed.connect(_on_mobile_toggle_pressed)

func _on_mobile_toggle_pressed() -> void:
	var mc = get_node_or_null("MobileControls")
	if mc and mc.has_method("toggle_mobile_controls"):
		mc.toggle_mobile_controls()

# ─── Stamina & Stress ───────────────────────────────────────────────────────

func _on_stamina_changed(current: float, max_val: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = max_val
		stamina_bar.value = current

func _on_stress_changed(current: float, max_val: float) -> void:
	if stress_bar:
		stress_bar.max_value = max_val
		stress_bar.value = current

func _on_chaos_changed(current: float, max_val: float) -> void:
	if chaos_bar:
		chaos_bar.max_value = max_val
		chaos_bar.value = current
		# Hiệu ứng đổi màu đỏ rực khi Chaos > 75%
		if current / max_val > 0.75:
			chaos_bar.modulate = Color(1.3, 0.4, 0.4, 1.0)
		else:
			chaos_bar.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _on_player_fainted(duration: float, count: int, max_faints: int) -> void:
	print("[HUD] 😵 Bảo vệ bị choáng/ngất xỉu trong %.1fs (Lần %d/%d)" % [duration, count, max_faints])

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
	var tree = get_tree()
	if not tree:
		return
	var player = tree.get_first_node_in_group("player")
	if not player or not player.get("inventory"):
		return
	for quest in player.inventory.get_active_quests():
		var item = _active_hud_items.get(quest.quest_id, null)
		if item:
			item.update_status(quest.is_item_picked_up)
