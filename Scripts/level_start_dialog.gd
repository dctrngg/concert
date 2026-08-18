extends CanvasLayer

signal play_pressed()

@export_group("Customizable Camera & Intro Config")
## Độ lệch vị trí Camera sang phải (pixels)
@export var intro_camera_offset: Vector2 = Vector2(60.0, 0.0)
## Độ Zoom camera khi đang mở bảng intro (2.4 = nhìn toàn cảnh rộng hơn)
@export var intro_camera_zoom: Vector2 = Vector2(2.4, 2.4)
## Độ Zoom camera khi bắt đầu chơi game
@export var gameplay_camera_zoom: Vector2 = Vector2(2.8, 2.8)
## Thời gian chuyển động mượt của Camera (giây)
@export var transition_duration: float = 0.65

@onready var play_button: Button = find_child("PlayButton", true, false) as Button
@onready var main_card: PanelContainer = find_child("MainCard", true, false) as PanelContainer
@onready var level_title_label: Label = find_child("LevelTitleLabel", true, false) as Label
@onready var time_label: Label = find_child("TimeLabel", true, false) as Label
@onready var target_label: Label = find_child("TargetLabel", true, false) as Label

var _camera: Camera2D = null
var _player: Node2D = null
var _is_starting: bool = false

func _ready() -> void:
	add_to_group("level_start_dialog")
	layer = 18 # Render above HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if play_button and not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
		
	call_deferred("_setup_intro_camera_and_level_data")

func _setup_intro_camera_and_level_data() -> void:
	# Fetch Level Config Data from GameManager
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("get_current_level_data"):
		var lvl_data = game_mgr.get_current_level_data()
		if lvl_data:
			if level_title_label and "level_name" in lvl_data:
				level_title_label.text = "🎮 " + str(lvl_data["level_name"]).to_upper()
			elif level_title_label and "level_id" in lvl_data:
				level_title_label.text = "🎮 MÀN %d: ĐÊM ĐẠI NHẠC HỘI" % lvl_data["level_id"]
				
			if time_label and "time_limit" in lvl_data:
				var mins = int(lvl_data["time_limit"]) / 60
				var secs = int(lvl_data["time_limit"]) % 60
				time_label.text = "⏱️ Thời gian: %02d:%02d" % [mins, secs]
			if target_label and "star_thresholds" in lvl_data:
				var stars = lvl_data["star_thresholds"]
				if stars.size() > 0:
					target_label.text = "🏆 Mục tiêu 1⭐: %d điểm" % stars[0]

	# Lock player movement during intro and set initial camera offset and zoom
	var tree = get_tree()
	if not tree or not is_inside_tree():
		return
	_player = tree.get_first_node_in_group("player") as Node2D
	if _player:
		_player.set("is_intro_locked", true)
		_camera = _player.get_node_or_null("Camera2D") as Camera2D
		if _camera:
			_camera.position = intro_camera_offset
			_camera.offset = intro_camera_offset
			if _player.get("intro_zoom_start") != null:
				var z_start = float(_player.get("intro_zoom_start"))
				_camera.zoom = Vector2(z_start, z_start)
			else:
				_camera.zoom = intro_camera_zoom

func _on_play_pressed() -> void:
	if _is_starting:
		return
	_is_starting = true
	
	if play_button:
		play_button.disabled = true
		
	# Play SFX safely if SoundManager exists
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_sfx"):
		sound_mgr.play_sfx("res://Audio/click.wav")
		
	# Trigger player camera transition (slides offset to center AND zooms from intro_zoom_start -> intro_zoom_end!)
	if _player and _player.has_method("start_play_camera_transition"):
		_player.start_play_camera_transition()
	elif _player:
		_player.set("is_intro_locked", false)
		
	# Fade out intro UI card
	var tween = create_tween()
	if main_card:
		tween.tween_property(main_card, "modulate:a", 0.0, 0.4)
		
	tween.finished.connect(func():
		play_pressed.emit()
		queue_free()
	)
