@tool
extends Node3D

@export_category("Functions")
@export_tool_button("Store Base Transform")
var store_base_transform = store_base_transform_exec
@export_tool_button("Plant")
var plant = plant_exec

@export_category("Variables")
@export var position_range: float
@export var position_height_range: float
@export var scale_range_min: float
@export var scale_range_max: float
@export var cloud_distance: float

func plant_exec():
	for child in get_children():
		child.position_range = self.position_range
		child.position_height_range = self.position_height_range
		child.scale_range_min = self.scale_range_min
		child.scale_range_max = self.scale_range_max
		child.cloud_distance = self.cloud_distance
		child.plant_exec()

func store_base_transform_exec():
	for child in get_children():
		child.store_base_transform_exec()
