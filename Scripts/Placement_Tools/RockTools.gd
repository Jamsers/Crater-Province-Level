@tool
extends Node3D

@export_category("Functions")
@export var store_base_transform: bool = false : set = store_base_transform_exec
@export var randomize: bool = false : set = randomize_exec
@export var instance: bool = false : set = instance_exec
@export var uninstance: bool = false : set = uninstance_exec

@export_category("Randomize")
@export var position_range: float
@export var rotation_range: float
@export var scale_range: float

func randomize_exec(dummy: bool) -> void:
	for child in get_children():
		child.position_range = position_range
		child.rotation_range = rotation_range
		child.scale_range = scale_range
		child.randomize_exec(true)

func store_base_transform_exec(dummy: bool) -> void:
	for child in get_children():
		child.store_base_transform_exec(true)

func instance_exec(dummy: bool) -> void:
	for child in get_children():
		child.instance_exec(true)

func uninstance_exec(dummy: bool) -> void:
	for child in get_children():
		child.uninstance_exec(true)
