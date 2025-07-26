@tool
extends Node3D

@export_category("Functions")
@export_tool_button("Store Base Transform")
var store_base_transform = store_base_transform_exec
@export_tool_button("Restore Base Transform")
var restore_base_transform = restore_base_transform_exec
@export_tool_button("Randomize")
var randomize = randomize_exec
@export_tool_button("Plant")
var instance = plant_exec

@export_category("Variables")
@export var plant_target: PhysicsBody3D

func randomize_exec():
	for child in get_children():
		await get_tree().process_frame
		child.randomize_exec()

func store_base_transform_exec():
	for child in get_children():
		await get_tree().process_frame
		child.store_base_transform_exec()

func restore_base_transform_exec():
	for child in get_children():
		await get_tree().process_frame
		child.restore_base_transform_exec()

func plant_exec():
	for child in get_children():
		child.plant_target = self.plant_target
		await get_tree().process_frame
		child.plant_exec()
