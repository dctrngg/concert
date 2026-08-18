extends Node
class_name PlayerStats

signal stamina_changed(current: float, max_val: float)
signal stress_changed(current: float, max_val: float)
signal stress_maxed()
signal player_fainted(duration: float, faint_count: int, max_faints: int)

@export var max_stamina: float = 100.0
@export var sprint_drain_per_sec: float = 20.0
@export var stamina_regen_per_sec: float = 12.0
@export var min_stamina_to_sprint: float = 5.0

@export var max_stress: float = 100.0
@export var stress_decay_per_sec: float = 1.5
@export var max_faints: int = 3

var faint_count: int = 0
var is_fainted: bool = false
var faint_timer: float = 0.0

var stamina: float = 100.0:
	set(val):
		var prev = stamina
		stamina = clamp(val, 0.0, max_stamina)
		if stamina != prev:
			stamina_changed.emit(stamina, max_stamina)

var stress: float = 0.0:
	set(val):
		var prev = stress
		stress = clamp(val, 0.0, max_stress)
		if stress != prev:
			stress_changed.emit(stress, max_stress)
			if stress >= max_stress and not is_fainted:
				trigger_faint()

var is_sprinting: bool = false

func _ready() -> void:
	# Bắt đầu phát các giá trị ban đầu sau khi các nút khác đã sẵn sàng lắng nghe
	call_deferred("_emit_initial")

func _emit_initial() -> void:
	stamina_changed.emit(stamina, max_stamina)
	stress_changed.emit(stress, max_stress)

func trigger_faint() -> void:
	is_fainted = true
	faint_count += 1
	faint_timer = 3.0
	stress = 0.0 # Reset stress khi ngất xỉu
	stress_maxed.emit()
	player_fainted.emit(faint_timer, faint_count, max_faints)
	
	print("[PlayerStats] 😵 Bảo vệ bị ngất xỉu! Lần %d/%d" % [faint_count, max_faints])
	
	var gm = get_node_or_null("/root/GameManager")
	if faint_count >= max_faints and gm and gm.has_method("trigger_game_over"):
		gm.trigger_game_over("PLAYER_FAINTED")

func _process(delta: float) -> void:
	# Nếu đang trong trạng thái ngất xỉu
	if is_fainted:
		faint_timer -= delta
		# Tăng nhẹ Chaos trong lúc bảo vệ ngất xỉu
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.has_method("add_chaos"):
			gm.add_chaos(delta * 1.5)
			
		if faint_timer <= 0.0:
			is_fainted = false
			print("[PlayerStats] ⚡ Bảo vệ hồi phục sau cơn ngất xỉu!")
		return

	# 1) Handle Stamina Drain / Regen
	if is_sprinting:
		stamina -= sprint_drain_per_sec * delta
	else:
		stamina += stamina_regen_per_sec * delta

	# 2) Handle Stress Decay
	if stress > 0.0:
		stress -= stress_decay_per_sec * delta

func add_stress(amount: float) -> void:
	if not is_fainted:
		stress += amount

func reduce_stress(amount: float) -> void:
	stress -= amount
