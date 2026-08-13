extends CanvasLayer

signal dialogue_started()
signal intro_finished()
signal line_advanced(line_index: int)

@onready var control_root: Control = $Control
@onready var dialogue_panel: PanelContainer = $Control/MarginContainer/DialoguePanel
@onready var speaker_name_label: Label = $Control/MarginContainer/DialoguePanel/Margin/VBox/SpeakerNameLabel
@onready var text_label: Label = $Control/MarginContainer/DialoguePanel/Margin/VBox/TextLabel

@export var player_name: String = "Player (Bảo Vệ)"

@export_group("1. Intro / Tutorial Dialogue")
## Danh sách câu thoại Giới thiệu & Hướng dẫn cách chơi (chạy lần lượt khi zoom camera mở đầu game)
@export var intro_tutorial_dialogue_list: Array[String] = [
	"Chào mừng bạn! Tôi là Bảo Vệ đêm đại nhạc hội hôm nay.",
	"Sử dụng các phím A-W-S-D để di chuyển, giữ phím Shift để chạy nhanh.",
	"Hãy qua Quầy Đồ Ăn / Kho Ghế để lấy đồ và hỗ trợ khán giả kịp thời nhé!"
]

@export_group("2. Gameplay Dialogue (Random Loop)")
## Danh sách các câu thoại lặp lại NGẪU NHIÊN khi ĐANG CHƠI GAME
@export var gameplay_dialogue_list: Array[String] = [
	"Tôi là Bảo Vệ đêm nhạc. Tôi sẽ hỗ trợ khán giả và giữ gìn an ninh!",
	"Khu vực sân khấu đang rất đông vui, hãy chú ý di chuyển trật tự nhé.",
	"Nếu khán giả nào cần đồ ăn hoặc ghế ngồi, tôi sẽ đến hỗ trợ ngay!",
	"Đêm hòa nhạc hôm nay thật bùng nổ và cuồng nhiệt!"
]

## Tốc độ gõ chữ (ký tự / giây)
@export var characters_per_second: float = 30.0
## Thời gian hiển thị mỗi câu thoại sau khi gõ xong (giây)
@export var display_duration_per_line: float = 3.5
@export var enable_typewriter_sound: bool = true

enum DialoguePhase { INTRO_TUTORIAL, GAMEPLAY_RANDOM }
var current_phase: DialoguePhase = DialoguePhase.INTRO_TUTORIAL

var tex_frame_dialogue: Texture2D = preload("res://Sprites/UI_Flat_Frame01a.png")

var _current_line_index: int = 0
var _last_random_index: int = -1
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
	if speaker_name_label:
		speaker_name_label.text = player_name

	control_root.visible = true
	dialogue_started.emit()
	
	current_phase = DialoguePhase.INTRO_TUTORIAL
	_current_line_index = 0
	_display_current_line()

func _display_current_line() -> void:
	var text_content: String = ""
	
	if current_phase == DialoguePhase.INTRO_TUTORIAL:
		if intro_tutorial_dialogue_list.is_empty() or _current_line_index >= intro_tutorial_dialogue_list.size():
			# Hoàn thành Phase 1 (Intro/Tutorial) -> Chuyển sang Phase 2 (Gameplay Random)
			current_phase = DialoguePhase.GAMEPLAY_RANDOM
			intro_finished.emit()
			_pick_next_random_gameplay_line()
			return
		else:
			text_content = intro_tutorial_dialogue_list[_current_line_index]
			
	elif current_phase == DialoguePhase.GAMEPLAY_RANDOM:
		if gameplay_dialogue_list.is_empty():
			control_root.visible = false
			return
		text_content = gameplay_dialogue_list[_current_line_index]

	text_label.text = text_content
	text_label.visible_characters = 0
	_visible_chars_float = 0.0
	_read_timer = 0.0
	_is_typing = true
	
	line_advanced.emit(_current_line_index)

func _pick_next_random_gameplay_line() -> void:
	if gameplay_dialogue_list.is_empty():
		control_root.visible = false
		return
		
	var next_idx = randi() % gameplay_dialogue_list.size()
	if gameplay_dialogue_list.size() > 1 and next_idx == _last_random_index:
		next_idx = (_last_random_index + 1) % gameplay_dialogue_list.size()
		
	_last_random_index = next_idx
	_current_line_index = next_idx
	_display_current_line()

func _process(delta: float) -> void:
	if not control_root or not control_root.visible:
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
			if current_phase == DialoguePhase.INTRO_TUTORIAL:
				_current_line_index += 1
				_display_current_line()
			else:
				_pick_next_random_gameplay_line()

func _play_typewriter_sfx() -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_food_pickup_sfx"):
		sound_mgr.play_food_pickup_sfx(-18.0)
