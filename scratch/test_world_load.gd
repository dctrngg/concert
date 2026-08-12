@tool
extends SceneTree

func _init():
	print("Loading world.tscn...")
	var scene_res = load("res://Scene/world.tscn")
	if scene_res == null:
		print("ERROR: Failed to load world.tscn")
		quit(1)
		return
	var scene = scene_res.instantiate()
	print("Successfully instantiated world.tscn!")
	var player = scene.get_node("Player")
	var barrier = scene.get_node("barrier")
	var crowd = scene.get_node("CrowdManager")
	print("Player mask:", player.collision_mask)
	print("Barrier physics layers:", barrier.tile_set.get_physics_layers_count())
	print("Barrier collision layer 0:", barrier.tile_set.get_physics_layer_collision_layer(0))
	print("CrowdManager barrier_layer ref test:")
	crowd._ready()
	print("CrowdManager barrier_layer:", crowd.barrier_layer)
	print("All verification checks PASSED!")
	quit(0)
