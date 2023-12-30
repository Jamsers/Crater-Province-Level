@tool
extends Node3D

@export_category("Plant")
@export var plant_instances: bool = false : set = plant_instances_exec
@export var unplant_instances: bool = false : set = unplant_instances_exec

func plant_instances_exec(dummy: bool) -> void:
	for child in get_children():
		child.plant_instances_exec(true)

func unplant_instances_exec(dummy: bool) -> void:
	for child in get_children():
		child.unplant_instances_exec(true)
