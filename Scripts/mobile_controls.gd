extends CanvasLayer
class_name MobileControls

@onready var joystick_base: Control = $Control/JoystickArea/Base
@onready var joystick_knob: Control = $Control/JoystickArea/Base/Knob
@onready var interact_btn: Button = $Control/ActionArea/InteractButton
@onready var sprint_btn: Button = $Control/ActionArea/SprintButton

var _is_dragging_joystick: bool = false
var _joystick_touch_index: int = -1
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_radius: float = 60.0
var _output_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("mobile_controls")
	layer = 12
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if interact_btn:
		interact_btn.button_down.connect(_on_interact_down)
		interact_btn.button_up.connect(_on_interact_up)
		
	if sprint_btn:
		sprint_btn.button_down.connect(_on_sprint_down)
		sprint_btn.button_up.connect(_on_sprint_up)

	call_deferred("_init_default_off")

func _init_default_off() -> void:
	set_controls_visible(false)

func is_mobile_device() -> bool:
	if DisplayServer.has_feature(DisplayServer.FEATURE_TOUCHSCREEN):
		return true
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios"):
		return true
	if OS.has_feature("web"):
		if JavaScriptBridge.eval("/Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent)") == true:
			return true
		if JavaScriptBridge.eval("navigator.maxTouchPoints && navigator.maxTouchPoints > 0") == true:
			return true
	return false

func set_controls_visible(should_be_visible: bool) -> void:
	visible = should_be_visible
	_update_minimap_visibility()

func toggle_mobile_controls() -> void:
	set_controls_visible(not visible)

func _update_minimap_visibility() -> void:
	var tree = get_tree()
	if not tree:
		return
	var minimap = tree.get_first_node_in_group("minimap")
	if not minimap:
		var hud = tree.get_first_node_in_group("hud")
		if hud:
			minimap = hud.find_child("Minimap", true, false)
	if minimap:
		# Khi bật Touch UI trên điện thoại -> Tự động ẨN Minimap để thoáng màn hình
		minimap.visible = not visible

func _input(event: InputEvent) -> void:
	if not visible:
		return
		
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pos = event.position
		var is_pressed = event.pressed if event is InputEventScreenTouch else (event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
		var touch_id = (event as InputEventScreenTouch).index if event is InputEventScreenTouch else 0
		
		if is_pressed:
			# Kiểm tra xem chạm vào nửa bên trái màn hình (khu vực Joystick)
			var vp_size = get_viewport().get_visible_rect().size
			if pos.x < vp_size.x * 0.5 and pos.y > vp_size.y * 0.3:
				_is_dragging_joystick = true
				_joystick_touch_index = touch_id
				_joystick_center = joystick_base.global_position + joystick_base.size / 2.0
				_update_joystick(pos)
		else:
			if touch_id == _joystick_touch_index or not is_pressed:
				_reset_joystick()

	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and _is_dragging_joystick):
		var touch_id = (event as InputEventScreenDrag).index if event is InputEventScreenDrag else 0
		if touch_id == _joystick_touch_index or _is_dragging_joystick:
			_update_joystick(event.position)

func _update_joystick(touch_pos: Vector2) -> void:
	var diff = touch_pos - _joystick_center
	var dist = diff.length()
	var clamped_diff = diff.limit_length(_joystick_radius)
	
	if joystick_knob:
		joystick_knob.position = (joystick_base.size / 2.0) + clamped_diff - (joystick_knob.size / 2.0)
		
	if dist > 8.0:
		_output_vector = diff.normalized() * min(1.0, dist / _joystick_radius)
	else:
		_output_vector = Vector2.ZERO
		
	_apply_mobile_vector_to_player()

func _reset_joystick() -> void:
	_is_dragging_joystick = false
	_joystick_touch_index = -1
	_output_vector = Vector2.ZERO
	if joystick_knob:
		joystick_knob.position = (joystick_base.size / 2.0) - (joystick_knob.size / 2.0)
	_apply_mobile_vector_to_player()

func _apply_mobile_vector_to_player() -> void:
	var tree = get_tree()
	var player = tree.get_first_node_in_group("player") if tree else null
	if player and "mobile_input_vector" in player:
		player.mobile_input_vector = _output_vector

func _on_interact_down() -> void:
	var event = InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)

func _on_interact_up() -> void:
	var event = InputEventAction.new()
	event.action = "interact"
	event.pressed = false
	Input.parse_input_event(event)

func _on_sprint_down() -> void:
	var event = InputEventAction.new()
	event.action = "run"
	event.pressed = true
	Input.parse_input_event(event)

func _on_sprint_up() -> void:
	var event = InputEventAction.new()
	event.action = "run"
	event.pressed = false
	Input.parse_input_event(event)

# toggle_mobile_controls is already defined above with minimap update
