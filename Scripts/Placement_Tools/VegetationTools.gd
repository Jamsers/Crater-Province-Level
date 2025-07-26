@tool
extends Node3D

@export_category("Functions")
@export_tool_button("Plant")
var plant = plant_exec
@export_tool_button("Unplant")
var unplant = unplant_exec
@export_tool_button("Instance")
var instance = instance_exec
@export_tool_button("Uninstance")
var uninstance = uninstance_exec

@export_category("Variables")
@export var rotation_range: float
@export var scale_range_min: float
@export var scale_range_max: float
@export var plant_target: PhysicsBody3D

func plant_exec():
	for child in get_children():
		child.rotation_range = self.rotation_range
		child.scale_range_min = self.scale_range_min
		child.scale_range_max = self.scale_range_max
		child.plant_target = self.plant_target
		await get_tree().process_frame
		child.plant_exec()

func unplant_exec():
	for child in get_children():
		await get_tree().process_frame
		child.unplant_exec()

func instance_exec():
	for child in get_children():
		await get_tree().process_frame
		child.instance_exec()

func uninstance_exec():
	for child in get_children():
		await get_tree().process_frame
		child.uninstance_exec()
