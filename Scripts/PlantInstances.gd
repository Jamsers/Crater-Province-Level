@tool
extends MultiMeshInstance3D

@export_category("Plant")
@export var plant_instances: bool = false : set = plant_instances_exec
@export var unplant_instances: bool = false : set = unplant_instances_exec

func plant_instances_exec(dummy: bool) -> void:
	for child in get_children():
		await child.plant_instances_exec(true)
	
	await get_tree().process_frame
	
	var scene_count = 0
	for child in get_children():
		scene_count += 1
	
	multimesh.instance_count = scene_count
	
	for child in get_children():
		multimesh.set_instance_transform(child.get_index(), child.transform)

func unplant_instances_exec(dummy: bool) -> void:
	multimesh.instance_count = 0
	for child in get_children():
		child.unplant_instances_exec(true)
