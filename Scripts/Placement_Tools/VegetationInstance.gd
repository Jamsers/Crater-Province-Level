@tool
extends MultiMeshInstance3D

@export_category("Functions")
@export var plant: bool = false : set = plant_exec
@export var unplant: bool = false : set = unplant_exec
@export var instance: bool = false : set = instance_exec
@export var uninstance: bool = false : set = uninstance_exec

@export_category("Variables")
@export var rotation_range: float
@export var scale_range_min: float
@export var scale_range_max: float
@export var plant_target: PhysicsBody3D

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

func plant_exec(dummy: bool) -> void:
	for child in get_children():
		child.rotation_range = self.rotation_range
		child.scale_range_min = self.scale_range_min
		child.scale_range_max = self.scale_range_max
		child.plant_target = self.plant_target
		await get_tree().process_frame
		child.plant_exec(true)

func unplant_exec(dummy: bool) -> void:
	for child in get_children():
		await get_tree().process_frame
		child.unplant_exec(true)
