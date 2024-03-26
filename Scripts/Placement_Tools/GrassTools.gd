@tool
extends Node3D

@export_category("Functions")
@export var set_grass_scalability: bool = false : set = set_grass_scalability_exec

@export_category("Variables")
@export var grass_range: float = 125
@export var grass_fade_range: float = 50
@export var grass_cull_supression: float = 50
@export var grass_chunk_range: float = 200

func set_grass_scalability_exec(dummy: bool) -> void:
	for child in get_children():
		child.optimization_dist_min = grass_range - (grass_fade_range / 2)
		child.optimization_dist_max = grass_range + (grass_fade_range / 2)
		child.optimization_level = grass_cull_supression
		child.visibility_range_end = grass_chunk_range
