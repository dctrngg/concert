extends CanvasLayer

signal dialogue_started()
signal tutorial_completed()
signal line_advanced(line_index: int)

@onready var control_root: Control = $Control
@onready var dialogue_panel: PanelContainer = find_child("DialoguePanel", true, false) as PanelContainer
@onready var speaker_name_label: Label = find_child("SpeakerNameLabel", true, false) as Label
@onready var text_label: Label = find_child("TextLabel", true, false) as Label

@export var player_name: String = "dctrng"

@export_group("1. Dynamic Guided Tutorial Lines")
@export var tutorial_welcome_text: String = "Chào mừng bạn đến với Đêm Đại Nhạc Hội! Tôi là Bảo Vệ chịu trách nhiệm an ninh và hỗ trợ khán giả hôm nay."
@export var tutorial_greeting_text: String = "Sử dụng các phím A-W-S-D để di chuyển. Hãy lại gần vị khán giả có dấu (!) gần nhất để nhận nhiệm vụ nhé!"
@export var tutorial_accepted_text: String = "Rất tốt! Hãy đi theo Mũi Tên Chỉ Đường đến quầy tương ứng để lấy món đồ khán giả cần nhé!"
@export var tutorial_item_text: String = "Món đồ đã có trong túi! Hãy quay lại gặp vị khán giả đó và nhấn [E] / Click chuột để giao đồ nhé!"
@export var tutorial_done_text: String = "Hoàn hảo! Bạn đã nắm vững cách làm Bảo Vệ. Đêm đại nhạc hội bùng nổ chính thức bắt đầu!"

@export_group("2. Gameplay Dialogue (Random Loop)")
## Danh sách các câu thoại lặp lại NGẪU NHIÊN khi ĐANG CHƠI GAME
@export var gameplay_dialogue_list: Array[String] = [
	"Tôi là Bảo Vệ đêm nhạc. Tôi sẽ hỗ trợ khán giả và giữ gìn an ninh!",
	"Khu vực sân khấu đang rất đông vui, hãy chú ý di chuyển trật tự nhé.",
	"Nếu khán giả nào cần đồ ăn hoặc ghế ngồi, tôi sẽ đến hỗ trợ ngay!",
	"Đêm hòa nhạc hôm nay thật bùng nổ và cuồng nhiệt!"
]

## Tốc độ gõ chữ (ký tự / giây)
@export var characters_per_second: float = 65.0
## Thời gian hiển thị mỗi câu thoại sau khi gõ xong (giây)
@export var display_duration_per_line: float = 3.5
@export var enable_typewriter_sound: bool = true

enum DialoguePhase { TUTORIAL_GUIDE, GAMEPLAY_RANDOM }
enum TutorialState { WELCOME, GREETING, QUEST_ACCEPTED, ITEM_PICKED_UP, COMPLETED }

var current_phase: DialoguePhase = DialoguePhase.TUTORIAL_GUIDE
var tutorial_state: TutorialState = TutorialState.WELCOME

var _last_random_index: int = -1
var _is_typing: bool = false
var _visible_chars_float: float = 0.0
var _read_timer: float = 0.0
var _current_text: String = ""

func _ready() -> void:
	layer = 15 # Hiển thị trên cùng đè lên HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	if control_root:
		control_root.visible = false
	
	_apply_styles()
	
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("level_started"):
		if not gm.level_started.is_connected(_on_level_started):
			gm.level_started.connect(_on_level_started)
			
	var tree = get_tree()
	if tree:
		tree.node_added.connect(_on_node_added)

	call_deferred("_check_level_start_dialog")
	call_deferred("_connect_quest_signals")

func _on_level_started(_level_info: Dictionary) -> void:
	if control_root:
		control_root.visible = false
	call_deferred("_check_level_start_dialog")
	call_deferred("_connect_quest_signals")

func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		call_deferred("_connect_quest_signals")
	elif node.is_in_group("level_start_dialog"):
		call_deferred("_check_level_start_dialog")

func _check_level_start_dialog() -> void:
	var tree = get_tree()
	if not tree:
		return
		
	# Nếu đang ở Main Menu thì ẩn DialogueBox
	if tree.current_scene and tree.current_scene.scene_file_path.contains("main_menu"):
		if control_root:
			control_root.visible = false
		return

	var start_dialog = tree.get_first_node_in_group("level_start_dialog")
	if not start_dialog and tree.root:
		start_dialog = tree.root.find_child("LevelStartDialog", true, false)
		
	if start_dialog:
		if control_root:
			control_root.visible = false
		if not start_dialog.play_pressed.is_connected(_start_auto_dialogue):
			start_dialog.play_pressed.connect(_start_auto_dialogue)
	else:
		_start_auto_dialogue()

func _apply_styles() -> void:
	pass

func _connect_quest_signals() -> void:
	var quest_mgr = get_node_or_null("/root/QuestManager")
	if quest_mgr:
		if not quest_mgr.quest_accepted.is_connected(_on_quest_accepted):
			quest_mgr.quest_accepted.connect(_on_quest_accepted)
		if not quest_mgr.quest_completed.is_connected(_on_quest_completed):
			quest_mgr.quest_completed.connect(_on_quest_completed)
			
	var tree = get_tree()
	var player = tree.get_first_node_in_group("player") if tree else null
	if player and player.get("inventory"):
		var inv = player.get("inventory")
		if inv and inv.has_signal("inventory_changed"):
			if not inv.inventory_changed.is_connected(_on_inventory_changed):
				inv.inventory_changed.connect(_on_inventory_changed)

func _start_auto_dialogue() -> void:
	if speaker_name_label:
		speaker_name_label.text = player_name

	control_root.visible = true
	dialogue_started.emit()
	
	current_phase = DialoguePhase.TUTORIAL_GUIDE
	tutorial_state = TutorialState.WELCOME
	_set_dialogue_text(tutorial_welcome_text)

func _set_dialogue_text(new_text: String) -> void:
	_current_text = new_text
	text_label.text = _current_text
	text_label.visible_characters = 0
	_visible_chars_float = 0.0
	_read_timer = 0.0
	_is_typing = true

func _on_quest_accepted(quest: NPCQuestData) -> void:
	if current_phase == DialoguePhase.TUTORIAL_GUIDE:
		if tutorial_state == TutorialState.GREETING or tutorial_state == TutorialState.WELCOME:
			tutorial_state = TutorialState.QUEST_ACCEPTED
			if quest.is_item_picked_up:
				tutorial_state = TutorialState.ITEM_PICKED_UP
				_set_dialogue_text(tutorial_item_text)
			else:
				_set_dialogue_text(tutorial_accepted_text)

func _on_inventory_changed() -> void:
	if current_phase == DialoguePhase.TUTORIAL_GUIDE and tutorial_state == TutorialState.QUEST_ACCEPTED:
		var quest_mgr = get_node_or_null("/root/QuestManager")
		if quest_mgr and "active_quests" in quest_mgr:
			for q in quest_mgr.active_quests:
				if q.is_item_picked_up:
					tutorial_state = TutorialState.ITEM_PICKED_UP
					_set_dialogue_text(tutorial_item_text)
					break

func _on_quest_completed(_quest: NPCQuestData) -> void:
	if current_phase == DialoguePhase.TUTORIAL_GUIDE:
		tutorial_state = TutorialState.COMPLETED
		_set_dialogue_text(tutorial_done_text)

func _pick_next_random_gameplay_line() -> void:
	if gameplay_dialogue_list.is_empty():
		control_root.visible = false
		return
		
	var next_idx = randi() % gameplay_dialogue_list.size()
	if gameplay_dialogue_list.size() > 1 and next_idx == _last_random_index:
		next_idx = (_last_random_index + 1) % gameplay_dialogue_list.size()
		
	_last_random_index = next_idx
	_set_dialogue_text(gameplay_dialogue_list[next_idx])

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
		if current_phase == DialoguePhase.TUTORIAL_GUIDE:
			if tutorial_state == TutorialState.WELCOME and _read_timer >= display_duration_per_line:
				tutorial_state = TutorialState.GREETING
				_set_dialogue_text(tutorial_greeting_text)
			elif tutorial_state == TutorialState.COMPLETED and _read_timer >= display_duration_per_line:
				current_phase = DialoguePhase.GAMEPLAY_RANDOM
				tutorial_completed.emit()
				_pick_next_random_gameplay_line()
		else:
			if _read_timer >= display_duration_per_line:
				_pick_next_random_gameplay_line()

func _play_typewriter_sfx() -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_food_pickup_sfx"):
		sound_mgr.play_food_pickup_sfx(-18.0)
