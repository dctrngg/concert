extends Node

signal score_changed(current_score: int, target_stars: Array)
signal level_timer_updated(time_remaining: float, time_limit: float)
signal level_completed(score: int, stars_earned: int, is_passed: bool)
signal level_started(level_info: Dictionary)
signal chaos_changed(current_chaos: float, max_chaos: float)
signal game_over(reason: String)

# Cấu hình Cấp độ / Map
const LEVEL_CONFIGS: Array[Dictionary] = [
	{
		"level_id": 1,
		"title": "Cấp độ 1: Đêm Diễn Khởi Đầu",
		"description": "Làm quen với không khí concert. Phục vụ khán giả và đảm bảo an ninh!",
		"scene_path": "res://Scene/world.tscn",
		"time_limit": 300.0, # 5 phút
		"star_thresholds": [150, 350, 600] # Mốc 1 sao, 2 sao, 3 sao
	},
	{
		"level_id": 2,
		"title": "Cấp độ 2: Sức Nóng Đỉnh Điểm",
		"description": "Đám đông cuồng nhiệt hơn, nhiều sự cố ẩu đả phát sinh!",
		"scene_path": "res://Scene/world.tscn",
		"time_limit": 300.0, # 5 phút
		"star_thresholds": [200, 450, 750]
	},
	{
		"level_id": 3,
		"title": "Cấp độ 3: Đêm Đại Ca Nhạc",
		"description": "Thử thách lớn nhất! Đòi hỏi khả năng xử lý tình huống cực kỳ nhanh nhạy.",
		"scene_path": "res://Scene/world.tscn",
		"time_limit": 300.0, # 5 phút
		"star_thresholds": [250, 550, 900]
	}
]

var current_level_index: int = 0
var current_score: int = 0
var time_remaining: float = 300.0
var current_chaos: float = 0.0
var max_chaos: float = 100.0
var game_over_reason: String = ""
var is_level_active: bool = false
var is_paused: bool = false

# Dữ liệu lưu tiến trình mở khóa & số sao cao nhất
var unlocked_levels: Array = [1] # Mặc định level 1 đã mở khóa
var level_stars: Dictionary = {}      # level_id -> stars (int 0..3)
var level_high_scores: Dictionary = {}# level_id -> score (int)

const SAVE_PATH = "user://save_game.cfg"

func _ready() -> void:
	load_progress()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_custom_mouse_cursor()

func _setup_custom_mouse_cursor() -> void:
	var cursor_normal = load("res://Spritesheets/DEMO_Cozy_UI_Pack_doboui/Cursors/Cursors_Crosshairs/Cursors_32px/Cursor2_42px.png")
	var cursor_click = load("res://Spritesheets/DEMO_Cozy_UI_Pack_doboui/Cursors/Cursors_Crosshairs/Cursors_32px/Cursor2Clicked_42px.png")
	if cursor_normal:
		Input.set_custom_mouse_cursor(cursor_normal, Input.CURSOR_ARROW, Vector2(0, 0))
	if cursor_click:
		Input.set_custom_mouse_cursor(cursor_click, Input.CURSOR_POINTING_HAND, Vector2(0, 0))

func get_current_level_data() -> Dictionary:
	if current_level_index >= 0 and current_level_index < LEVEL_CONFIGS.size():
		return LEVEL_CONFIGS[current_level_index]
	return LEVEL_CONFIGS[0]

var is_gameplay_started: bool = false

func start_level(level_id: int) -> void:
	for i in range(LEVEL_CONFIGS.size()):
		if LEVEL_CONFIGS[i]["level_id"] == level_id:
			current_level_index = i
			break
			
	var level_data = get_current_level_data()
	current_score = 0
	current_chaos = 0.0
	game_over_reason = ""
	time_remaining = level_data["time_limit"]
	is_level_active = true
	is_gameplay_started = false # Chờ bấm PLAY ở màn hình Intro mới bắt đầu tính giờ!
	is_paused = false
	get_tree().paused = false
	
	score_changed.emit(current_score, level_data["star_thresholds"])
	chaos_changed.emit(current_chaos, max_chaos)
	level_timer_updated.emit(time_remaining, level_data["time_limit"])
	level_started.emit(level_data)
	
	# Load scene nếu chưa nằm đúng scene
	var target_scene = level_data["scene_path"]
	if get_tree().current_scene and get_tree().current_scene.scene_file_path != target_scene:
		get_tree().change_scene_to_file(target_scene)

func start_gameplay() -> void:
	is_gameplay_started = true
	print("[GameManager] ⏱️ Bắt đầu đếm ngược thời gian màn chơi!")

func add_score(amount: int) -> void:
	if not is_level_active:
		return
	current_score += amount
	var level_data = get_current_level_data()
	score_changed.emit(current_score, level_data["star_thresholds"])

func add_chaos(amount: float) -> void:
	if not is_level_active or not is_gameplay_started:
		return
	current_chaos = clamp(current_chaos + amount, 0.0, max_chaos)
	chaos_changed.emit(current_chaos, max_chaos)
	if current_chaos >= max_chaos and is_level_active:
		trigger_game_over("CONCERT_CHAOS_MAXED")

func reduce_chaos(amount: float) -> void:
	if not is_level_active:
		return
	current_chaos = clamp(current_chaos - amount, 0.0, max_chaos)
	chaos_changed.emit(current_chaos, max_chaos)

func trigger_game_over(reason: String) -> void:
	if not is_level_active:
		return
	is_level_active = false
	game_over_reason = reason
	print("[GameManager] ❌ GAME OVER! Lý do: ", reason)
	game_over.emit(reason)
	level_completed.emit(current_score, 0, false)

func _process(delta: float) -> void:
	if not is_level_active or not is_gameplay_started or is_paused or get_tree().paused:
		return
		
	# Tự động hạ Chaos mượt mà khi concert đang ổn định (-0.4%/s)
	if current_chaos > 0.0:
		current_chaos = max(0.0, current_chaos - delta * 0.4)
		chaos_changed.emit(current_chaos, max_chaos)
		
	time_remaining -= delta
	var level_data = get_current_level_data()
	level_timer_updated.emit(max(0.0, time_remaining), level_data["time_limit"])
	
	if time_remaining <= 0.0:
		finish_level()

func calculate_stars(score: int, thresholds: Array) -> int:
	if score >= thresholds[2]:
		return 3
	elif score >= thresholds[1]:
		return 2
	elif score >= thresholds[0]:
		return 1
	return 0

func finish_level() -> void:
	if not is_level_active:
		return
	is_level_active = false
	
	var level_data = get_current_level_data()
	var stars = calculate_stars(current_score, level_data["star_thresholds"])
	var is_passed = stars >= 1
	
	var level_id: int = level_data["level_id"]
	
	# Lưu điểm cao nhất và sao cao nhất
	if stars > level_stars.get(level_id, 0):
		level_stars[level_id] = stars
	if current_score > level_high_scores.get(level_id, 0):
		level_high_scores[level_id] = current_score
		
	# Mở khóa level tiếp theo nếu đạt tối thiểu 1 sao
	if is_passed:
		var next_level_id = level_id + 1
		if not (next_level_id in unlocked_levels):
			# Kiểm tra xem next_level_id có tồn tại trong LEVEL_CONFIGS không
			for cfg in LEVEL_CONFIGS:
				if cfg["level_id"] == next_level_id:
					unlocked_levels.append(next_level_id)
					break
					
	save_progress()
	level_completed.emit(current_score, stars, is_passed)

func retry_current_level() -> void:
	var level_data = get_current_level_data()
	start_level(level_data["level_id"])

func next_level() -> void:
	var level_data = get_current_level_data()
	var next_id = level_data["level_id"] + 1
	start_level(next_id)

func has_next_level() -> bool:
	var level_data = get_current_level_data()
	var next_id = level_data["level_id"] + 1
	for cfg in LEVEL_CONFIGS:
		if cfg["level_id"] == next_id:
			return true
	return false

# ─── SAVE / LOAD ─────────────────────────────────────────────────────────────

func save_progress() -> void:
	var config = ConfigFile.new()
	config.set_value("progress", "unlocked_levels", unlocked_levels)
	config.set_value("progress", "level_stars", level_stars)
	config.set_value("progress", "level_high_scores", level_high_scores)
	config.save(SAVE_PATH)

func load_progress() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err == OK:
		unlocked_levels = config.get_value("progress", "unlocked_levels", [1])
		level_stars = config.get_value("progress", "level_stars", {})
		level_high_scores = config.get_value("progress", "level_high_scores", {})
