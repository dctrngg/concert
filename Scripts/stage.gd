class_name ConcertStage
extends StaticBody2D

## Signal khi concert bắt đầu hoặc kết thúc
signal concert_started
signal concert_ended
signal player_entered_stage_zone
signal player_exited_stage_zone
signal climax_started
signal climax_ended

@export var is_concert_active: bool = true
@export var hype_multiplier: float = 1.5
@export var light_pulse_speed: float = 1.2
@export var is_climax_active: bool = false
@export var climax_duration: float = 12.0
@export var climax_interval: float = 35.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var audience_area: Area2D = $AudienceArea
@onready var stage_lights: Node2D = $StageLights

var _time_passed: float = 0.0
var _is_player_in_zone: bool = false
var _strobe_intensity: float = 0.0
var _climax_timer: float = 0.0
var _climax_interval_timer: float = 0.0

# Node vẽ hiệu ứng LED và Laser
var _led_display: Node2D = null
var _laser_beams: Node2D = null

# Palette màu LED concert rực rỡ & hài hòa
var _neon_colors: Array[Color] = [
	Color(1.0, 0.05, 0.55, 0.9),  # Deep Magenta
	Color(0.0, 0.85, 1.0, 0.9),   # Electric Cyan
	Color(0.95, 0.75, 0.0, 0.9),  # Warm Gold
	Color(0.55, 0.15, 1.0, 0.9),  # Purple Glow
	Color(0.0, 0.95, 0.45, 0.9),  # Emerald Mint
	Color(1.0, 0.25, 0.15, 0.9)   # Coral Flame
]

var _artists_container: Node2D = null
var _stage_artist_sprites: Array[AnimatedSprite2D] = []
var _artist_base_positions: Array[Vector2] = []
var _artist_current_x: Array[float] = []
var _artist_target_x: Array[float] = []
var _artist_state_timer: Array[float] = []
var _artist_action_state: Array[int] = []

var _confetti_left: CPUParticles2D = null
var _confetti_right: CPUParticles2D = null
var _dust_motes: CPUParticles2D = null
var _stage_fog: Node2D = null

func _ready() -> void:
	add_to_group("concert_stage")
	if audience_area:
		audience_area.body_entered.connect(_on_audience_area_body_entered)
		audience_area.body_exited.connect(_on_audience_area_body_exited)
		
	_setup_led_and_laser_effects()
	_setup_stage_artists()
	_setup_confetti_and_atmosphere()

func _setup_led_and_laser_effects() -> void:
	_led_display = Node2D.new()
	_led_display.name = "LEDDisplay"
	_led_display.z_index = 1
	add_child(_led_display)
	_led_display.draw.connect(_on_draw_led_display)
	
	_laser_beams = Node2D.new()
	_laser_beams.name = "LaserBeams"
	_laser_beams.z_index = 2
	add_child(_laser_beams)
	_laser_beams.draw.connect(_on_draw_laser_beams)

@export var artist_scale: Vector2 = Vector2(6.0, 6.0)
@export var artist_offsets: Array[Vector2] = [
	Vector2(0, -420),     # Ca sĩ chính (Giữa sân khấu)
	Vector2(-240, -460),  # Nhạc công Trái (Cánh trái)
	Vector2(240, -460)    # Nhạc công Phải (Cánh phải)
]

func _setup_stage_artists() -> void:
	_artists_container = Node2D.new()
	_artists_container.name = "ArtistsContainer"
	_artists_container.z_index = 3
	add_child(_artists_container)
	
	await get_tree().process_frame
	
	var cm = get_tree().get_first_node_in_group("crowd_manager")
	
	for i in range(artist_offsets.size()):
		var base_pos = artist_offsets[i]
		_artist_base_positions.append(base_pos)
		_artist_current_x.append(base_pos.x)
		_artist_target_x.append(base_pos.x)
		_artist_state_timer.append(randf_range(1.0, 4.0))
		_artist_action_state.append(0)
		
		var artist = AnimatedSprite2D.new()
		artist.name = "StageArtist_%d" % i
		artist.position = base_pos
		artist.scale = artist_scale
		
		var sf: SpriteFrames = null
		if cm and cm.has_method("get_random_outfit_sprite_frames"):
			sf = cm.get_random_outfit_sprite_frames()
			
		if sf == null:
			var player_scene = load("res://Scene/Player.tscn")
			if player_scene:
				var dummy = player_scene.instantiate()
				var p_sprite = dummy.get_node_or_null("AnimatedSprite2D")
				if p_sprite and p_sprite.sprite_frames:
					sf = p_sprite.sprite_frames
				dummy.queue_free()
				
		if sf != null:
			artist.sprite_frames = sf
			if sf.has_animation("idle_down"):
				artist.play("idle_down")
			elif sf.has_animation("walk_down"):
				artist.play("walk_down")
				
		_artists_container.add_child(artist)
		_stage_artist_sprites.append(artist)

func _setup_confetti_and_atmosphere() -> void:
	# 1. Hạt Bụi Đèn Spotlight Lơ Lửng Rực Rỡ (Ambient Dust Motes)
	_dust_motes = CPUParticles2D.new()
	_dust_motes.name = "DustMotes"
	_dust_motes.z_index = 4
	_dust_motes.amount = 80
	_dust_motes.lifetime = 5.0
	_dust_motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_dust_motes.emission_rect_extents = Vector2(750, 500)
	_dust_motes.position = Vector2(0, -350)
	_dust_motes.gravity = Vector2(0, -10.0)
	_dust_motes.initial_velocity_min = 8.0
	_dust_motes.initial_velocity_max = 24.0
	_dust_motes.scale_amount_min = 4.0
	_dust_motes.scale_amount_max = 8.0
	_dust_motes.color = Color(1.0, 0.98, 0.75, 0.65)
	add_child(_dust_motes)

	# 2. Pháo Hoa Giấy Kim Tuyến Sân Khấu (Stage Confetti Celebration)
	_confetti_left = _create_confetti_cannon(Vector2(-360, -520), Vector2(0.4, -1.0))
	_confetti_right = _create_confetti_cannon(Vector2(360, -520), Vector2(-0.4, -1.0))

	# 3. Lớp Khói Sân Khấu Trôi Nhè Nhẹ (Stage Fog)
	_stage_fog = Node2D.new()
	_stage_fog.name = "StageFog"
	_stage_fog.z_index = 2
	add_child(_stage_fog)
	_stage_fog.draw.connect(_on_draw_stage_fog)

	# Tự động nổ pháo hoa Confetti chào mừng sau 1 giây khi vừa vào Đêm Nhạc!
	get_tree().create_timer(1.0).timeout.connect(burst_confetti)

func _create_confetti_cannon(pos: Vector2, dir: Vector2) -> CPUParticles2D:
	var cannon = CPUParticles2D.new()
	cannon.position = pos
	cannon.z_index = 6
	cannon.amount = 100
	cannon.lifetime = 3.2
	cannon.one_shot = true
	cannon.explosiveness = 0.92
	cannon.direction = dir
	cannon.spread = 40.0
	cannon.gravity = Vector2(0, 360.0)
	cannon.initial_velocity_min = 320.0
	cannon.initial_velocity_max = 520.0
	cannon.scale_amount_min = 4.0
	cannon.scale_amount_max = 8.5
	cannon.color = Color(1.0, 0.2, 0.6, 1.0)
	add_child(cannon)
	return cannon

func burst_confetti() -> void:
	if _confetti_left:
		_confetti_left.color = _neon_colors[randi() % _neon_colors.size()]
		_confetti_left.restart()
	if _confetti_right:
		_confetti_right.color = _neon_colors[randi() % _neon_colors.size()]
		_confetti_right.restart()
	print("[ConcertStage] 🎆 BẮN PHÁO HOA GIẤY KIM TUYẾN SÂN KHẤU BÙNG NỔ!")

func _on_draw_stage_fog() -> void:
	if not is_concert_active:
		return
	var fog_y = -320.0
	var fog_alpha = (sin(_time_passed * 0.8) + 1.0) * 0.04 + 0.05
	var fog_color = Color(0.85, 0.92, 1.0, fog_alpha)
	var fog_offset_x = sin(_time_passed * 0.4) * 40.0
	
	_stage_fog.draw_circle(Vector2(-180 + fog_offset_x, fog_y), 160.0, fog_color)
	_stage_fog.draw_circle(Vector2(180 - fog_offset_x, fog_y), 160.0, fog_color)

func trigger_climax() -> void:
	is_climax_active = true
	_climax_timer = climax_duration
	_climax_interval_timer = 0.0
	climax_started.emit()
	print("[ConcertStage] 🔥 CAO TRÀO SÂN KHẤU BẮT ĐẦU! CA SĨ BÙNG NỔ!")
	
	# Bắn Pháo Hoa Kim Tuyến 2 bên Sân Khấu khi vào Cao Trào!
	burst_confetti()

	# Kích hoạt cú Rung Camera Bùng Nổ sôi động khi Cao Trào bắt đầu
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("apply_camera_shake"):
		player.apply_camera_shake(8.5)

func end_climax() -> void:
	is_climax_active = false
	_climax_timer = 0.0
	_climax_interval_timer = 0.0
	climax_ended.emit()
	print("[ConcertStage] Cao trào kết thúc, trả về nhịp điệu bình thường.")

func _process(delta: float) -> void:
	if is_concert_active:
		# Tự động kích hoạt Cao Trào Đêm Nhạc (Concert Climax) định kỳ
		if not is_climax_active:
			_climax_interval_timer += delta
			if _climax_interval_timer >= climax_interval:
				trigger_climax()
		else:
			_climax_timer -= delta
			if _climax_timer <= 0.0:
				end_climax()

		var speed_mult = 3.2 if is_climax_active else 1.0
		_time_passed += delta * light_pulse_speed * speed_mult
		
		# Animate Stage Performers (Ca sĩ & Nhạc công trình diễn cực sống động trên sân khấu)
		for i in range(_stage_artist_sprites.size()):
			var artist = _stage_artist_sprites[i]
			if not is_instance_valid(artist):
				continue
				
			var base_pos = _artist_base_positions[i]
			
			_artist_state_timer[i] -= delta
			if _artist_state_timer[i] <= 0.0:
				_artist_state_timer[i] = randf_range(2.5, 6.0)
				_artist_action_state[i] = randi() % 4
				if _artist_action_state[i] == 1:
					_artist_target_x[i] = base_pos.x - randf_range(40.0, 110.0)
				elif _artist_action_state[i] == 2:
					_artist_target_x[i] = base_pos.x + randf_range(40.0, 110.0)
				else:
					_artist_target_x[i] = base_pos.x

			var move_speed = 65.0 * (2.2 if is_climax_active else 1.0)
			_artist_current_x[i] = move_toward(_artist_current_x[i], _artist_target_x[i], move_speed * delta)

			var sway_freq = 4.0 if is_climax_active else 2.0
			var sway_amp = 10.0 if is_climax_active else 4.0
			var jump_y = -abs(sin(_time_passed * sway_freq + float(i) * 1.5)) * sway_amp
			
			if _artist_action_state[i] == 3 or is_climax_active:
				jump_y -= abs(sin(_time_passed * 6.0)) * 6.0

			artist.position = Vector2(_artist_current_x[i], base_pos.y + jump_y)

			var sf = artist.sprite_frames
			if sf:
				var is_moving = abs(_artist_current_x[i] - _artist_target_x[i]) > 2.0
				if is_moving:
					var moving_right = (_artist_target_x[i] > _artist_current_x[i])
					var anim = "walk_right" if moving_right else "walk_left"
					if sf.has_animation(anim) and artist.animation != anim:
						artist.play(anim)
				else:
					var anim = "idle_down"
					if sf.has_animation(anim) and artist.animation != anim:
						artist.play(anim)

			var tilt_angle = sin(_time_passed * 3.0 + float(i)) * (0.14 if is_climax_active else 0.06)
			artist.rotation = tilt_angle
		
		if fmod(_time_passed, 6.0) < 0.12 or is_climax_active:
			_strobe_intensity = lerp(_strobe_intensity, 0.95 if is_climax_active else 0.8, delta * 15.0)
		else:
			_strobe_intensity = lerp(_strobe_intensity, 0.0, delta * 6.0)
			
		if _led_display:
			_led_display.queue_redraw()
		if _laser_beams:
			_laser_beams.queue_redraw()
		if _stage_fog:
			_stage_fog.queue_redraw()

## Bật/Tắt chế độ trình diễn Concert
func set_concert_active(active: bool) -> void:
	is_concert_active = active
	if active:
		concert_started.emit()
	else:
		concert_ended.emit()

## Vẽ Hệ thống đèn LED sân khấu & Laser (Đã loại bỏ hoàn toàn các chấm LED trong khu vực chữ nhật)
func _on_draw_led_display() -> void:
	if not is_concert_active:
		return

	# 2. Hàng giàn đèn LED dải trên mái giàn sân khấu (Roof Truss Light Array)
	var roof_y = -710.0
	var roof_count = 50
	var roof_step = 1000.0 / float(roof_count)
	var start_roof_x = -500.0
	
	for i in range(roof_count):
		var rx = start_roof_x + i * roof_step
		var r_phase = _time_passed * 1.5 - float(i) * 0.12
		var r_alpha = (cos(r_phase) + 1.0) * 0.45 + 0.1
		
		var r_col_idx = (int(_time_passed * 0.5) + i) % _neon_colors.size()
		var r_col = _neon_colors[r_col_idx]
		r_col.a = r_alpha
		
		_led_display.draw_circle(Vector2(rx, roof_y), 4.5, r_col)

	# 3. Dải đèn LED viền sân khấu dưới mặt sàn (Stage Edge LED Strip)
	var strip_y = -35.0
	var dot_count = 48
	var dot_spacing = 24.0
	var start_dot_x = - (dot_count * dot_spacing) / 2.0
	
	for i in range(dot_count):
		var dot_x = start_dot_x + i * dot_spacing
		var dot_phase = _time_passed * 2.0 - float(i) * 0.15
		var alpha = (sin(dot_phase) + 1.0) * 0.4 + 0.1
		
		var dot_col_idx = (int(_time_passed * 0.6) + i) % _neon_colors.size()
		var dot_col = _neon_colors[dot_col_idx]
		dot_col.a = alpha
		
		_led_display.draw_circle(Vector2(dot_x, strip_y), 4.5, dot_col)


## Vẽ 10 luồng đèn Laser & Spotlight rực rỡ chiếu cực sáng toàn bộ bản đồ
func _on_draw_laser_beams() -> void:
	if not is_concert_active:
		return
		
	# 10 Vị trí súng phun Laser trên giàn đèn sân khấu
	var emitters: Array[Vector2] = [
		Vector2(-640, -700),
		Vector2(-500, -715),
		Vector2(-360, -730),
		Vector2(-220, -740),
		Vector2(-70, -745),
		Vector2(70, -745),
		Vector2(220, -740),
		Vector2(360, -730),
		Vector2(500, -715),
		Vector2(640, -700)
	]
	
	var num_emitters = emitters.size()
	for e in range(num_emitters):
		var origin = emitters[e]
		var base_angle = (float(e) - (float(num_emitters - 1) / 2.0)) * 0.15
		var sweep = sin(_time_passed * 0.35 + float(e) * 0.8) * 0.65
		var current_angle = base_angle + sweep + PI / 2.0
		
		var beam_len = 2600.0
		var beam_width = 45.0
		
		var dir = Vector2.from_angle(current_angle)
		var perp = Vector2(-dir.y, dir.x) * (beam_width / 2.0)
		
		var p1 = origin - perp
		var p2 = origin + perp
		var p3 = origin + dir * beam_len + perp * 6.5
		var p4 = origin + dir * beam_len - perp * 6.5
		
		var laser_poly = PackedVector2Array([p1, p2, p3, p4])
		
		var col_idx = (int(_time_passed * 0.5) + e) % _neon_colors.size()
		var laser_color = _neon_colors[col_idx]
		
		# Tăng độ sáng bùng nổ (Alpha 0.68 -> 0.88 khi cao trào)
		var base_alpha = 0.88 if is_climax_active else 0.68
		laser_color.a = base_alpha + sin(_time_passed * 2.5 + float(e)) * 0.12
		
		# 1. Lớp viền sáng rộng ngoài cùng (Outer Glow Cone)
		var outer_col = Color(laser_color.r, laser_color.g, laser_color.b, laser_color.a * 0.45)
		_laser_beams.draw_polygon(laser_poly, PackedColorArray([outer_col, outer_col, Color(laser_color.r, laser_color.g, laser_color.b, 0.05), Color(laser_color.r, laser_color.g, laser_color.b, 0.05)]))
		
		# 2. Lớp chùm Laser rực rỡ bên trong (Inner Beam Cone)
		var inner_p1 = origin - perp * 0.5
		var inner_p2 = origin + perp * 0.5
		var inner_p3 = origin + dir * beam_len + perp * 3.2
		var inner_p4 = origin + dir * beam_len - perp * 3.2
		var inner_poly = PackedVector2Array([inner_p1, inner_p2, inner_p3, inner_p4])
		_laser_beams.draw_polygon(inner_poly, PackedColorArray([laser_color, laser_color, Color(laser_color.r, laser_color.g, laser_color.b, 0.15), Color(laser_color.r, laser_color.g, laser_color.b, 0.15)]))

		# 3. Lõi tia Laser trắng rực rỡ sắc nét (Ultra Bright Core)
		_laser_beams.draw_line(origin, origin + dir * beam_len, Color(1.0, 1.0, 1.0, laser_color.a * 0.95), 5.5)
		
		# 4. Quầng sáng rực rỡ ở gốc súng phun Laser (Emitter Flare)
		_laser_beams.draw_circle(origin, 14.0 + sin(_time_passed * 4.0 + float(e)) * 3.0, Color(1.0, 1.0, 1.0, 0.9))
		_laser_beams.draw_circle(origin, 22.0, Color(laser_color.r, laser_color.g, laser_color.b, 0.6))

func _on_audience_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_is_player_in_zone = true
		player_entered_stage_zone.emit()

func _on_audience_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_is_player_in_zone = false
		player_exited_stage_zone.emit()

func is_player_in_audience_zone() -> bool:
	return _is_player_in_zone
