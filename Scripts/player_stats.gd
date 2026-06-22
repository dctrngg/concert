extends Node
class_name PlayerStats

signal stamina_changed(current: float, max_val: float)
signal stress_changed(current: float, max_val: float)
signal stress_maxed()

@export var max_stamina: float = 100.0
@export var sprint_drain_per_sec: float = 20.0
@export var stamina_regen_per_sec: float = 12.0
@export var min_stamina_to_sprint: float = 5.0

@export var max_stress: float = 100.0
@export var stress_decay_per_sec: float = 0.5

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
			if stress >= max_stress:
				stress_maxed.emit()

var is_sprinting: bool = false

func _ready() -> void:
	# Bắt đầu phát các giá trị ban đầu sau khi các nút khác đã sẵn sàng lắng nghe
	call_deferred("_emit_initial")

func _emit_initial() -> void:
	stamina_changed.emit(stamina, max_stamina)
	stress_changed.emit(stress, max_stress)

func _process(delta: float) -> void:
	# 1) Handle Stamina Drain / Regen
	if is_sprinting:
		stamina -= sprint_drain_per_sec * delta
	else:
		stamina += stamina_regen_per_sec * delta

	# 2) Handle Stress Decay
	if stress > 0.0:
		stress -= stress_decay_per_sec * delta

func add_stress(amount: float) -> void:
	stress += amount

func reduce_stress(amount: float) -> void:
	stress -= amount
