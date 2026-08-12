extends Control
class_name MainMenu

@onready var title_label: Label = $MarginContainer/VBox/TitleBanner/TitleLabel
@onready var start_button: Button = $MarginContainer/VBox/MenuButtons/StartButton
@onready var level_select_button: Button = $MarginContainer/VBox/MenuButtons/LevelSelectButton
@onready var settings_button: Button = $MarginContainer/VBox/MenuButtons/SettingsButton
@onready var quit_button: Button = $MarginContainer/VBox/MenuButtons/QuitButton

@onready var settings_modal: Control = $SettingsModal
@onready var bgm_slider: HSlider = $SettingsModal/Panel/VBox/BGMRow/BGMSlider
@onready var sfx_slider: HSlider = $SettingsModal/Panel/VBox/SFXRow/SFXSlider
@onready var close_settings_btn: Button = $SettingsModal/Panel/VBox/CloseSettingsBtn
@onready var test_sfx_btn: Button = $SettingsModal/Panel/VBox/TestSFXBtn

var tex_btn_normal: Texture2D = preload("res://Sprites/UI_Flat_Button01a_1.png")
var tex_btn_hover: Texture2D = preload("res://Sprites/UI_Flat_Button01a_2.png")
var tex_btn_pressed: Texture2D = preload("res://Sprites/UI_Flat_Button01a_3.png")

var _anim_time: float = 0.0

func _ready() -> void:
	# Khởi tạo âm thanh nhạc nền menu
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("resume_music"):
		sound_mgr.resume_music()

	# Cấu hình Stylebox Pixel cho các nút bấm
	_apply_pixel_button_styles(start_button)
	_apply_pixel_button_styles(level_select_button)
	_apply_pixel_button_styles(settings_button)
	_apply_pixel_button_styles(quit_button)
	_apply_pixel_button_styles(close_settings_btn)
	_apply_pixel_button_styles(test_sfx_btn)

	# Kết nối tín hiệu nút bấm
	start_button.pressed.connect(_on_start_pressed)
	level_select_button.pressed.connect(_on_level_select_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	close_settings_btn.pressed.connect(_on_close_settings_pressed)
	test_sfx_btn.pressed.connect(_on_test_sfx_pressed)

	# Lắng nghe sự kiện hover nút để phát SFX
	for btn in [start_button, level_select_button, settings_button, quit_button, close_settings_btn, test_sfx_btn]:
		btn.mouse_entered.connect(_on_button_hovered)

	# Cấu hình modal cài đặt
	if settings_modal:
		settings_modal.visible = false

	_init_sliders()

func _process(delta: float) -> void:
	_anim_time += delta
	if title_label:
		# Hiệu ứng nhịp đập nhẹ nhấp nháy chữ Title
		var scale_factor = 1.0 + sin(_anim_time * 3.0) * 0.03
		title_label.scale = Vector2(scale_factor, scale_factor)
		title_label.pivot_offset = title_label.size / 2.0

func _apply_pixel_button_styles(btn: Button) -> void:
	if not btn:
		return
	var style_n = StyleBoxTexture.new()
	style_n.texture = tex_btn_normal
	style_n.texture_margin_left = 8
	style_n.texture_margin_top = 8
	style_n.texture_margin_right = 8
	style_n.texture_margin_bottom = 8

	var style_h = StyleBoxTexture.new()
	style_h.texture = tex_btn_hover
	style_h.texture_margin_left = 8
	style_h.texture_margin_top = 8
	style_h.texture_margin_right = 8
	style_h.texture_margin_bottom = 8

	var style_p = StyleBoxTexture.new()
	style_p.texture = tex_btn_pressed
	style_p.texture_margin_left = 8
	style_p.texture_margin_top = 8
	style_p.texture_margin_right = 8
	style_p.texture_margin_bottom = 8

	btn.add_theme_stylebox_override("normal", style_n)
	btn.add_theme_stylebox_override("hover", style_h)
	btn.add_theme_stylebox_override("pressed", style_p)

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

func _on_bgm_volume_changed(val: float) -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr:
		sound_mgr.set_music_volume(val)

func _on_sfx_volume_changed(val: float) -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr:
		sound_mgr.sfx_volume_db = val

func _on_test_sfx_pressed() -> void:
	var sound_mgr = get_node_or_null("/root/SoundManager")
	if sound_mgr and sound_mgr.has_method("play_food_pickup_sfx"):
		sound_mgr.play_food_pickup_sfx()
