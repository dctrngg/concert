extends CanvasLayer
class_name LevelResultDialog

@onready var header_label: Label = $Control/Panel/VBox/HeaderLabel
@onready var subtitle_label: Label = $Control/Panel/VBox/SubTitleLabel
@onready var result_status_label: Label = $Control/Panel/VBox/ResultStatusLabel
@onready var stars_label: Label = $Control/Panel/VBox/StarsLabel
@onready var score_label: Label = $Control/Panel/VBox/ScoreLabel
@onready var req_score_label: Label = $Control/Panel/VBox/ReqScoreLabel

@onready var retry_btn: Button = $Control/Panel/VBox/ButtonHBox/RetryButton
@onready var next_btn: Button = $Control/Panel/VBox/ButtonHBox/NextButton
@onready var select_btn: Button = $Control/Panel/VBox/ButtonHBox/SelectMenuButton

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	retry_btn.pressed.connect(_on_retry_pressed)
	next_btn.pressed.connect(_on_next_pressed)
	select_btn.pressed.connect(_on_select_pressed)

	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.level_completed.connect(_on_level_completed)

func _on_level_completed(score: int, stars: int, is_passed: bool) -> void:
	visible = true
	get_tree().paused = true
	
	var gm = get_node_or_null("/root/GameManager")
	var lvl_data = gm.get_current_level_data() if gm else {}
	var lvl_title = lvl_data.get("title", "Cấp độ")
	
	if header_label:
		header_label.text = "TỔNG KẾT MÀN CHƠI"
	if subtitle_label:
		subtitle_label.text = lvl_title
	
	if is_passed:
		result_status_label.text = "🎉 VƯỢT QUA VÒNG CHƠI! 🎉"
		result_status_label.modulate = Color(0.3, 1.0, 0.5)
	else:
		result_status_label.text = "❌ CHƯA ĐẠT YÊU CẦU MÀN CHƠI!"
		result_status_label.modulate = Color(1.0, 0.35, 0.35)
		
	var stars_text = ""
	match stars:
		0: stars_text = "☆☆☆ (0/3 Sao)"
		1: stars_text = "★☆☆ (1/3 Sao)"
		2: stars_text = "★★☆ (2/3 Sao)"
		3: stars_text = "★★★ (3/3 Sao - Xuất Sắc!)"
	stars_label.text = stars_text
	
	var min_thresh = lvl_data.get("star_thresholds", [150])[0]
	if score_label:
		score_label.text = "Tổng điểm đạt được: %d điểm" % score
	if req_score_label:
		req_score_label.text = "(Yêu cầu 1 Sao: %d điểm)" % min_thresh
	
	# Xử lý ẩn/hiện nút Màn tiếp theo
	if is_passed and gm and gm.has_next_level():
		next_btn.visible = true
	else:
		next_btn.visible = false

func _on_retry_pressed() -> void:
	visible = false
	get_tree().paused = false
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.retry_current_level()

func _on_next_pressed() -> void:
	visible = false
	get_tree().paused = false
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.next_level()

func _on_select_pressed() -> void:
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scene/level_select.tscn")
