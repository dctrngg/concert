extends CanvasLayer
class_name LevelResultDialog

@onready var header_label: Label = find_child("HeaderLabel", true, false) as Label
@onready var subtitle_label: Label = find_child("SubTitleLabel", true, false) as Label
@onready var result_status_label: Label = find_child("ResultStatusLabel", true, false) as Label
@onready var stars_label: Label = find_child("StarsLabel", true, false) as Label
@onready var score_label: Label = find_child("ScoreLabel", true, false) as Label
@onready var req_score_label: Label = find_child("ReqScoreLabel", true, false) as Label

@onready var retry_btn: Button = find_child("RetryButton", true, false) as Button
@onready var next_btn: Button = find_child("NextButton", true, false) as Button
@onready var select_btn: Button = find_child("SelectMenuButton", true, false) as Button

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if retry_btn and not retry_btn.pressed.is_connected(_on_retry_pressed):
		retry_btn.pressed.connect(_on_retry_pressed)
	if next_btn and not next_btn.pressed.is_connected(_on_next_pressed):
		next_btn.pressed.connect(_on_next_pressed)
	if select_btn and not select_btn.pressed.is_connected(_on_select_pressed):
		select_btn.pressed.connect(_on_select_pressed)

	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("level_completed"):
		if not gm.level_completed.is_connected(_on_level_completed):
			gm.level_completed.connect(_on_level_completed)

func _on_level_completed(score: int, stars: int, is_passed: bool) -> void:
	visible = true
	if get_tree():
		get_tree().paused = true
	
	var gm = get_node_or_null("/root/GameManager")
	var lvl_data = gm.get_current_level_data() if (gm and gm.has_method("get_current_level_data")) else {}
	var lvl_title = lvl_data.get("title", "Cấp độ hiện tại")
	
	if header_label:
		header_label.text = "🏆 KẾT QUẢ MÀN CHƠI"
	if subtitle_label:
		subtitle_label.text = str(lvl_title).to_upper()
	
	if is_passed:
		if result_status_label:
			result_status_label.text = "🎉 CHÚC MỪNG VƯỢT MÀN! 🎉"
			result_status_label.set("theme_override_colors/font_color", Color(0.18, 0.55, 0.22, 1))
		if get_tree():
			var stage_node = get_tree().get_first_node_in_group("concert_stage")
			if stage_node and stage_node.has_method("burst_confetti"):
				stage_node.burst_confetti()
	else:
		var fail_msg = "❌ CHƯA ĐẠT YÊU CẦU MÀN CHƠI"
		if gm and "game_over_reason" in gm:
			match gm.game_over_reason:
				"CONCERT_CHAOS_MAXED":
					fail_msg = "💥 HỦY ĐÊM DIỄN! HỖN LOẠN VƯỢT TẦM KIỂM SOÁT (100% CHAOS)!"
				"PLAYER_FAINTED":
					fail_msg = "😵 GỤC ĐỔ! BẢO VỆ KIỆT SỨC NGẤT XỈU DO ÁP LỰC QUÁ LỚN!"
		if result_status_label:
			result_status_label.text = fail_msg
			result_status_label.set("theme_override_colors/font_color", Color(0.85, 0.15, 0.15, 1))
		
	var stars_text = ""
	match stars:
		0: stars_text = "☆☆☆ (0/3 Sao)"
		1: stars_text = "★☆☆ (1/3 Sao)"
		2: stars_text = "★★☆ (2/3 Sao)"
		3: stars_text = "★★★ (3/3 Sao - Xuất Sắc!)"
		
	if stars_label:
		stars_label.text = stars_text
	
	var min_thresh = 150
	if "star_thresholds" in lvl_data and lvl_data["star_thresholds"].size() > 0:
		min_thresh = lvl_data["star_thresholds"][0]
		
	if score_label:
		score_label.text = "Tổng điểm đạt được: %d điểm" % score
	if req_score_label:
		req_score_label.text = "Mục tiêu 1 Sao: %d điểm" % min_thresh
	
	# Handle next level button visibility
	if is_passed and gm and gm.has_method("has_next_level") and gm.has_next_level():
		if next_btn: next_btn.visible = true
	else:
		if next_btn: next_btn.visible = false

func _on_retry_pressed() -> void:
	visible = false
	if get_tree(): get_tree().paused = false
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("retry_current_level"):
		gm.retry_current_level()

func _on_next_pressed() -> void:
	visible = false
	if get_tree(): get_tree().paused = false
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("next_level"):
		gm.next_level()

func _on_select_pressed() -> void:
	visible = false
	if get_tree():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scene/level_select.tscn")
