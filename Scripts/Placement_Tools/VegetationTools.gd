@tool
extends Node3D

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

func plant_exec(dummy: bool) -> void:
	for child in get_children():
		child.rotation_range = self.rotation_range
		child.scale_range_min = self.scale_range_min
		child.scale_range_max = self.scale_range_max
		child.plant_target = self.plant_target
		child.plant_exec(true)

func unplant_exec(dummy: bool) -> void:
	for child in get_children():
		child.unplant_exec(true)

func instance_exec(dummy: bool) -> void:
	for child in get_children():
		child.instance_exec(true)

func uninstance_exec(dummy: bool) -> void:
	for child in get_children():
		child.uninstance_exec(true)
