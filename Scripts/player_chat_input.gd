extends CanvasLayer
class_name PlayerChatInput

@onready var control_root: Control = $Control
@onready var line_edit: LineEdit = find_child("LineEdit", true, false) as LineEdit
@onready var send_button: Button = find_child("SendButton", true, false) as Button
@onready var chat_toggle_button: Button = find_child("ChatToggleButton", true, false) as Button

func _ready() -> void:
	layer = 16 # Render above HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	if control_root:
		control_root.visible = false
		
	if send_button and not send_button.pressed.is_connected(_on_send_pressed):
		send_button.pressed.connect(_on_send_pressed)
		
	if line_edit and not line_edit.text_submitted.is_connected(_on_text_submitted):
		line_edit.text_submitted.connect(_on_text_submitted)
		
	if chat_toggle_button and not chat_toggle_button.pressed.is_connected(toggle_chat_input):
		chat_toggle_button.pressed.connect(toggle_chat_input)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if control_root and not control_root.visible:
				open_chat_input()
				get_viewport().set_input_as_handled()
			elif control_root and control_root.visible:
				_on_send_pressed()
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and control_root and control_root.visible:
			close_chat_input()
			get_viewport().set_input_as_handled()

func open_chat_input() -> void:
	var tree = get_tree()
	if tree and tree.current_scene and tree.current_scene.scene_file_path.contains("main_menu"):
		return
		
	if control_root:
		control_root.visible = true
		
	if line_edit:
		line_edit.text = ""
		line_edit.grab_focus()
		
	var player = tree.get_first_node_in_group("player") if tree else null
	if player:
		player.set("is_chat_typing", true)

func close_chat_input() -> void:
	if control_root:
		control_root.visible = false
		
	if line_edit:
		line_edit.release_focus()
		
	var tree = get_tree()
	var player = tree.get_first_node_in_group("player") if tree else null
	if player:
		player.set("is_chat_typing", false)

func toggle_chat_input() -> void:
	if control_root and control_root.visible:
		close_chat_input()
	else:
		open_chat_input()

func _on_send_pressed() -> void:
	if line_edit:
		_send_message(line_edit.text)

func _on_text_submitted(text: String) -> void:
	_send_message(text)

func _send_message(text: String) -> void:
	var clean_text = text.strip_edges()
	if not clean_text.is_empty():
		var tree = get_tree()
		var player = tree.get_first_node_in_group("player") if tree else null
		if player and player.has_method("say"):
			player.say(clean_text)
			
		var dialogue_box = get_node_or_null("/root/DialogueBox")
		if dialogue_box and dialogue_box.has_method("_set_dialogue_text"):
			dialogue_box._set_dialogue_text(clean_text)
			if "control_root" in dialogue_box and dialogue_box.control_root:
				dialogue_box.control_root.visible = true
				
		var sound_mgr = get_node_or_null("/root/SoundManager")
		if sound_mgr and sound_mgr.has_method("play_food_pickup_sfx"):
			sound_mgr.play_food_pickup_sfx(-10.0)

	close_chat_input()
