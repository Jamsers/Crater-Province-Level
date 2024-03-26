@tool
extends Node3D

@export_category("Functions")
#@export var randomize: bool = false : set = randomize_exec
#@export var store_base_transform: bool = false : set = store_base_transform_exec

@export_category("Randomize")
@export var position_range: float
@export var rotation_range: float
@export var scale_range: float

@export_category("Base Transform")
@export var base_position: Vector3
@export var base_rotation: Vector3
@export var base_scale: Vector3

@export_category("References")
@export var mesh: MeshInstance3D

func randomize_exec(dummy: bool) -> void:
	global_rotation_degrees = base_rotation + Vector3(randf_range(-rotation_range, rotation_range), randf_range(-rotation_range, rotation_range), randf_range(-rotation_range, rotation_range))
	var scale_rand = randf_range(1.0-scale_range, 1.0+scale_range)
	scale = Vector3(scale_rand, scale_rand, scale_rand)
	global_position = base_position + Vector3(randf_range(-position_range, position_range), randf_range(-position_range, position_range), randf_range(-position_range, position_range))

func store_base_transform_exec(dummy: bool) -> void:
	base_position = global_position
	base_rotation = global_rotation_degrees
	base_scale = scale

func instance_exec(dummy: bool) -> void:
	# changes made by @tool code to prefabs don't get saved in scene, so you'll have to toggle mesh visibility yourself manually in the prefab :(
	mesh.visible = false

func uninstance_exec(dummy: bool) -> void:
	# changes made by @tool code to prefabs don't get saved in scene, so you'll have to toggle mesh visibility yourself manually in the prefab :(
	mesh.visible = true
