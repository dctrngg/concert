extends CanvasLayer

signal dialogue_started()
signal dialogue_finished()
signal line_advanced(line_index: int)

@onready var control_root: Control = $Control
@onready var dialogue_panel: PanelContainer = $Control/MarginContainer/DialoguePanel
@onready var speaker_name_label: Label = $Control/MarginContainer/DialoguePanel/Margin/VBox/SpeakerNameLabel
@onready var text_label: Label = $Control/MarginContainer/DialoguePanel/Margin/VBox/TextLabel

@export var player_name: String = "Player (Bảo Vệ)"

## 📝 DANH SÁCH CÂU THOẠI BẠN CHUẨN BỊ TRƯỚC TẠI ĐÂY:
## Bạn có thể tự do thêm, bớt hoặc thay đổi các câu thoại trong mảng này!
@export var my_dialogue_list: Array[String] = [
	"Tôi là Bảo Vệ đêm nhạc. Tôi sẽ hỗ trợ khán giả và giữ gìn an ninh!",
	"Khu vực sân khấu đang rất đông vui, hãy chú ý di chuyển trật tự nhé.",
	"Nếu khán giả nào cần đồ ăn hoặc ghế ngồi, tôi sẽ đến hỗ trợ ngay!",
	"Đêm hòa nhạc hôm nay thật bùng nổ và cuồng nhiệt!"
]

## Tốc độ gõ chữ (ký tự / giây)
@export var characters_per_second: float = 30.0
## Thời gian hiển thị mỗi câu thoại sau khi gõ xong (giây)
@export var display_duration_per_line: float = 3.5
## Tự động lặp lại từ đầu khi đọc hết danh sách
@export var loop_forever: bool = true
@export var enable_typewriter_sound: bool = true

var tex_frame_dialogue: Texture2D = preload("res://Sprites/UI_Flat_Frame01a.png")

var _current_line_index: int = 0
var _is_typing: bool = false
var _visible_chars_float: float = 0.0
var _read_timer: float = 0.0

func _ready() -> void:
	layer = 15 # Hiển thị trên cùng đè lên HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_apply_styles()
	call_deferred("_start_auto_dialogue")

func _apply_styles() -> void:
	if dialogue_panel:
		var style_d = StyleBoxTexture.new()
		style_d.texture = tex_frame_dialogue
		style_d.texture_margin_left = 16
		style_d.texture_margin_top = 14
		style_d.texture_margin_right = 16
		style_d.texture_margin_bottom = 14
		dialogue_panel.add_theme_stylebox_override("panel", style_d)

func _start_auto_dialogue() -> void:
	if my_dialogue_list.is_empty():
		if control_root:
			control_root.visible = false
		return
		
	if speaker_name_label:
		speaker_name_label.text = player_name

	control_root.visible = true
	dialogue_started.emit()
	
	_current_line_index = 0
	_display_current_line()

func _display_current_line() -> void:
	if _current_line_index < 0 or _current_line_index >= my_dialogue_list.size():
		if loop_forever and not my_dialogue_list.is_empty():
			_current_line_index = 0
		else:
			control_root.visible = false
			dialogue_finished.emit()
			return

	var text_content = my_dialogue_list[_current_line_index]
	text_label.text = text_content
	text_label.visible_characters = 0
	_visible_chars_float = 0.0
	_read_timer = 0.0
	_is_typing = true
	
	line_advanced.emit(_current_line_index)

func _process(delta: float) -> void:
	if not control_root or not control_root.visible or my_dialogue_list.is_empty():
		return

	if _is_typing:
		var total_chars = text_label.text.length()
		if text_label.visible_characters < total_chars:
			_visible_chars_float += characters_per_second * delta
			var prev_count = text_label.visible_characters
			text_label.visible_characters = int(_visible_chars_float)
			
			if enable_typewriter_sound and text_label.visible_characters > prev_count:
				if text_label.visible_characters % 3 == 0:
					_play_typewriter_sfx()
		else:
			_is_typing = false
			_read_timer = 0.0
	else:
		_read_timer += delta
		if _read_timer >= display_duration_per_line:
			_read_timer = 0.0
			_current_line_index += 1
			_display_current_line()

func _play_typewriter_sfx() -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_food_pickup_sfx"):
		sound_mgr.play_food_pickup_sfx(-18.0)
