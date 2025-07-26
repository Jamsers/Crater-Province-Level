@tool
extends Node3D

@export_category("Variables")
@export var lights_on: bool
@export var car_colors: Array[BaseMaterial3D]
@export var mat_front_light_on: BaseMaterial3D
@export var mat_front_light_off: BaseMaterial3D
@export var mat_back_light_on: BaseMaterial3D
@export var mat_back_light_off: BaseMaterial3D
@export var car_mesh: MeshInstance3D
@export var car_lights: Array[SpotLight3D]

func _ready():
	await get_tree().process_frame
	randomize_colors_exec()

func randomize_colors_exec():
	#car_mesh.set_surface_override_material(0, car_colors[randi_range(0, car_colors.size()-1)])
	if lights_on:
		car_mesh.set_surface_override_material(2, mat_front_light_on)
		car_mesh.set_surface_override_material(3, mat_back_light_on)
		for light in car_lights:
			light.visible = true
	else:
		car_mesh.set_surface_override_material(2, mat_front_light_off)
		car_mesh.set_surface_override_material(3, mat_back_light_off)
		for light in car_lights:
			light.visible = false
