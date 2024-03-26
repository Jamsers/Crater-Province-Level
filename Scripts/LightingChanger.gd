@tool
extends Node

class_name LightingChanger

@export_category("Apply lighting")
@export_range(0, 23) var military_time_hour: float = 12 :
	set(value):
		military_time_hour = int(value)
		run_apply_lighting_exec()
@export_range(0, 59) var military_time_mins: float = 0 :
	set(value):
		military_time_mins = int(value)
		run_apply_lighting_exec()

@export_category("Dump Lighting")
@export var dump_lighting: bool = false : set = dump_lighting_exec

@export_category("Lighting to apply")
@export var lighting: Array[Lighting]

@export_category("References")
@export var environment: WorldEnvironment
@export var sun: DirectionalLight3D

func run_apply_lighting_exec():
	if !Engine.is_editor_hint():
		return
	apply_lighting(military_time_hour, military_time_mins)

func apply_lighting(time_hour, time_mins):
	var top_lerp
	var bottom_lerp
	var prev_lighting_scenario = lighting[lighting.size()-1]
	var found = false
	
	for lighting_scenario in lighting:
		if (time_hour == lighting_scenario.military_time_hour and time_mins <= lighting_scenario.military_time_mins) or time_hour < lighting_scenario.military_time_hour:
			top_lerp = lighting_scenario
			bottom_lerp = prev_lighting_scenario
			found = true
			break
		prev_lighting_scenario = lighting_scenario
	if not found:
		top_lerp = lighting[0]
		bottom_lerp = lighting[lighting.size()-1]
	
	var time_mins_float = float(time_mins) / 60.0
	var bottom_lerp_time_mins_float = float(bottom_lerp.military_time_mins) / 60.0
	var top_lerp_time_mins_float = float(top_lerp.military_time_mins) / 60.0
	
	var time_hour_final = float(time_hour) + time_mins_float
	var bottom_lerp_time_hour_final = float(bottom_lerp.military_time_hour) + bottom_lerp_time_mins_float
	var top_lerp_time_hour_final = float(top_lerp.military_time_hour) + top_lerp_time_mins_float
	
	if bottom_lerp == lighting[lighting.size()-1] and top_lerp == lighting[0]:
		top_lerp_time_hour_final = 24
	
	var lerp_hour = (time_hour_final - bottom_lerp_time_hour_final) / (top_lerp_time_hour_final - bottom_lerp_time_hour_final)
	
	sun.light_intensity_lux = lerp(bottom_lerp.sun_intensity_lux, top_lerp.sun_intensity_lux, lerp_hour)
	sun.light_temperature = lerp(bottom_lerp.sun_temperature, top_lerp.sun_temperature, lerp_hour)
	sun.rotation_degrees = lerp(bottom_lerp.sun_rotation, top_lerp.sun_rotation, lerp_hour)
	
	environment.environment.background_intensity = lerp(bottom_lerp.sky_intensity_nits, top_lerp.sky_intensity_nits, lerp_hour)
	environment.environment.sky.sky_material.sky_top_color = lerp(bottom_lerp.sky_top_color, top_lerp.sky_top_color, lerp_hour)
	environment.environment.sky.sky_material.sky_horizon_color = lerp(bottom_lerp.sky_horizon_color, top_lerp.sky_horizon_color, lerp_hour)
	environment.environment.sky.sky_material.ground_horizon_color = lerp(bottom_lerp.sky_horizon_color, top_lerp.sky_horizon_color, lerp_hour)
	 
	environment.camera_attributes.exposure_sensitivity = lerp(bottom_lerp.exposure_sensitivity, top_lerp.exposure_sensitivity, lerp_hour)
	
	environment.camera_attributes.auto_exposure_scale = lerp(bottom_lerp.auto_exposure_scale, top_lerp.auto_exposure_scale, lerp_hour)
	environment.camera_attributes.auto_exposure_min_sensitivity = lerp(bottom_lerp.auto_exposure_min_sensitivity, top_lerp.auto_exposure_min_sensitivity, lerp_hour)
	environment.camera_attributes.auto_exposure_max_sensitivity = lerp(bottom_lerp.auto_exposure_max_sensitivity, top_lerp.auto_exposure_max_sensitivity, lerp_hour)
	
	if Engine.is_editor_hint():
		environment.environment.sdfgi_enabled = false
		await get_tree().create_timer(0.1).timeout
		environment.environment.sdfgi_enabled = true

func dump_lighting_exec(dummy: bool) -> void:
	current_lighting_dump()

func current_lighting_dump():
	var lighting_dump = Lighting.new()
	lighting_dump.military_time_hour = military_time_hour
	lighting_dump.military_time_mins = military_time_mins
	lighting_dump.sun_intensity_lux = sun.light_intensity_lux
	lighting_dump.sun_temperature = sun.light_temperature
	lighting_dump.sun_rotation = sun.rotation_degrees
	lighting_dump.sky_intensity_nits = environment.environment.background_intensity
	lighting_dump.sky_top_color = environment.environment.sky.sky_material.sky_top_color
	lighting_dump.sky_horizon_color = environment.environment.sky.sky_material.sky_horizon_color
	lighting_dump.exposure_sensitivity = environment.camera_attributes.exposure_sensitivity
	lighting_dump.auto_exposure_scale = environment.camera_attributes.auto_exposure_scale
	lighting_dump.auto_exposure_min_sensitivity = environment.camera_attributes.auto_exposure_min_sensitivity
	lighting_dump.auto_exposure_max_sensitivity = environment.camera_attributes.auto_exposure_max_sensitivity
	var file_name = "TIME_"
	
	if military_time_hour < 12:
		file_name += "AM_"
		file_name += str(military_time_hour)
	else:
		file_name += "PM_"
		if military_time_hour == 12:
			file_name += str(military_time_hour)
		else:
			file_name += str(military_time_hour - 12)
	
	if military_time_mins != 0:
		file_name += "_" + str(military_time_mins)
	ResourceSaver.save(lighting_dump, "res://Resources/Lighting/" + file_name + ".tres")
