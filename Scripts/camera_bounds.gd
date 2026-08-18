extends Area2D
class_name CameraBounds
## CameraBounds - Giới hạn khung hình Camera2D trong phạm vi ô Collider chỉ định.
## Người chơi có thể kéo giãn RectangleShape2D trong Editor Viewport để chỉnh khung Camera.

@export var camera: Camera2D = null

func _ready() -> void:
	await get_tree().process_frame
	if not is_inside_tree() or get_tree() == null:
		return
	_apply_camera_limits()

func _apply_camera_limits() -> void:
	if not camera:
		var tree = get_tree()
		var player = tree.get_first_node_in_group("player") if tree else null
		if player:
			camera = player.get_node_or_null("Camera2D") as Camera2D
			
	if not camera:
		camera = get_viewport().get_camera_2d()
		
	if not camera:
		return
		
	var shape_node = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if not shape_node or not (shape_node.shape is RectangleShape2D):
		return
		
	var rect_shape = shape_node.shape as RectangleShape2D
	var half_size = (rect_shape.size * shape_node.scale) / 2.0
	var center = shape_node.global_position
	
	var min_x = int(center.x - half_size.x)
	var max_x = int(center.x + half_size.x)
	var min_y = int(center.y - half_size.y)
	var max_y = int(center.y + half_size.y)
	
	camera.limit_left = min_x
	camera.limit_top = min_y
	camera.limit_right = max_x
	camera.limit_bottom = max_y
	camera.limit_smoothed = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	
	print("[CameraBounds] 🎥 Đã giới hạn phạm vi Camera: Left=%d, Top=%d, Right=%d, Bottom=%d" % [min_x, min_y, max_x, max_y])
