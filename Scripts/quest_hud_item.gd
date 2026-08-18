extends PanelContainer
class_name QuestHudItem

@onready var quest_title_label: Label = find_child("QuestTitle", true, false) as Label
@onready var time_label: Label = find_child("TimeLabel", true, false) as Label
@onready var quest_icon: TextureRect = find_child("QuestIcon", true, false) as TextureRect
@onready var progress_bar: ProgressBar = find_child("TimeBar", true, false) as ProgressBar
@onready var status_label: Label = find_child("StatusLabel", true, false) as Label

var _quest_data: NPCQuestData = null

func setup(quest: NPCQuestData) -> void:
	_quest_data = quest
	quest_title_label.text = quest.title
	
	if quest_icon:
		if quest.item_icon_path != "" and ResourceLoader.exists(quest.item_icon_path):
			quest_icon.texture = load(quest.item_icon_path)
			quest_icon.visible = true
		else:
			quest_icon.visible = false
			
	progress_bar.max_value = quest.time_limit
	progress_bar.value = quest.time_limit
	time_label.text = "%ds" % int(quest.time_limit)
	update_status(quest.is_item_picked_up)
	_update_bar_color(1.0)


func update_timer(time_left: float) -> void:
	if _quest_data == null:
		return
	progress_bar.value = time_left
	time_label.text = "%ds" % max(0, int(time_left))
	
	var ratio = time_left / _quest_data.time_limit
	_update_bar_color(ratio)

func update_status(is_picked_up: bool) -> void:
	if _quest_data == null:
		return
		
	match _quest_data.quest_type:
		NPCQuestData.QuestType.FOOD_DELIVERY:
			if is_picked_up:
				status_label.text = "✓ Đã lấy đồ ăn — Hãy giao ngay!"
				status_label.add_theme_color_override("font_color", Color(0.18, 0.8, 0.44, 1))
			else:
				status_label.text = "Chưa lấy đồ ăn..."
				status_label.remove_theme_color_override("font_color")
				
		NPCQuestData.QuestType.SEAT_FINDER:
			if is_picked_up:
				status_label.text = "✓ Đã lấy ghế — Hãy mang cho khán giả!"
				status_label.add_theme_color_override("font_color", Color(0.18, 0.8, 0.44, 1))
			else:
				status_label.text = "Chưa lấy ghế từ kho..."
				status_label.remove_theme_color_override("font_color")
				
		NPCQuestData.QuestType.MERCH_SELLING:
			if is_picked_up:
				status_label.text = "✓ Đã bán đủ chỉ tiêu!"
				status_label.add_theme_color_override("font_color", Color(0.18, 0.8, 0.44, 1))
			else:
				status_label.text = "Đã bán: %d/%d sản phẩm" % [_quest_data.merch_sold_count, _quest_data.merch_target_count]
				status_label.remove_theme_color_override("font_color")

		NPCQuestData.QuestType.INTERVENTION:
			if is_picked_up:
				status_label.text = "✓ Đã dẹp xong cuộc đánh nhau!"
				status_label.add_theme_color_override("font_color", Color(0.18, 0.8, 0.44, 1))
			else:
				status_label.text = "Ấn giữ [E] để cản đánh nhau!"
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
