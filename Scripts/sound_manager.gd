extends Node
## SoundManager - Quản lý Nhạc nền Playlist (Background MP3) & Hiệu ứng Âm thanh (SFX)
## Tự động phát lần lượt danh sách nhạc nền MP3, hỗ trợ quét thư mục và chỉnh âm lượng.

signal track_changed(track_name: String, track_index: int)
signal playlist_finished()

@export_group("Background Music Config")
## Danh sách các file nhạc nền MP3 / WAV / OGG (Kéo thả file mp3 trực tiếp vào đây trong Inspector)
@export var music_playlist: Array[AudioStream] = []

## Đường dẫn thư mục tự động quét nạp file MP3 nếu playlist trống (Ví dụ: "res://Audio/" hoặc "res://Music/")
@export var auto_scan_folder: String = "res://Music/"

## Tự động phát lặp lại playlist sau khi phát hết bài cuối
@export var loop_playlist: bool = true

## Phát ngẫu nhiên hay lần lượt theo thứ tự
@export var shuffle_tracks: bool = true

## Âm lượng nhạc nền mặc định (dB)
@export_range(-80.0, 6.0) var music_volume_db: float = -4.0:
	set(val):
		music_volume_db = val
		if is_node_ready() and _music_player:
			_music_player.volume_db = -80.0 if val <= -29.0 else val

@export_group("Sound Effects (SFX) - Tùy chỉnh âm thanh sự kiện")
## Âm lượng tổng cho tất cả hiệu ứng SFX (dB, ví dụ: 0.0 là chuẩn, 6.0 là to gấp đôi, 12.0 là rất to)
@export_range(-80.0, 24.0) var sfx_volume_db: float = 6.0:
	set(val):
		sfx_volume_db = val

## Tăng riêng âm lượng khi LẤY ĐỒ ÁN / LẤY GHẾ / BÁN HÀNG (dB, cộng thêm vào sfx_volume_db, mặc định +6.0 dB)
@export_range(-24.0, 24.0) var pickup_volume_boost: float = 6.0

## Giảm riêng âm lượng khi HOÀN THÀNH NHIỆM VỤ (dB, mặc định -8.0 dB để âm thanh nhỏ bớt vừa nghe)
@export_range(-30.0, 12.0) var quest_complete_volume_offset: float = -8.0

## File âm thanh khi nhận nhiệm vụ (Kéo thả file .mp3 / .wav / .ogg)
@export var quest_accept_sfx: AudioStream

## File âm thanh khi hoàn thành nhiệm vụ
@export var quest_complete_sfx: AudioStream

## File âm thanh khi thất bại nhiệm vụ
@export var quest_fail_sfx: AudioStream

## File âm thanh khi lấy đồ ăn tại quầy
@export var food_pickup_sfx: AudioStream

## File âm thanh khi lấy ghế từ kho
@export var chair_pickup_sfx: AudioStream

## File âm thanh khi bán đồ / merch cho khán giả
@export var merch_sell_sfx: AudioStream

var current_track_index: int = -1
var _music_player: AudioStreamPlayer = null

func _ready() -> void:
	if get_tree().root.has_node("SoundManager") and get_tree().root.get_node("SoundManager") != self:
		queue_free()
		return
		
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Khởi tạo Node AudioStreamPlayer cho nhạc nền
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "BackgroundMusicPlayer"
	_music_player.bus = "Master"
	_music_player.volume_db = -80.0 if music_volume_db <= -29.0 else music_volume_db
	_music_player.finished.connect(_on_music_track_finished)
	add_child(_music_player)
	
	# Nếu danh sách playlist trống -> Tự động quét thư mục nạp file mp3
	if music_playlist.is_empty():
		_auto_scan_music_files()
		
	# Tự động bắt đầu phát bài nhạc đầu tiên nếu có nhạc trong playlist
	if not music_playlist.is_empty():
		play_playlist()

	# Quét tự động nạp SFX nếu chưa gán trong Inspector
	_auto_scan_sfx_files()
	
	# Kết nối tín hiệu sự kiện từ QuestManager
	call_deferred("_connect_quest_manager")

func _connect_quest_manager() -> void:
	var quest_mgr = get_node_or_null("/root/QuestManager")
	if quest_mgr:
		if not quest_mgr.quest_accepted.is_connected(_on_quest_accepted):
			quest_mgr.quest_accepted.connect(_on_quest_accepted)
		if not quest_mgr.quest_completed.is_connected(_on_quest_completed):
			quest_mgr.quest_completed.connect(_on_quest_completed)
		if not quest_mgr.quest_failed.is_connected(_on_quest_failed):
			quest_mgr.quest_failed.connect(_on_quest_failed)

const MUSIC_CACHE_PATH = "user://music_cache.cfg"

## Tự động quét tìm tất cả file .mp3, .ogg, .wav trong thư mục auto_scan_folder (hỗ trợ Cache)
func _auto_scan_music_files() -> void:
	var config = ConfigFile.new()
	if FileAccess.file_exists(MUSIC_CACHE_PATH):
		var err = config.load(MUSIC_CACHE_PATH)
		if err == OK:
			var cached_paths: Array = config.get_value("music", "playlist_paths", [])
			if not cached_paths.is_empty():
				var all_valid = true
				var loaded_streams: Array[AudioStream] = []
				for file_path in cached_paths:
					if ResourceLoader.exists(file_path):
						var stream = load(file_path) as AudioStream
						if stream:
							loaded_streams.append(stream)
						else:
							all_valid = false
							break
					else:
						all_valid = false
						break
				if all_valid and not loaded_streams.is_empty():
					music_playlist = loaded_streams
					print("[SoundManager] ⚡ Nạp nhanh %d bài nhạc BGM từ cache %s!" % [music_playlist.size(), MUSIC_CACHE_PATH])
					return

	var folders_to_check = [auto_scan_folder, "res://sound/", "res://music/", "res://Audio/", "res://Sound/", "res://"]
	var sfx_keywords = ["pick", "done", "job", "accept", "complete", "fail", "sell", "coin"]
	for folder in folders_to_check:
		if DirAccess.dir_exists_absolute(folder):
			var dir = DirAccess.open(folder)
			if dir:
				dir.list_dir_begin()
				var file_name = dir.get_next()
				while file_name != "":
					if not dir.current_is_dir():
						var ext = file_name.get_extension().to_lower()
						var base = file_name.get_basename().to_lower()
						if ext in ["mp3", "ogg", "wav"]:
							var is_sfx = false
							for kw in sfx_keywords:
								if kw in base:
									is_sfx = true
									break
							if not is_sfx:
								var file_path = folder.path_join(file_name)
								if ResourceLoader.exists(file_path):
									var stream = load(file_path) as AudioStream
									if stream and not music_playlist.has(stream):
										music_playlist.append(stream)
										print("[SoundManager] 🎵 Đã tự động nạp bài nhạc BGM: ", file_name)
					file_name = dir.get_next()
				dir.list_dir_end()
		if not music_playlist.is_empty():
			break

	if music_playlist.is_empty():
		var static_bgm_paths = [
			"res://sound/1.mp3",
			"res://sound/2.mp3",
			"res://sound/3.mp3",
			"res://sound/4.mp3",
			"res://sound/5.mp3"
		]
		for p in static_bgm_paths:
			if ResourceLoader.exists(p):
				var stream = load(p) as AudioStream
				if stream:
					music_playlist.append(stream)
					print("[SoundManager] 🎵 Static fallback nạp BGM: ", p)

	# Save scanned paths to cache
	var valid_paths: Array = []
	for stream in music_playlist:
		if stream and stream.resource_path != "":
			valid_paths.append(stream.resource_path)
	if not valid_paths.is_empty():
		config.set_value("music", "playlist_paths", valid_paths)
		config.save(MUSIC_CACHE_PATH)

## Bắt đầu phát danh sách nhạc nền từ bài đầu tiên (hoặc bài chỉ định)
func play_playlist(start_index: int = 0) -> void:
	if music_playlist.is_empty():
		_auto_scan_music_files()
		
	if music_playlist.is_empty():
		print("[SoundManager] ℹ️ Chưa có bài nhạc .mp3 nào. Hãy kéo thả file mp3 vào Inspector hoặc tạo thư mục res://Music/")
		return
		
	if shuffle_tracks:
		current_track_index = randi() % music_playlist.size()
	else:
		current_track_index = clamp(start_index, 0, music_playlist.size() - 1)
	_play_current_track()

## Phát bài nhạc theo index hiện tại
func _play_current_track() -> void:
	if music_playlist.is_empty() or current_track_index < 0 or current_track_index >= music_playlist.size():
		return
		
	var stream = music_playlist[current_track_index]
	if stream:
		_music_player.stream = stream
		_music_player.volume_db = music_volume_db
		_music_player.play()
		
		var track_name = stream.resource_path.get_file().get_basename()
		track_changed.emit(track_name, current_track_index)
		print("[SoundManager] 🎶 Đang phát bài (%d/%d): %s" % [current_track_index + 1, music_playlist.size(), track_name])

## Signal tự động gọi khi phát hết 1 bài MP3 -> Chuyển sang bài kế tiếp lần lượt!
func _on_music_track_finished() -> void:
	if music_playlist.is_empty():
		return
		
	if shuffle_tracks:
		var next_idx = randi() % music_playlist.size()
		if music_playlist.size() > 1 and next_idx == current_track_index:
			next_idx = (current_track_index + 1) % music_playlist.size()
		current_track_index = next_idx
	else:
		current_track_index += 1
		if current_track_index >= music_playlist.size():
			if loop_playlist:
				current_track_index = 0
			else:
				current_track_index = -1
				playlist_finished.emit()
				print("[SoundManager] ⏹️ Đã phát hết toàn bộ playlist nhạc nền.")
				return
				
	_play_current_track()

## Chuyển sang bài nhạc kế tiếp
func play_next_track() -> void:
	if music_playlist.is_empty():
		return
	current_track_index = (current_track_index + 1) % music_playlist.size()
	_play_current_track()

## Quay lại bài nhạc trước đó
func play_previous_track() -> void:
	if music_playlist.is_empty():
		return
	current_track_index = (current_track_index - 1 + music_playlist.size()) % music_playlist.size()
	_play_current_track()

## Tạm dừng / Dừng phát nhạc nền
func stop_music() -> void:
	if _music_player:
		_music_player.stop()

## Tiếp tục phát nhạc
func resume_music() -> void:
	if _music_player and _music_player.stream and not _music_player.playing:
		_music_player.play()

## Thêm file MP3 mới vào playlist runtime
func add_track(stream: AudioStream) -> void:
	if stream and not music_playlist.has(stream):
		music_playlist.append(stream)
		if not _music_player.playing:
			play_playlist(music_playlist.size() - 1)

## Xóa toàn bộ playlist và đặt bài mới
func set_playlist(tracks: Array[AudioStream]) -> void:
	music_playlist = tracks
	if not music_playlist.is_empty():
		play_playlist(0)

## Điều chỉnh âm lượng nhạc nền (dB, ví dụ: 0.0 là chuẩn, -10.0 là nhỏ bớt, -80.0 là tắt hẳn)
func set_music_volume(volume_db: float) -> void:
	music_volume_db = volume_db
	if _music_player:
		_music_player.volume_db = -80.0 if volume_db <= -29.0 else volume_db
		if not _music_player.playing and not music_playlist.is_empty():
			resume_music()

## Điều chỉnh âm lượng hiệu ứng (dB)
func set_sfx_volume(volume_db: float) -> void:
	sfx_volume_db = volume_db

## Phát hiệu ứng âm thanh SFX một lần (Sound Effect - Chấp nhận cả AudioStream lẫn đường dẫn String)
func play_sfx(sound_arg: Variant, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var stream: AudioStream = null
	if sound_arg is AudioStream:
		stream = sound_arg
	elif sound_arg is String and ResourceLoader.exists(sound_arg):
		stream = load(sound_arg) as AudioStream
		
	if not stream:
		return
	var sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = stream
	sfx_player.volume_db = sfx_volume_db + volume_db
	sfx_player.pitch_scale = pitch_scale
	sfx_player.finished.connect(sfx_player.queue_free)
	add_child(sfx_player)
	sfx_player.play()

## --- SFX Event Triggers ---

func _on_quest_accepted(_quest: NPCQuestData) -> void:
	play_quest_accept_sfx()

func _on_quest_completed(_quest: NPCQuestData) -> void:
	play_quest_complete_sfx()

func _on_quest_failed(_quest: NPCQuestData) -> void:
	play_quest_fail_sfx()

func play_quest_accept_sfx(volume_db: float = NAN) -> void:
	var stream = quest_accept_sfx
	if stream:
		play_sfx(stream, 0.0 if is_nan(volume_db) else volume_db)
	else:
		print("[SoundManager] 🔊 (SFX Event) Nhận nhiệm vụ! (Chưa gán quest_accept_sfx trong Inspector)")

func play_quest_complete_sfx(volume_db: float = NAN) -> void:
	var stream = quest_complete_sfx
	if stream:
		var vol = quest_complete_volume_offset if is_nan(volume_db) else volume_db
		play_sfx(stream, vol)
	else:
		print("[SoundManager] 🔊 (SFX Event) Hoàn thành nhiệm vụ! (Chưa gán quest_complete_sfx trong Inspector)")

func play_quest_fail_sfx(volume_db: float = NAN) -> void:
	if quest_fail_sfx:
		play_sfx(quest_fail_sfx, 0.0 if is_nan(volume_db) else volume_db)

func play_food_pickup_sfx(volume_db: float = NAN) -> void:
	var stream = food_pickup_sfx if food_pickup_sfx else (chair_pickup_sfx if chair_pickup_sfx else merch_sell_sfx)
	if stream:
		var vol = pickup_volume_boost if is_nan(volume_db) else volume_db
		play_sfx(stream, vol)
	else:
		print("[SoundManager] 🔊 (SFX Event) Lấy đồ ăn thành công! (Chưa gán food_pickup_sfx trong Inspector)")

func play_chair_pickup_sfx(volume_db: float = NAN) -> void:
	var stream = chair_pickup_sfx if chair_pickup_sfx else (food_pickup_sfx if food_pickup_sfx else merch_sell_sfx)
	if stream:
		var vol = pickup_volume_boost if is_nan(volume_db) else volume_db
		play_sfx(stream, vol)
	else:
		print("[SoundManager] 🔊 (SFX Event) Lấy ghế thành công! (Chưa gán chair_pickup_sfx trong Inspector)")

func play_merch_sell_sfx(volume_db: float = NAN) -> void:
	var stream = merch_sell_sfx if merch_sell_sfx else (food_pickup_sfx if food_pickup_sfx else chair_pickup_sfx)
	if stream:
		var vol = pickup_volume_boost if is_nan(volume_db) else volume_db
		play_sfx(stream, vol)
	else:
		print("[SoundManager] 🔊 (SFX Event) Bán merchandise thành công!")

## Tự động tìm nạp các file SFX trong thư mục res://sound/ hoặc res://sound/sfx/ nếu chưa gán trong Inspector
func _auto_scan_sfx_files() -> void:
	var folders = ["res://sound/sfx/", "res://sound/", "res://Sound/", "res://Audio/"]
	var sfx_map = {
		"quest_accept": ["quest_accept", "nhan_nhiem_vu", "accept_quest", "quest_start", "job"],
		"quest_complete": ["quest_complete", "hoan_thanh", "complete_quest", "quest_done", "done"],
		"quest_fail": ["quest_fail", "that_bai", "fail_quest"],
		"food_pickup": ["food_pickup", "lay_do_an", "pickup_food", "food", "get_food", "pick"],
		"chair_pickup": ["chair_pickup", "lay_ghe", "pickup_chair", "chair", "get_chair", "pick"],
		"merch_sell": ["merch_sell", "ban_hang", "sell_merch", "coin", "sell", "pick"]
	}
	
	for folder in folders:
		if not DirAccess.dir_exists_absolute(folder):
			continue
		var dir = DirAccess.open(folder)
		if not dir:
			continue
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				var ext = file_name.get_extension().to_lower()
				if ext in ["mp3", "wav", "ogg"]:
					var base = file_name.get_basename().to_lower()
					var file_path = folder.path_join(file_name)
					if ResourceLoader.exists(file_path):
						var stream = load(file_path) as AudioStream
						if stream:
							if quest_accept_sfx == null and _matches_any(base, sfx_map["quest_accept"]):
								quest_accept_sfx = stream
								print("[SoundManager] 🔊 Đã nạp tự động quest_accept_sfx: ", file_name)
							if quest_complete_sfx == null and _matches_any(base, sfx_map["quest_complete"]):
								quest_complete_sfx = stream
								print("[SoundManager] 🔊 Đã nạp tự động quest_complete_sfx: ", file_name)
							if quest_fail_sfx == null and _matches_any(base, sfx_map["quest_fail"]):
								quest_fail_sfx = stream
								print("[SoundManager] 🔊 Đã nạp tự động quest_fail_sfx: ", file_name)
							if food_pickup_sfx == null and _matches_any(base, sfx_map["food_pickup"]):
								food_pickup_sfx = stream
								print("[SoundManager] 🔊 Đã nạp tự động food_pickup_sfx: ", file_name)
							if chair_pickup_sfx == null and _matches_any(base, sfx_map["chair_pickup"]):
								chair_pickup_sfx = stream
								print("[SoundManager] 🔊 Đã nạp tự động chair_pickup_sfx: ", file_name)
							if merch_sell_sfx == null and _matches_any(base, sfx_map["merch_sell"]):
								merch_sell_sfx = stream
								print("[SoundManager] 🔊 Đã nạp tự động merch_sell_sfx: ", file_name)
			file_name = dir.get_next()
		dir.list_dir_end()

	if quest_accept_sfx == null and ResourceLoader.exists("res://sound/job.mp3"):
		quest_accept_sfx = load("res://sound/job.mp3") as AudioStream
	if quest_complete_sfx == null and ResourceLoader.exists("res://sound/done.mp3"):
		quest_complete_sfx = load("res://sound/done.mp3") as AudioStream
	if food_pickup_sfx == null and ResourceLoader.exists("res://sound/pick.mp3"):
		food_pickup_sfx = load("res://sound/pick.mp3") as AudioStream
	if chair_pickup_sfx == null and ResourceLoader.exists("res://sound/pick.mp3"):
		chair_pickup_sfx = load("res://sound/pick.mp3") as AudioStream

func _matches_any(filename: String, patterns: Array) -> bool:
	for p in patterns:
		if p in filename:
			return true
	return false

