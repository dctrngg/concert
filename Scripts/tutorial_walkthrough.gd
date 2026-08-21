extends Control

signal walkthrough_completed()

enum TutorialStep {
	MOVE = 1,
	ACCEPT_QUEST = 2,
	FETCH_ITEM = 3,
	DELIVER_ITEM = 4,
	FINISHED = 5
}

var current_step: TutorialStep = TutorialStep.MOVE

@onready var main_card: PanelContainer = find_child("MainCard", true, false) as PanelContainer
@onready var step1_label: Label = find_child("Step1Label", true, false) as Label
@onready var step2_label: Label = find_child("Step2Label", true, false) as Label
@onready var step3_label: Label = find_child("Step3Label", true, false) as Label
@onready var step4_label: Label = find_child("Step4Label", true, false) as Label
@onready var hint_label: Label = find_child("HintLabel", true, false) as Label
@onready var skip_button: Button = find_child("SkipButton", true, false) as Button

var _player: CharacterBody2D = null
var _last_player_pos: Vector2 = Vector2.ZERO
var _distance_moved: float = 0.0
var _pulse_time: float = 0.0
var _is_dismissing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if skip_button and not skip_button.pressed.is_connected(_on_skip_pressed):
		skip_button.pressed.connect(_on_skip_pressed)

	_setup_card_style()
	_update_ui_display()

	call_deferred("_connect_signals")

func _setup_card_style() -> void:
	if main_card:
		main_card.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_property(main_card, "modulate:a", 1.0, 0.4)

func _connect_signals() -> void:
	var tree = get_tree()
	if tree:
		_player = tree.get_first_node_in_group("player") as CharacterBody2D
		if _player:
			_last_player_pos = _player.global_position
			if _player.get("inventory"):
				var inv = _player.get("inventory")
				if inv and inv.has_signal("inventory_changed"):
					if not inv.inventory_changed.is_connected(_on_inventory_changed):
						inv.inventory_changed.connect(_on_inventory_changed)

	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		if not qm.quest_accepted.is_connected(_on_quest_accepted):
			qm.quest_accepted.connect(_on_quest_accepted)
		if not qm.quest_completed.is_connected(_on_quest_completed):
			qm.quest_completed.connect(_on_quest_completed)

func _process(delta: float) -> void:
	if _is_dismissing:
		return

	# Hiệu ứng nhấp nháy chữ Hướng Dẫn đang active
	_pulse_time += delta * 4.0
	var alpha_pulse = 0.7 + sin(_pulse_time) * 0.3
	if hint_label:
		hint_label.modulate.a = alpha_pulse

	# Bước 1: Kiểm tra người chơi tự di chuyển nhân vật
	if current_step == TutorialStep.MOVE and _player:
		var current_pos = _player.global_position
		var delta_dist = _last_player_pos.distance_to(current_pos)
		_last_player_pos = current_pos

		if delta_dist > 0.5:
			_distance_moved += delta_dist
			if _distance_moved >= 45.0:
				advance_step(TutorialStep.ACCEPT_QUEST)

func advance_step(next_step: TutorialStep) -> void:
	if current_step >= next_step or _is_dismissing:
		return

	current_step = next_step
	_play_chime_sfx()
	_update_ui_display()

	if current_step == TutorialStep.FINISHED:
		_finish_walkthrough()

func _on_quest_accepted(_quest: NPCQuestData) -> void:
	if current_step == TutorialStep.ACCEPT_QUEST:
		if _quest and _quest.is_item_picked_up:
			advance_step(TutorialStep.DELIVER_ITEM)
		else:
			advance_step(TutorialStep.FETCH_ITEM)

func _on_inventory_changed() -> void:
	if current_step == TutorialStep.FETCH_ITEM:
		var qm = get_node_or_null("/root/QuestManager")
		if qm and "active_quests" in qm:
			for q in qm.active_quests:
				if q.is_item_picked_up:
					advance_step(TutorialStep.DELIVER_ITEM)
					break

func _on_quest_completed(_quest: NPCQuestData) -> void:
	if current_step == TutorialStep.DELIVER_ITEM or current_step == TutorialStep.FETCH_ITEM or current_step == TutorialStep.ACCEPT_QUEST:
		advance_step(TutorialStep.FINISHED)

func _update_ui_display() -> void:
	if step1_label: _format_step_label(step1_label, 1, "Di chuyển nhân vật [W-A-S-D / Joystick]", current_step > TutorialStep.MOVE, current_step == TutorialStep.MOVE)
	if step2_label: _format_step_label(step2_label, 2, "Gặp Khán Giả có dấu ❗️ và nhấn [E]", current_step > TutorialStep.ACCEPT_QUEST, current_step == TutorialStep.ACCEPT_QUEST)
	if step3_label: _format_step_label(step3_label, 3, "Đi theo Mũi Tên Hướng Dẫn lấy Đồ", current_step > TutorialStep.FETCH_ITEM, current_step == TutorialStep.FETCH_ITEM)
	if step4_label: _format_step_label(step4_label, 4, "Quay lại Khán Giả nhấn [E] để Giao Đồ", current_step > TutorialStep.DELIVER_ITEM, current_step == TutorialStep.DELIVER_ITEM)

	if hint_label:
		match current_step:
			TutorialStep.MOVE:
				hint_label.text = "💡 Hãy bấm các phím W-A-S-D hoặc dùng Cần xoay Touch để di chuyển nhân vật!"
			TutorialStep.ACCEPT_QUEST:
				hint_label.text = "💡 Đi đến vị khán giả gần nhất có bong bóng ❗️ màu vàng và bấm [E] / Tap màn hình!"
			TutorialStep.FETCH_ITEM:
				hint_label.text = "💡 Mũi tên xanh quanh bạn sẽ chỉ đường đến Quầy Đồ Ăn/Ghế. Hãy bước lại gần và bấm [E]!"
			TutorialStep.DELIVER_ITEM:
				hint_label.text = "💡 Đồ đã có trong Túi! Mũi tên sẽ chỉ đường quay lại gặp Khán Giả để trao đồ!"
			TutorialStep.FINISHED:
				hint_label.text = "🎉 XUẤT SẮC! Bạn đã làm chủ nhiệm vụ Bảo Vệ Đêm Nhạc Hội!"

func _format_step_label(label: Label, step_num: int, text: String, is_done: bool, is_active: bool) -> void:
	if is_done:
		label.text = " ✅ Bước %d: %s" % [step_num, text]
		label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4, 1.0))
	elif is_active:
		label.text = " ➔ Bước %d: %s" % [step_num, text]
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	else:
		label.text = " ⚪ Bước %d: %s" % [step_num, text]
		label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 0.7))

func _on_skip_pressed() -> void:
	_play_click_sfx()
	_dismiss_card()

func _finish_walkthrough() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("mark_tutorial_completed"):
		gm.mark_tutorial_completed()

	walkthrough_completed.emit()

	# Chờ 3.5s rồi tự động ẩn bảng Hướng Dẫn
	get_tree().create_timer(3.5).timeout.connect(_dismiss_card)

func _dismiss_card() -> void:
	if _is_dismissing:
		return
	_is_dismissing = true

	if main_card:
		var tween = create_tween()
		tween.tween_property(main_card, "modulate:a", 0.0, 0.5)
		tween.finished.connect(queue_free)
	else:
		queue_free()

func _play_chime_sfx() -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_food_pickup_sfx"):
		sound_mgr.play_food_pickup_sfx(-6.0)

func _play_click_sfx() -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_food_pickup_sfx"):
		sound_mgr.play_food_pickup_sfx(-12.0)
