extends CanvasLayer

signal pause_toggled(is_paused: bool)

@onready var dim_overlay: ColorRect = find_child("DimOverlay", true, false) as ColorRect
@onready var main_card: PanelContainer = find_child("MainCard", true, false) as PanelContainer
@onready var main_buttons_vbox: VBoxContainer = find_child("MainButtonsVBox", true, false) as VBoxContainer
@onready var settings_vbox: VBoxContainer = find_child("SettingsVBox", true, false) as VBoxContainer

# Main Buttons
@onready var resume_button: Button = find_child("ResumeButton", true, false) as Button
@onready var settings_button: Button = find_child("SettingsButton", true, false) as Button
@onready var restart_button: Button = find_child("RestartButton", true, false) as Button
@onready var main_menu_button: Button = find_child("MainMenuButton", true, false) as Button

# Settings Controls
@onready var bgm_label: Label = find_child("BGMLabel", true, false) as Label
@onready var bgm_slider: HSlider = find_child("BGMSlider", true, false) as HSlider
@onready var bgm_minus_btn: Button = find_child("BGMMinusBtn", true, false) as Button
@onready var bgm_plus_btn: Button = find_child("BGMPlusBtn", true, false) as Button

@onready var sfx_label: Label = find_child("SFXLabel", true, false) as Label
@onready var sfx_slider: HSlider = find_child("SFXSlider", true, false) as HSlider
@onready var sfx_minus_btn: Button = find_child("SFXMinusBtn", true, false) as Button
@onready var sfx_plus_btn: Button = find_child("SFXPlusBtn", true, false) as Button

@onready var test_sfx_btn: Button = find_child("TestSFXBtn", true, false) as Button
@onready var touch_ui_button: Button = find_child("TouchUIButton", true, false) as Button
@onready var fps_button: Button = find_child("FPSButton", true, false) as Button
@onready var back_button: Button = find_child("BackButton", true, false) as Button

func _ready() -> void:
	layer = 20 # Render above HUD and dialogue box
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	_connect_signals()
	_update_settings_values()

func _connect_signals() -> void:
	if resume_button and not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)
	if settings_button and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if restart_button and not restart_button.pressed.is_connected(_on_restart_pressed):
		restart_button.pressed.connect(_on_restart_pressed)
	if main_menu_button and not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		main_menu_button.pressed.connect(_on_main_menu_pressed)
		
	if back_button and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	if touch_ui_button and not touch_ui_button.pressed.is_connected(_on_touch_ui_toggled):
		touch_ui_button.pressed.connect(_on_touch_ui_toggled)
	if fps_button and not fps_button.pressed.is_connected(_on_fps_toggled):
		fps_button.pressed.connect(_on_fps_toggled)
		
	# BGM controls
	if bgm_slider and not bgm_slider.value_changed.is_connected(_on_bgm_volume_changed):
		bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	if bgm_minus_btn and not bgm_minus_btn.pressed.is_connected(_on_bgm_minus_pressed):
		bgm_minus_btn.pressed.connect(_on_bgm_minus_pressed)
	if bgm_plus_btn and not bgm_plus_btn.pressed.is_connected(_on_bgm_plus_pressed):
		bgm_plus_btn.pressed.connect(_on_bgm_plus_pressed)

	# SFX controls
	if sfx_slider and not sfx_slider.value_changed.is_connected(_on_sfx_volume_changed):
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	if sfx_minus_btn and not sfx_minus_btn.pressed.is_connected(_on_sfx_minus_pressed):
		sfx_minus_btn.pressed.connect(_on_sfx_minus_pressed)
	if sfx_plus_btn and not sfx_plus_btn.pressed.is_connected(_on_sfx_plus_pressed):
		sfx_plus_btn.pressed.connect(_on_sfx_plus_pressed)

	# Test SFX
	if test_sfx_btn and not test_sfx_btn.pressed.is_connected(_on_test_sfx_pressed):
		test_sfx_btn.pressed.connect(_on_test_sfx_pressed)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var game_mgr = get_node_or_null("/root/GameManager")
		if game_mgr and game_mgr.get("is_level_active") and game_mgr.is_level_active:
			if visible and settings_vbox and settings_vbox.visible:
				_show_main_view()
			else:
				toggle_pause()
			get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	var should_pause = not get_tree().paused
	set_paused(should_pause)

func set_paused(should_pause: bool) -> void:
	get_tree().paused = should_pause
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.is_paused = should_pause
		
	visible = should_pause
	if should_pause:
		_show_main_view()
		_update_settings_values()
	pause_toggled.emit(should_pause)

var confirm_panel: PanelContainer = null
var _pending_action: Callable = Callable()

func _show_main_view() -> void:
	if main_buttons_vbox: main_buttons_vbox.visible = true
	if settings_vbox: settings_vbox.visible = false
	if confirm_panel: confirm_panel.visible = false

func _show_settings_view() -> void:
	if main_buttons_vbox: main_buttons_vbox.visible = false
	if settings_vbox: settings_vbox.visible = true
	if confirm_panel: confirm_panel.visible = false
	_update_settings_values()

func _show_confirmation_dialog(action_title: String, message: String, on_confirm: Callable) -> void:
	_pending_action = on_confirm
	if confirm_panel == null:
		_create_confirm_ui()
		
	if confirm_panel:
		var title_label = confirm_panel.find_child("ConfirmTitle", true, false) as Label
		if title_label: title_label.text = action_title
		
		var msg_label = confirm_panel.find_child("ConfirmMsg", true, false) as Label
		if msg_label: msg_label.text = message
		
		confirm_panel.visible = true
		if main_buttons_vbox: main_buttons_vbox.visible = false
		if settings_vbox: settings_vbox.visible = false

func _create_confirm_ui() -> void:
	confirm_panel = PanelContainer.new()
	confirm_panel.name = "ConfirmModal"
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.08, 0.18, 0.95)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.9, 0.3, 0.3, 0.8)
	confirm_panel.add_theme_stylebox_override("panel", style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	
	var title = Label.new()
	title.name = "ConfirmTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	
	var msg = Label.new()
	msg.name = "ConfirmMsg"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 14)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	
	var yes_btn = Button.new()
	yes_btn.text = "✅ Đồng Ý"
	yes_btn.custom_minimum_size = Vector2(100, 36)
	yes_btn.pressed.connect(func():
		if confirm_panel: confirm_panel.visible = false
		if _pending_action.is_valid():
			_pending_action.call()
	)
	
	var no_btn = Button.new()
	no_btn.text = "❌ Hủy Bỏ"
	no_btn.custom_minimum_size = Vector2(100, 36)
	no_btn.pressed.connect(func():
		if confirm_panel: confirm_panel.visible = false
		_show_main_view()
	)
	
	hbox.add_child(yes_btn)
	hbox.add_child(no_btn)
	
	vbox.add_child(title)
	vbox.add_child(msg)
	vbox.add_child(hbox)
	
	confirm_panel.add_child(vbox)
	
	if main_card:
		main_card.add_child(confirm_panel)
	else:
		add_child(confirm_panel)

func _db_to_pct(val: float, min_db: float, max_db: float) -> int:
	if val <= min_db:
		return 0
	if val >= max_db:
		return 100
	var pct = (val - min_db) / (max_db - min_db) * 100.0
	return int(round(pct))

func _update_settings_values() -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr:
		if bgm_slider:
			bgm_slider.value = sound_mgr.music_volume_db
		if sfx_slider:
			sfx_slider.value = sound_mgr.sfx_volume_db

	if bgm_slider and bgm_label:
		var pct = _db_to_pct(bgm_slider.value, bgm_slider.min_value, bgm_slider.max_value)
		bgm_label.text = "🎶 Nhạc nền (BGM): " + (str(pct) + "%" if pct > 0 else "TẮT")

	if sfx_slider and sfx_label:
		var pct = _db_to_pct(sfx_slider.value, sfx_slider.min_value, sfx_slider.max_value)
		sfx_label.text = "🔔 Hiệu ứng âm thanh (SFX): " + (str(pct) + "%" if pct > 0 else "TẮT")

	var tree = get_tree()
	var mobile_controls = tree.get_first_node_in_group("mobile_controls") if tree else null
	if mobile_controls and touch_ui_button:
		touch_ui_button.text = "📱 Touch UI: " + ("BẬT" if mobile_controls.visible else "TẮT")

	var game_mgr = get_node_or_null("/root/GameManager")
	if fps_button:
		var enabled = bool(game_mgr.get("show_fps")) if game_mgr else false
		fps_button.text = "📊 Hiển thị FPS: " + ("BẬT" if enabled else "TẮT")

func _on_fps_toggled() -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("toggle_fps"):
		game_mgr.toggle_fps()
	_update_settings_values()

func _on_resume_pressed() -> void:
	set_paused(false)

func _on_settings_pressed() -> void:
	_show_settings_view()

func _on_restart_pressed() -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.get("is_level_active") and game_mgr.is_level_active:
		_show_confirmation_dialog(
			"⚠️ XÁC NHẬN CHƠI LẠI",
			"Chơi lại giữa màn sẽ hủy bỏ tiến trình màn chơi dở dang này.\nBạn có chắc chắn muốn chơi lại?",
			_do_restart
		)
	else:
		_do_restart()

func _do_restart() -> void:
	set_paused(false)
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_method("get_current_level_data"):
		var cur_data = game_mgr.get_current_level_data()
		if cur_data and "level_id" in cur_data:
			game_mgr.start_level(cur_data["level_id"])

func _on_main_menu_pressed() -> void:
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.get("is_level_active") and game_mgr.is_level_active:
		_show_confirmation_dialog(
			"⚠️ XÁC NHẬN THOÁT",
			"Thoát ra Màn Hình Chính sẽ hủy bỏ tiến trình màn chơi dở dang này.\nBạn có chắc chắn muốn thoát?",
			_do_main_menu
		)
	else:
		_do_main_menu()

func _do_main_menu() -> void:
	set_paused(false)
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr:
		game_mgr.is_level_active = false
	get_tree().change_scene_to_file("res://Scene/main_menu.tscn")

func _on_back_pressed() -> void:
	_show_main_view()

func _on_touch_ui_toggled() -> void:
	var tree = get_tree()
	var mobile_controls = tree.get_first_node_in_group("mobile_controls") if tree else null
	if mobile_controls:
		mobile_controls.visible = not mobile_controls.visible
		_update_settings_values()

func _on_bgm_volume_changed(val: float) -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr:
		sound_mgr.set_music_volume(val)
	if bgm_slider and bgm_label:
		var pct = _db_to_pct(val, bgm_slider.min_value, bgm_slider.max_value)
		bgm_label.text = "🎶 Nhạc nền (BGM): " + (str(pct) + "%" if pct > 0 else "TẮT")

func _on_sfx_volume_changed(val: float) -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr:
		sound_mgr.set_sfx_volume(val)
	if sfx_slider and sfx_label:
		var pct = _db_to_pct(val, sfx_slider.min_value, sfx_slider.max_value)
		sfx_label.text = "🔔 Hiệu ứng âm thanh (SFX): " + (str(pct) + "%" if pct > 0 else "TẮT")

func _on_bgm_minus_pressed() -> void:
	if bgm_slider:
		bgm_slider.value = max(bgm_slider.min_value, bgm_slider.value - 3.0)

func _on_bgm_plus_pressed() -> void:
	if bgm_slider:
		bgm_slider.value = min(bgm_slider.max_value, bgm_slider.value + 3.0)

func _on_sfx_minus_pressed() -> void:
	if sfx_slider:
		sfx_slider.value = max(sfx_slider.min_value, sfx_slider.value - 3.0)
		_play_test_sfx()

func _on_sfx_plus_pressed() -> void:
	if sfx_slider:
		sfx_slider.value = min(sfx_slider.max_value, sfx_slider.value + 3.0)
		_play_test_sfx()

func _on_test_sfx_pressed() -> void:
	_play_test_sfx()

func _play_test_sfx() -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_food_pickup_sfx"):
		sound_mgr.play_food_pickup_sfx()
