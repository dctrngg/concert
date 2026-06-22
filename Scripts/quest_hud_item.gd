extends PanelContainer
class_name QuestHudItem

@onready var quest_title_label: Label = $MarginContainer/VBox/TitleRow/QuestTitle
@onready var time_label: Label = $MarginContainer/VBox/TitleRow/TimeLabel
@onready var progress_bar: ProgressBar = $MarginContainer/VBox/TimeBar
@onready var status_label: Label = $MarginContainer/VBox/StatusLabel

var _quest_data: NPCQuestData = null

func setup(quest: NPCQuestData) -> void:
	_quest_data = quest
	quest_title_label.text = quest.title
	progress_bar.max_value = quest.time_limit
	progress_bar.value = quest.time_limit
	time_label.text = "%ds" % int(quest.time_limit)
	status_label.text = "Chưa lấy hàng..."
	_update_bar_color(1.0)

func update_timer(time_left: float) -> void:
	if _quest_data == null:
		return
	progress_bar.value = time_left
	time_label.text = "%ds" % max(0, int(time_left))
	
	var ratio = time_left / _quest_data.time_limit
	_update_bar_color(ratio)

func update_status(is_picked_up: bool) -> void:
	if is_picked_up:
		status_label.text = "✓ Đã lấy hàng — Hãy giao ngay!"
		status_label.add_theme_color_override("font_color", Color(0.180392, 0.8, 0.443137, 1))
	else:
		status_label.text = "Chưa lấy hàng..."
		status_label.remove_theme_color_override("font_color")

func _update_bar_color(ratio: float) -> void:
	var fill_style = progress_bar.get_theme_stylebox("fill")
	if not fill_style is StyleBoxFlat:
		return
	
	var fill = fill_style as StyleBoxFlat
	if ratio > 0.5:
		# Xanh lá
		fill.bg_color = Color(0.180392, 0.8, 0.443137, 1)
	elif ratio > 0.25:
		# Vàng cam
		fill.bg_color = Color(0.952941, 0.611765, 0.070588, 1)
	else:
		# Đỏ — tween nhấp nháy nhẹ
		fill.bg_color = Color(0.901961, 0.298039, 0.235294, 1)
		_pulse_red()

func _pulse_red() -> void:
	var tween = create_tween()
	tween.set_loops(1)
	tween.tween_property(progress_bar, "modulate", Color(1, 0.4, 0.4, 1), 0.3)
	tween.tween_property(progress_bar, "modulate", Color(1, 1, 1, 1), 0.3)

func get_quest_id() -> String:
	return _quest_data.quest_id if _quest_data else ""
