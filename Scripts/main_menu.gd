extends Control
class_name MainMenu

@onready var title_label: Label = find_child("TitleLabel", true, false) as Label
@onready var start_button: Button = find_child("StartButton", true, false) as Button
@onready var level_select_button: Button = find_child("LevelSelectButton", true, false) as Button
@onready var settings_button: Button = find_child("SettingsButton", true, false) as Button
@onready var quit_button: Button = find_child("QuitButton", true, false) as Button

@onready var settings_modal: Control = find_child("SettingsModal", true, false) as Control
@onready var bgm_label: Label = find_child("BGMLabel", true, false) as Label
@onready var bgm_slider: HSlider = find_child("BGMSlider", true, false) as HSlider
@onready var bgm_minus_btn: Button = find_child("BGMMinusBtn", true, false) as Button
@onready var bgm_plus_btn: Button = find_child("BGMPlusBtn", true, false) as Button

@onready var sfx_label: Label = find_child("SFXLabel", true, false) as Label
@onready var sfx_slider: HSlider = find_child("SFXSlider", true, false) as HSlider
@onready var sfx_minus_btn: Button = find_child("SFXMinusBtn", true, false) as Button
@onready var sfx_plus_btn: Button = find_child("SFXPlusBtn", true, false) as Button

@onready var close_settings_btn: Button = find_child("CloseSettingsBtn", true, false) as Button
@onready var test_sfx_btn: Button = find_child("TestSFXBtn", true, false) as Button

var _anim_time: float = 0.0

func _ready() -> void:
	# Khởi tạo âm thanh nhạc nền menu
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("resume_music"):
		sound_mgr.resume_music()

	# Ẩn các phần tử HUD gameplay trong màn hình concert nền nếu có
	var bg_world = get_node_or_null("WorldBackground")
	if bg_world:
		var hud = bg_world.get_node_or_null("HUD")
		if hud:
			var ctrl = hud.get_node_or_null("Control")
			if ctrl: ctrl.visible = false
			var start_dialog = hud.get_node_or_null("LevelStartDialog")
			if start_dialog: start_dialog.visible = false
			var mob_ctrl = hud.get_node_or_null("MobileControls")
			if mob_ctrl: mob_ctrl.visible = false

	# Cấu hình âm thanh & tín hiệu nút bấm
	if start_button: start_button.pressed.connect(_on_start_pressed)
	if level_select_button: level_select_button.pressed.connect(_on_level_select_pressed)
	if settings_button: settings_button.pressed.connect(_on_settings_pressed)
	if quit_button: quit_button.pressed.connect(_on_quit_pressed)
	if close_settings_btn: close_settings_btn.pressed.connect(_on_close_settings_pressed)
	if test_sfx_btn: test_sfx_btn.pressed.connect(_on_test_sfx_pressed)

	if bgm_minus_btn: bgm_minus_btn.pressed.connect(_on_bgm_minus_pressed)
	if bgm_plus_btn: bgm_plus_btn.pressed.connect(_on_bgm_plus_pressed)
	if sfx_minus_btn: sfx_minus_btn.pressed.connect(_on_sfx_minus_pressed)
	if sfx_plus_btn: sfx_plus_btn.pressed.connect(_on_sfx_plus_pressed)

	# Lắng nghe sự kiện hover nút để phát SFX
	var all_btns = [start_button, level_select_button, settings_button, quit_button, close_settings_btn, test_sfx_btn]
	if bgm_minus_btn: all_btns.append(bgm_minus_btn)
	if bgm_plus_btn: all_btns.append(bgm_plus_btn)
	if sfx_minus_btn: all_btns.append(sfx_minus_btn)
	if sfx_plus_btn: all_btns.append(sfx_plus_btn)
	
	for btn in all_btns:
		if btn and not btn.mouse_entered.is_connected(_on_button_hovered):
			btn.mouse_entered.connect(_on_button_hovered)

	# Cấu hình modal cài đặt
	if settings_modal:
		settings_modal.visible = false

	_init_sliders()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if settings_modal and settings_modal.visible:
			_on_close_settings_pressed()
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_anim_time += delta
	if title_label:
		var scale_factor = 1.0 + sin(_anim_time * 3.0) * 0.02
		title_label.scale = Vector2(scale_factor, scale_factor)
		title_label.pivot_offset = title_label.size / 2.0

func _on_button_hovered() -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_food_pickup_sfx"):
		sound_mgr.play_food_pickup_sfx(-6.0)

func _play_click_sfx() -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_quest_accept_sfx"):
		sound_mgr.play_quest_accept_sfx()

func _on_start_pressed() -> void:
	_play_click_sfx()
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.start_level(1)
	else:
		get_tree().change_scene_to_file("res://Scene/world.tscn")

func _on_level_select_pressed() -> void:
	_play_click_sfx()
	get_tree().change_scene_to_file("res://Scene/level_select.tscn")

func _on_settings_pressed() -> void:
	_play_click_sfx()
	if settings_modal:
		settings_modal.visible = true
		_init_sliders()

func _on_close_settings_pressed() -> void:
	_play_click_sfx()
	if settings_modal:
		settings_modal.visible = false

func _on_quit_pressed() -> void:
	_play_click_sfx()
	get_tree().quit()

func _db_to_pct(val: float, min_db: float, max_db: float) -> int:
	if val <= min_db:
		return 0
	if val >= max_db:
		return 100
	var pct = (val - min_db) / (max_db - min_db) * 100.0
	return int(round(pct))

func _init_sliders() -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if not sound_mgr:
		return
		
	if bgm_slider:
		bgm_slider.min_value = -30.0
		bgm_slider.max_value = 6.0
		bgm_slider.value = sound_mgr.music_volume_db
		if not bgm_slider.value_changed.is_connected(_on_bgm_volume_changed):
			bgm_slider.value_changed.connect(_on_bgm_volume_changed)

	if sfx_slider:
		sfx_slider.min_value = -30.0
		sfx_slider.max_value = 12.0
		sfx_slider.value = sound_mgr.sfx_volume_db
		if not sfx_slider.value_changed.is_connected(_on_sfx_volume_changed):
			sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	_update_labels()

func _update_labels() -> void:
	if bgm_slider and bgm_label:
		var pct = _db_to_pct(bgm_slider.value, bgm_slider.min_value, bgm_slider.max_value)
		bgm_label.text = "🎶 Nhạc Nền: " + (str(pct) + "%" if pct > 0 else "TẮT")

	if sfx_slider and sfx_label:
		var pct = _db_to_pct(sfx_slider.value, sfx_slider.min_value, sfx_slider.max_value)
		sfx_label.text = "🔔 Hiệu Ứng: " + (str(pct) + "%" if pct > 0 else "TẮT")

func _on_bgm_volume_changed(val: float) -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr:
		sound_mgr.set_music_volume(val)
	_update_labels()

func _on_sfx_volume_changed(val: float) -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr:
		sound_mgr.set_sfx_volume(val)
	_update_labels()

func _on_bgm_minus_pressed() -> void:
	if bgm_slider:
		bgm_slider.value = max(bgm_slider.min_value, bgm_slider.value - 3.0)

func _on_bgm_plus_pressed() -> void:
	if bgm_slider:
		bgm_slider.value = min(bgm_slider.max_value, bgm_slider.value + 3.0)

func _on_sfx_minus_pressed() -> void:
	if sfx_slider:
		sfx_slider.value = max(sfx_slider.min_value, sfx_slider.value - 3.0)
		_on_test_sfx_pressed()

func _on_sfx_plus_pressed() -> void:
	if sfx_slider:
		sfx_slider.value = min(sfx_slider.max_value, sfx_slider.value + 3.0)
		_on_test_sfx_pressed()

func _on_test_sfx_pressed() -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_food_pickup_sfx"):
		sound_mgr.play_food_pickup_sfx()
