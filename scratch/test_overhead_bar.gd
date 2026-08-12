extends SceneTree

func _init() -> void:
	var world_scene = load("res://Scene/world.tscn")
	var world = world_scene.instantiate()
	root.add_child(world)
	
	await process_frame
	await process_frame
	
	var player = world.get_node("Player")
	var bar = player.get_node("OverheadItemBar")
	bar.position = Vector2(-30.0, -26.0)
	
	await process_frame
	
	var hbox = bar.get_node("HBox")
	var slot1 = hbox.get_node("Slot1")
	var slot2 = hbox.get_node("Slot2")
	var slot3 = hbox.get_node("Slot3")
	
	print("--- TEST WITH position = Vector2(-30, -26) ---")
	print("Player global pos: ", player.global_position)
	print("Player scale: ", player.scale)
	print("OverheadItemBar pos: ", bar.position, " rect: ", bar.get_rect())
	print("Slot1 local X in Bar: ", slot1.position.x, " Slot1 center global X: ", slot1.get_global_transform().origin.x + (16.0*3.0/2.0))
	print("Slot2 local X in Bar: ", slot2.position.x, " Slot2 center global X: ", slot2.get_global_transform().origin.x + (16.0*3.0/2.0))
	print("Slot3 local X in Bar: ", slot3.position.x, " Slot3 center global X: ", slot3.get_global_transform().origin.x + (16.0*3.0/2.0))
	
	quit()
