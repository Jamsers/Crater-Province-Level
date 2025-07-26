@tool
extends Node3D

@export_category("Variables")
@export var position_range: float
@export var position_height_range: float
@export var scale_range_min: float
@export var scale_range_max: float
@export var cloud_distance: float

@export_category("Materials")
@export var cloud_materials: Array[BaseMaterial3D]
@export var cloud_mesh: MeshInstance3D

@export_category("Base Transform")
@export var base_position: Vector3

func plant_exec():
	if base_position.distance_to(Vector3.ZERO) < cloud_distance:
		global_position = base_position + Vector3(randf_range(-position_range, position_range), randf_range(-position_height_range, position_height_range), randf_range(-position_range, position_range))
		global_rotation_degrees.y = randf_range(0.0, 360.0)
		scale.x = randf_range(scale_range_min, scale_range_max)
		scale.y = randf_range(scale_range_min, scale_range_max)
		cloud_mesh.set_material_override(cloud_materials[randi_range(0, cloud_materials.size()-1)])
	else:
		queue_free()

func store_base_transform_exec():
	base_position = global_position
