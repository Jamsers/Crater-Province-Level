@tool
extends Node3D

@export_category("Plant")
@export var plant_instances: bool = false : set = plant_instances_exec
@export var unplant_instances: bool = false : set = unplant_instances_exec

@export_category("Options")
@export var do_not_randomize: bool = false

@export_category("References")
@export var mesh: MeshInstance3D

func plant_instances_exec(dummy: bool) -> void:
	global_position = global_position + (Vector3.UP * 1000)
	
	await get_tree().process_frame
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + (Vector3.DOWN * 10000))
	var collision = space.intersect_ray(query)
	
	if collision:
		global_position = collision.position
		if !do_not_randomize:
			global_position.y += randf_range(-1.1, 1.1)
			global_rotation_degrees.y = randf_range(0.0, 360.0)
	else:
		global_position.y = 100
	
	# changes made by @tool code to prefabs don't get saved in scene, so you'll have to toggle mesh visibility yourself manually in the prefab :(
	# mesh.visible = false

func unplant_instances_exec(dummy: bool) -> void:
	global_rotation_degrees.y = 0.0
	position.y = 0
	# changes made by @tool code to prefabs don't get saved in scene, so you'll have to toggle mesh visibility yourself manually in the prefab :(
	# mesh.visible = true
