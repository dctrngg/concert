extends Node

signal score_changed(current_score: int, target_stars: Array)
signal level_timer_updated(time_remaining: float, time_limit: float)
signal level_completed(score: int, stars_earned: int, is_passed: bool)
signal level_started(level_info: Dictionary)

signal fever_state_changed(is_fever: bool, multiplier: int)
signal combo_updated(combo_count: int, multiplier: int, time_left: float)

# FEVER MODE & COMBO STREAK
var combo_count: int = 0
var combo_timer: float = 0.0
var fever_multiplier: int = 1
var is_fever_active: bool = false
const COMBO_WINDOW_DURATION: float = 14.0

func register_quest_completion() -> void:
	if not is_level_active:
		return
		
	combo_count += 1
	combo_timer = COMBO_WINDOW_DURATION
	
	var old_multiplier = fever_multiplier
	var old_fever = is_fever_active
	
	if combo_count >= 5:
		fever_multiplier = 4
		is_fever_active = true
	elif combo_count >= 3:
		fever_multiplier = 3
		is_fever_active = true
	elif combo_count >= 2:
		fever_multiplier = 2
		is_fever_active = true
	else:
		fever_multiplier = 1
		is_fever_active = false
		
	if old_fever != is_fever_active or old_multiplier != fever_multiplier:
		fever_state_changed.emit(is_fever_active, fever_multiplier)
		var stage_node = get_tree().get_first_node_in_group("concert_stage")
		if stage_node and stage_node.has_method("burst_confetti"):
			stage_node.burst_confetti()
			
	combo_updated.emit(combo_count, fever_multiplier, combo_timer)

func _reset_combo() -> void:
	combo_count = 0
	combo_timer = 0.0
	var was_fever = is_fever_active
	fever_multiplier = 1
	is_fever_active = false
	if was_fever:
		fever_state_changed.emit(false, 1)
	combo_updated.emit(0, 1, 0.0)

func add_score(amount: int) -> void:
	if not is_level_active:
		return
	var final_amount = amount * fever_multiplier
	current_score += final_amount
	var level_data = get_current_level_data()
	score_changed.emit(current_score, level_data["star_thresholds"])

func _process(delta: float) -> void:
	if not is_level_active or is_paused or get_tree().paused:
		return
		
	time_remaining -= delta
	var level_data = get_current_level_data()
	level_timer_updated.emit(max(0.0, time_remaining), level_data["time_limit"])
	
	# Cập nhật đếm ngược Combo Timer
	if combo_timer > 0.0:
		combo_timer -= delta
		combo_updated.emit(combo_count, fever_multiplier, combo_timer)
		if combo_timer <= 0.0:
			_reset_combo()
	
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
