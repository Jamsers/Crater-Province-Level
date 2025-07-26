@tool
extends Node3D

@export_category("Variables")
@export var plant_target: PhysicsBody3D

@export_category("Options")
@export var is_flipped: bool = false

@export_category("Randomize")
var position_range: float = 0.4
var rotation_range: float = 180
var scale_range: float = 0.5

@export_category("Base Transform")
@export var base_position: Vector3
@export var base_rotation: Vector3
@export var base_scale: Vector3

func plant_exec():
	if is_flipped:
		plant_up()
	else:
		plant_down()

func store_base_transform_exec():
	base_position = global_position
	base_rotation = global_rotation_degrees
	base_scale = scale

func restore_base_transform_exec():
	global_position = base_position
	global_rotation_degrees = base_rotation
	scale = base_scale

func randomize_exec():
	global_rotation_degrees = base_rotation + Vector3(0.0, randf_range(-rotation_range, rotation_range), 0.0)
	var scale_rand = randf_range(1.0-scale_range, 1.0+scale_range)
	scale = Vector3(scale_rand, scale_rand, scale_rand)
	global_position = base_position + Vector3(randf_range(-position_range, position_range), 0.0, randf_range(-position_range, position_range))

func plant_down():
	global_position = global_position + (Vector3.UP * 0.5)
	
	await get_tree().process_frame
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + (Vector3.DOWN * 10000))
	var collision = space.intersect_ray(query)
	
	if collision and collision.collider == plant_target:
		global_position = collision.position

func plant_up():
	global_position = global_position + (Vector3.DOWN * 0.5)
	
	await get_tree().process_frame
	
	var space = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + (Vector3.UP * 10000))
	var collision = space.intersect_ray(query)
	
	if collision and collision.collider == plant_target:
		global_position = collision.position
