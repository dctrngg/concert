extends Control
class_name LevelSelectMenu

@onready var grid_container: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var back_button: Button = $MarginContainer/VBoxContainer/Header/BackButton

var tex_frame_unlocked: Texture2D = preload("res://Spritesheets/DEMO_Cozy_UI_Pack_doboui/Cards/CardRegular/CardRegular1_wood.png")
var tex_frame_locked: Texture2D = preload("res://Spritesheets/DEMO_Cozy_UI_Pack_doboui/Cards/CardRegular/CardRegular1_red.png")
var tex_btn_normal: Texture2D = preload("res://Spritesheets/DEMO_Cozy_UI_Pack_doboui/Buttons/Square/SquareButton1_wood.png")
var tex_btn_hover: Texture2D = preload("res://Spritesheets/DEMO_Cozy_UI_Pack_doboui/Buttons/Square/SquareButton2_wood.png")
var tex_btn_pressed: Texture2D = preload("res://Spritesheets/DEMO_Cozy_UI_Pack_doboui/Buttons/Square/SquareButton2_wood.png")

func _ready() -> void:
	if back_button:
		_apply_pixel_button_styles(back_button)
		back_button.pressed.connect(_on_back_pressed)
	_build_level_buttons()

func _apply_pixel_button_styles(btn: Button) -> void:
	var style_n = StyleBoxTexture.new()
	style_n.texture = tex_btn_normal
	style_n.texture_margin_left = 12
	style_n.texture_margin_top = 10
	style_n.texture_margin_right = 12
	style_n.texture_margin_bottom = 10

	var style_h = StyleBoxTexture.new()
	style_h.texture = tex_btn_hover
	style_h.texture_margin_left = 12
	style_h.texture_margin_top = 10
	style_h.texture_margin_right = 12
	style_h.texture_margin_bottom = 10

	var style_p = StyleBoxTexture.new()
	style_p.texture = tex_btn_pressed
	style_p.texture_margin_left = 12
	style_p.texture_margin_top = 10
	style_p.texture_margin_right = 12
	style_p.texture_margin_bottom = 10

	btn.add_theme_stylebox_override("normal", style_n)
	btn.add_theme_stylebox_override("hover", style_h)
	btn.add_theme_stylebox_override("pressed", style_p)

func _build_level_buttons() -> void:
	for child in grid_container.get_children():
		child.queue_free()
		
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		return
		
	var configs = gm.LEVEL_CONFIGS
	var unlocked = gm.unlocked_levels
	var stars_map = gm.level_stars
	var scores_map = gm.level_high_scores
	
	for lvl in configs:
		var lvl_id: int = lvl["level_id"]
		var title: String = lvl["title"]
		var is_unlocked: bool = lvl_id in unlocked
		var stars: int = stars_map.get(lvl_id, 0)
		var high_score: int = scores_map.get(lvl_id, 0)
		
		var card = PanelContainer.new()
		card.custom_minimum_size = Vector2(270, 220)
		
		var style = StyleBoxTexture.new()
		style.texture = tex_frame_unlocked if is_unlocked else tex_frame_locked
		style.texture_margin_left = 32
		style.texture_margin_top = 35
		style.texture_margin_right = 32
		style.texture_margin_bottom = 35
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		card.add_theme_stylebox_override("panel", style)
		
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_bottom", 10)
		card.add_child(margin)

		var vbox = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 8)
		margin.add_child(vbox)

		var title_lbl = Label.new()
		title_lbl.text = title
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title_lbl.add_theme_font_size_override("font_size", 18)
		if is_unlocked:
			title_lbl.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
		else:
			title_lbl.add_theme_color_override("font_color", Color(0.98, 0.95, 0.9))
			title_lbl.add_theme_outline_size_override("outline_size", 2)
			title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		vbox.add_child(title_lbl)
		
		if is_unlocked:
			var stars_lbl = Label.new()
			var stars_str = ""
			match stars:
				0: stars_str = "☆☆☆"
				1: stars_str = "★☆☆"
				2: stars_str = "★★☆"
				3: stars_str = "★★★"
			stars_lbl.text = stars_str
			stars_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			stars_lbl.add_theme_color_override("font_color", Color(0.85, 0.45, 0.05))
			stars_lbl.add_theme_font_size_override("font_size", 26)
			vbox.add_child(stars_lbl)
			
			var score_lbl = Label.new()
			score_lbl.text = "Điểm cao: %d" % high_score
			score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			score_lbl.add_theme_font_size_override("font_size", 16)
			score_lbl.add_theme_color_override("font_color", Color(0.4, 0.25, 0.1))
			vbox.add_child(score_lbl)
			
			var play_btn = Button.new()
			play_btn.text = "▶ CHƠI NGAY"
			play_btn.custom_minimum_size = Vector2(0, 42)
			play_btn.add_theme_font_size_override("font_size", 16)
			play_btn.add_theme_color_override("font_color", Color(0.28, 0.16, 0.08))
			play_btn.add_theme_color_override("font_hover_color", Color(0.48, 0.28, 0.1))
			_apply_pixel_button_styles(play_btn)
			play_btn.pressed.connect(func(): gm.start_level(lvl_id))
			vbox.add_child(play_btn)
		else:
			var lock_lbl = Label.new()
			lock_lbl.text = "🔒 ĐÃ KHÓA\n(Cần 1★ cấp trước)"
			lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.85))
			lock_lbl.add_theme_font_size_override("font_size", 16)
			lock_lbl.add_theme_outline_size_override("outline_size", 2)
			lock_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			vbox.add_child(lock_lbl)
			
		grid_container.add_child(card)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://Scene/main_menu.tscn")
