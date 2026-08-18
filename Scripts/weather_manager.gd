extends CanvasLayer
class_name WeatherManager

@export var weather_interval_min: float = 70.0
@export var weather_interval_max: float = 130.0
@export var rain_duration_min: float = 15.0
@export var rain_duration_max: float = 25.0

@onready var tint_overlay: ColorRect = find_child("RainTintOverlay", true, false) as ColorRect
@onready var rain_particles: CPUParticles2D = find_child("RainParticles", true, false) as CPUParticles2D
@onready var splash_particles: CPUParticles2D = find_child("SplashParticles", true, false) as CPUParticles2D

var is_raining: bool = false
var _weather_timer: float = 0.0
var _target_weather_time: float = 60.0
var _rain_timer: float = 0.0
var _target_rain_time: float = 20.0

var _tint_alpha: float = 0.0
var _target_tint_alpha: float = 0.0

func _ready() -> void:
	add_to_group("weather_manager")
	_target_weather_time = randf_range(weather_interval_min, weather_interval_max)
	if tint_overlay:
		tint_overlay.color.a = 0.0
	if rain_particles:
		rain_particles.emitting = false
	if splash_particles:
		splash_particles.emitting = false

func trigger_rain_now() -> void:
	_start_rain_event()

func _process(delta: float) -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		if ("is_gameplay_started" in gm) and not gm.is_gameplay_started:
			_stop_rain_immediately()
			return
		if ("is_level_active" in gm) and not gm.is_level_active:
			_stop_rain_immediately()
			return

	if get_tree().paused:
		return

	# Cập nhật độ mờ bầu khí quyển mưa mượt mà
	_tint_alpha = move_toward(_tint_alpha, _target_tint_alpha, delta * 0.15)
	if tint_overlay:
		tint_overlay.color = Color(0.1, 0.15, 0.25, _tint_alpha)

	if not is_raining:
		_weather_timer += delta
		if _weather_timer >= _target_weather_time:
			_start_rain_event()
	else:
		_rain_timer += delta
		if _rain_timer >= _target_rain_time:
			_stop_rain_event()

func _start_rain_event() -> void:
	is_raining = true
	_rain_timer = 0.0
	_target_rain_time = randf_range(rain_duration_min, rain_duration_max)
	_target_tint_alpha = 0.0
	
	if rain_particles:
		rain_particles.emitting = true
	if splash_particles:
		splash_particles.emitting = true

	print("[WeatherManager] 🌧️ TRỜI BẮT ĐẦU ĐỔ MƯA TRÊN ĐÊM ĐẠI NHẠC HỘI!")

func _stop_rain_event() -> void:
	is_raining = false
	_weather_timer = 0.0
	_target_weather_time = randf_range(weather_interval_min, weather_interval_max)
	_target_tint_alpha = 0.0

	if rain_particles:
		rain_particles.emitting = false
	if splash_particles:
		splash_particles.emitting = false

	print("[WeatherManager] ☀️ MƯA TẠNH, THỜI TIẾT TRỞ LẠI TRONG TRẺO.")

func _stop_rain_immediately() -> void:
	is_raining = false
	_weather_timer = 0.0
	_rain_timer = 0.0
	_tint_alpha = 0.0
	_target_tint_alpha = 0.0
	if tint_overlay:
		tint_overlay.color.a = 0.0
	if rain_particles:
		rain_particles.emitting = false
	if splash_particles:
		splash_particles.emitting = false
