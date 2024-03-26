@tool
extends Node3D

@export_category("Variables")
@export var rotation_range: float
@export var scale_range_min: float
@export var scale_range_max: float
@export var plant_target: PhysicsBody3D

@export_category("Options")
@export var do_not_randomize: bool = false

@export_category("References")
@export var mesh: MeshInstance3D

func plant_exec(dummy: bool) -> void:
	global_position = global_position + (Vector3.UP * 1000)
	
	await get_tree().process_frame
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + (Vector3.DOWN * 10000))
	var collision = space.intersect_ray(query)
	
	if collision and collision.collider == plant_target:
		global_position = collision.position
		global_rotation_degrees = Vector3.ZERO
		global_rotation_degrees.y = randf_range(0.0, 360.0)
		if !do_not_randomize:
			global_rotation_degrees.x = randf_range(-rotation_range, rotation_range)
			global_rotation_degrees.z = randf_range(-rotation_range, rotation_range)
			var scale_amount = randf_range(scale_range_min, scale_range_max)
			global_scale(Vector3(scale_amount, scale_amount, scale_amount))
	else:
		queue_free()

func unplant_exec(dummy: bool) -> void:
	global_rotation_degrees = Vector3.ZERO
	position.y = 0
	global_scale(Vector3.ONE)

func instance_exec(dummy: bool) -> void:
	# changes made by @tool code to prefabs don't get saved in scene, so you'll have to toggle mesh visibility yourself manually in the prefab :(
	mesh.visible = false

func uninstance_exec(dummy: bool) -> void:
	# changes made by @tool code to prefabs don't get saved in scene, so you'll have to toggle mesh visibility yourself manually in the prefab :(
	mesh.visible = true
