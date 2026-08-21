extends Control

@export var radar_radius: float = 800.0 # Bán kính thế giới được quét quanh Player (pixels)

@onready var canvas: Control = find_child("MinimapCanvas", true, false) as Control
@onready var time_label: Label = find_child("TimeLabel", true, false) as Label

var food_icon_tex: Texture2D = preload("res://Sprites/Pixel_Mart/snack1.png")
var merch_icon_tex: Texture2D = preload("res://Sprites/Pixel_Mart/potatochip_blue.png")
const DEFAULT_FONT: Font = preload("res://0307-LNTH-TwistyPixel.ttf")

var _player: Node2D = null
var _pulse_time: float = 0.0
var _redraw_timer: float = 0.0

func _ready() -> void:
	add_to_group("minimap")
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	if canvas:
		canvas.draw.connect(_on_canvas_draw)

	call_deferred("_check_mobile_hide")

func _check_mobile_hide() -> void:
	var tree = get_tree()
	if not tree:
		return
	var mobile_ctrl = tree.get_first_node_in_group("mobile_controls")
	if mobile_ctrl and mobile_ctrl.visible:
		visible = false

func _process(delta: float) -> void:
	_pulse_time += delta * 5.0
	_redraw_timer += delta
	
	if not _player:
		var tree = get_tree()
		if tree:
			_player = tree.get_first_node_in_group("player") as Node2D
			
	# Cập nhật đồng hồ smartphone theo GameManager.time_remaining
	if time_label:
		if GameManager and GameManager.get("time_remaining") != null:
			var t_rem = float(GameManager.time_remaining)
			var mins = int(t_rem) / 60
			var secs = int(t_rem) % 60
			time_label.text = "%02d:%02d" % [mins, secs]
		else:
			time_label.text = "20:00"

	# Throttling Minimap redraw rate (~20 FPS) giảm áp lực CanvasItem draw trên Web
	if _redraw_timer >= 0.05:
		_redraw_timer = 0.0
		if canvas and visible:
			canvas.queue_redraw()

func _on_canvas_draw() -> void:
	if not canvas or not _player or not is_instance_valid(_player):
		return

	var rect_size = canvas.get_rect().size
	var center = rect_size / 2.0
	var map_radius = min(rect_size.x, rect_size.y) / 2.0 - 4.0

	# 1. Màn hình Google Maps / Event App nền tối hiện đại
	canvas.draw_rect(Rect2(Vector2.ZERO, rect_size), Color(0.1, 0.12, 0.18, 1.0))

	# Các đường sơ đồ ô lưới giao thông / tuyến đường sự kiện
	var road_color = Color(0.18, 0.23, 0.32, 0.45)
	canvas.draw_line(Vector2(center.x, 0), Vector2(center.x, rect_size.y), road_color, 2.0)
	canvas.draw_line(Vector2(0, center.y), Vector2(rect_size.x, center.y), road_color, 2.0)
	canvas.draw_arc(center, map_radius * 0.45, 0.0, TAU, 32, road_color, 1.5)
	canvas.draw_arc(center, map_radius * 0.9, 0.0, TAU, 32, Color(0.25, 0.65, 1.0, 0.3), 1.5)

	var player_pos = _player.global_position
	var scale_factor = map_radius / radar_radius

	var tree = get_tree()
	if not tree:
		return

	# 2. Vẽ Sân Khấu (Concert Stage - Pure Icon 🎤)
	var stage = tree.get_first_node_in_group("concert_stage") as Node2D
	if stage and is_instance_valid(stage):
		_draw_entity_icon(canvas, center, map_radius, player_pos, stage.global_position, scale_factor, Color(0.9, 0.4, 1.0), "🎤", null, 34.0)

	# 3. Vẽ Quầy Đồ Ăn (Food Stalls - Pure Food Texture Icon)
	for food in tree.get_nodes_in_group("food_source"):
		if food is Node2D and is_instance_valid(food):
			_draw_entity_icon(canvas, center, map_radius, player_pos, food.global_position, scale_factor, Color(1.0, 0.65, 0.2), "", food_icon_tex, 30.0)

	# 4. Vẽ Kho Ghế (Chair Sources - Pure Icon 🪑)
	for chair in tree.get_nodes_in_group("chair_source"):
		if chair is Node2D and is_instance_valid(chair):
			_draw_entity_icon(canvas, center, map_radius, player_pos, chair.global_position, scale_factor, Color(0.3, 0.8, 1.0), "🪑", null, 30.0)

	# 5. Vẽ Quầy Merch (Merch Stalls - Pure Merch Texture Icon)
	for merch in tree.get_nodes_in_group("merch_stall"):
		if merch is Node2D and is_instance_valid(merch):
			_draw_entity_icon(canvas, center, map_radius, player_pos, merch.global_position, scale_factor, Color(0.95, 0.45, 0.65), "", merch_icon_tex, 30.0)

	# 6. Vẽ Khán Giả Giao Nhiệm Vụ (NPC Quest - Pure !, ?, 📦 symbols)
	for npc in tree.get_nodes_in_group("npc_interactive"):
		if npc is Node2D and is_instance_valid(npc):
			var has_q = npc.get("has_quest") == true
			var q_data = npc.get("quest_data")
			if has_q and q_data != null:
				var is_offered = (q_data.state == NPCQuestData.QuestState.OFFERED)
				var is_active = (q_data.state == NPCQuestData.QuestState.ACTIVE)

				if is_offered:
					var pulse = 0.85 + sin(_pulse_time) * 0.15
					_draw_entity_icon(canvas, center, map_radius, player_pos, npc.global_position, scale_factor, Color(1.0, 0.9, 0.1, pulse), "!", null, 36.0)
				elif is_active:
					if q_data.is_item_picked_up:
						_draw_entity_icon(canvas, center, map_radius, player_pos, npc.global_position, scale_factor, Color(0.3, 1.0, 0.4), "?", null, 32.0)
					else:
						_draw_entity_icon(canvas, center, map_radius, player_pos, npc.global_position, scale_factor, Color(0.4, 0.7, 1.0), "📦", null, 28.0)

	# 7. Định Vị GPS Người Chơi (Player GPS Blue Dot & Location Beam)
	var gps_pulse = 8.0 + sin(_pulse_time * 1.5) * 2.5
	canvas.draw_circle(center, gps_pulse + 5.0, Color(0.1, 0.65, 1.0, 0.25))
	canvas.draw_circle(center, 8.0, Color(0.15, 0.75, 1.0, 1.0))
	canvas.draw_circle(center, 3.5, Color(1.0, 1.0, 1.0, 1.0))

	# Hướng nhìn di chuyển GPS
	var vel = _player.get("velocity")
	if vel is Vector2 and vel.length_squared() > 1.0:
		var dir = vel.normalized()
		# Vẽ hình chóp chùm sáng GPS chỉ hướng
		var p1 = center + dir * 22.0
		var p2 = center + dir.rotated(0.35) * 11.0
		var p3 = center + dir.rotated(-0.35) * 11.0
		var points = PackedVector2Array([center, p2, p1, p3])
		canvas.draw_colored_polygon(points, Color(0.2, 0.8, 1.0, 0.4))
		canvas.draw_line(center, p1, Color(0.2, 0.9, 1.0, 0.95), 3.0)

func _draw_entity_icon(canvas_node: Control, center: Vector2, max_radius: float, player_pos: Vector2, entity_pos: Vector2, scale_factor: float, color: Color, symbol: String, icon_tex: Texture2D = null, icon_size: float = 22.0) -> void:
	var diff = entity_pos - player_pos
	var map_offset = diff * scale_factor
	var dist = map_offset.length()

	var final_pos: Vector2
	var is_clamped = false

	if dist <= max_radius:
		final_pos = center + map_offset
	else:
		final_pos = center + map_offset.normalized() * max_radius
		is_clamped = true

	if is_clamped:
		# Ra ngoài bán kính: chấm nhỏ định hướng gọn gàng
		canvas_node.draw_circle(final_pos, 4.0, Color(color.r, color.g, color.b, 0.8))
	else:
		# KHÔNG CÓ Ô TRÒN NỀN - Vẽ trực tiếp Icon hoặc Ký tự ký hiệu
		if icon_tex:
			# Bóng mờ tương phản
			var shadow_rect = Rect2(final_pos - Vector2(icon_size / 2.0 - 1.0, icon_size / 2.0 - 1.0), Vector2(icon_size, icon_size))
			canvas_node.draw_texture_rect(icon_tex, shadow_rect, false, Color(0, 0, 0, 0.5))
			
			var rect = Rect2(final_pos - Vector2(icon_size / 2.0, icon_size / 2.0), Vector2(icon_size, icon_size))
			canvas_node.draw_texture_rect(icon_tex, rect, false)
		elif symbol != "":
			var font = DEFAULT_FONT if DEFAULT_FONT else ThemeDB.fallback_font
			var font_size = int(icon_size * 0.9)
			var text_offset = Vector2(-font_size * 0.3, font_size * 0.35)
			
			# Bóng mờ chữ tương phản
			canvas_node.draw_string(font, final_pos + text_offset + Vector2(1, 1), symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(0, 0, 0, 0.85))
			canvas_node.draw_string(font, final_pos + text_offset, symbol, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
