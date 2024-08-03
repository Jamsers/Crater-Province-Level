@tool
extends MultiMeshInstance3D

@export_category("Functions")
@export var store_base_transform: bool = false : set = store_base_transform_exec
@export var randomize: bool = false : set = randomize_exec
@export var instance: bool = false : set = instance_exec
@export var uninstance: bool = false : set = uninstance_exec

@export_category("Randomize")
@export var position_range: float
@export var rotation_range: float
@export var scale_range: float

func instance_exec(dummy: bool) -> void:
	multimesh = multimesh.duplicate()
	
	for child in get_children():
		await get_tree().process_frame
		child.instance_exec(true)
	
	var scene_count = 0
	for child in get_children():
		scene_count += 1
	
	multimesh.instance_count = scene_count
	
	for child in get_children():
		multimesh.set_instance_transform(child.get_index(), child.transform)

func uninstance_exec(dummy: bool) -> void:
	multimesh.instance_count = 0
	for child in get_children():
		await get_tree().process_frame
		child.uninstance_exec(true)

func randomize_exec(dummy: bool) -> void:
	for child in get_children():
		child.position_range = position_range
		child.rotation_range = rotation_range
		child.scale_range = scale_range
		await get_tree().process_frame
		child.randomize_exec(true)

func store_base_transform_exec(dummy: bool) -> void:
	for child in get_children():
		await get_tree().process_frame
		child.store_base_transform_exec(true)
