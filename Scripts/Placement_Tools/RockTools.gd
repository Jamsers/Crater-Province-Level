@tool
extends Node3D

@export_category("Functions")
@export_tool_button("Store Base Transform")
var store_base_transform = store_base_transform_exec
@export_tool_button("Randomize")
var randomize = randomize_exec
@export_tool_button("Instance")
var instance = instance_exec
@export_tool_button("Uninstance")
var uninstance = uninstance_exec

@export_category("Randomize")
@export var position_range: float
@export var rotation_range: float
@export var scale_range: float

func randomize_exec():
	for child in get_children():
		child.position_range = position_range
		child.rotation_range = rotation_range
		child.scale_range = scale_range
		await get_tree().process_frame
		child.randomize_exec()

func store_base_transform_exec():
	for child in get_children():
		await get_tree().process_frame
		child.store_base_transform_exec()

func instance_exec():
	for child in get_children():
		await get_tree().process_frame
		child.instance_exec()

func uninstance_exec():
	for child in get_children():
		await get_tree().process_frame
		child.uninstance_exec()
