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
@export var force_max_exposure: bool = false : set = force_max_exposure_exec
@export var force_halfway_exposure: bool = false : set = force_halfway_exposure_exec

@export_tool_button("Dump Lighting")
var dump_lighting = dump_lighting_exec

@export_category("Lighting to apply")
@export var lighting: Array[Lighting]
@export var max_exposure_lighting: Lighting
@export var halfway_exposure_lighting: Lighting

@export_category("Fog to apply")
@export var normal_fog: FogMaterial
@export var underwater_fog: FogMaterial

@export_category("References")
@export var environment: WorldEnvironment
@export var global_fog_volume: FogVolume
@export var sun: DirectionalLight3D
@export var camera_tracker: Area3D
@export var godot_human_for_scale_camera: Camera3D

const MAX_EXPOSURE_TRANSITION_SPEED = 0.75
const MIN_EXPOSURE_TRANSITION_SPEED = 0.01
const EXPOSURE_CURVE_GOING_DOWN = 0.05
const EXPOSURE_CURVE_GOING_UP = 0.5

static var self_reference: LightingChanger

var player_is_in_max_exposure_area = false
var player_is_in_halfway_exposure_area = false
var player_is_in_water_fog_area = false

func _ready():
	self_reference = self

func _process(delta):
	if !Engine.is_editor_hint():
		camera_tracker.global_position = get_viewport().get_camera_3d().global_position

func force_max_exposure_exec(is_in):
	set_player_is_in_max_exposure_area(is_in)
	force_max_exposure = is_in
	run_apply_lighting_exec()
	
func force_halfway_exposure_exec(is_in):
	set_player_is_in_halfway_exposure_area(is_in)
	force_halfway_exposure = is_in
	run_apply_lighting_exec()

func set_player_is_in_max_exposure_area(is_in):
	player_is_in_max_exposure_area = is_in
	
func set_player_is_in_halfway_exposure_area(is_in):
	player_is_in_halfway_exposure_area = is_in

func set_player_is_in_water_fog_area(is_in):
	player_is_in_water_fog_area = is_in

func run_apply_lighting_exec():
	if !Engine.is_editor_hint():
		return
	apply_lighting(military_time_hour, military_time_mins, 1.79769e308)

func apply_lighting(time_hour, time_mins, delta):
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
	
	var true_target_exposure_sensitivity = lerp(bottom_lerp.exposure_sensitivity, top_lerp.exposure_sensitivity, lerp_hour)
	var true_target_auto_exposure_scale = lerp(bottom_lerp.auto_exposure_scale, top_lerp.auto_exposure_scale, lerp_hour)
	var true_target_auto_exposure_min_sensitivity = lerp(bottom_lerp.auto_exposure_min_sensitivity, top_lerp.auto_exposure_min_sensitivity, lerp_hour)
	var true_target_auto_exposure_max_sensitivity = lerp(bottom_lerp.auto_exposure_max_sensitivity, top_lerp.auto_exposure_max_sensitivity, lerp_hour)
	
	var target_exposure_sensitivity
	var target_auto_exposure_scale
	var target_auto_exposure_min_sensitivity
	var target_auto_exposure_max_sensitivity
	
	if (player_is_in_halfway_exposure_area or (player_is_in_halfway_exposure_area and player_is_in_max_exposure_area)) and (true_target_exposure_sensitivity < halfway_exposure_lighting.exposure_sensitivity):
		target_exposure_sensitivity = halfway_exposure_lighting.exposure_sensitivity
		target_auto_exposure_scale = halfway_exposure_lighting.auto_exposure_scale
		target_auto_exposure_min_sensitivity = halfway_exposure_lighting.auto_exposure_min_sensitivity
		target_auto_exposure_max_sensitivity = halfway_exposure_lighting.auto_exposure_max_sensitivity
	elif player_is_in_max_exposure_area and (true_target_exposure_sensitivity < max_exposure_lighting.exposure_sensitivity):
		target_exposure_sensitivity = max_exposure_lighting.exposure_sensitivity
		target_auto_exposure_scale = max_exposure_lighting.auto_exposure_scale
		target_auto_exposure_min_sensitivity = max_exposure_lighting.auto_exposure_min_sensitivity
		target_auto_exposure_max_sensitivity = max_exposure_lighting.auto_exposure_max_sensitivity
	else:
		target_exposure_sensitivity = true_target_exposure_sensitivity
		target_auto_exposure_scale = true_target_auto_exposure_scale
		target_auto_exposure_min_sensitivity = true_target_auto_exposure_min_sensitivity
		target_auto_exposure_max_sensitivity = true_target_auto_exposure_max_sensitivity
	
	var exposure_sensitivity_transition_speed
	var auto_exposure_scale_transition_speed
	var auto_exposure_min_sensitivity_transition_speed
	var auto_exposure_max_sensitivity_transition_speed
	
	if target_exposure_sensitivity < environment.camera_attributes.exposure_sensitivity:
		exposure_sensitivity_transition_speed = lerp(MIN_EXPOSURE_TRANSITION_SPEED, MAX_EXPOSURE_TRANSITION_SPEED, ease(abs(environment.camera_attributes.exposure_sensitivity - target_exposure_sensitivity)/749875.0, EXPOSURE_CURVE_GOING_DOWN))
	else:
		exposure_sensitivity_transition_speed = lerp(MIN_EXPOSURE_TRANSITION_SPEED, MAX_EXPOSURE_TRANSITION_SPEED, ease(abs(environment.camera_attributes.exposure_sensitivity - target_exposure_sensitivity)/749875.0, EXPOSURE_CURVE_GOING_UP))
	
	if target_auto_exposure_scale < environment.camera_attributes.auto_exposure_scale:
		auto_exposure_scale_transition_speed = lerp(MIN_EXPOSURE_TRANSITION_SPEED, MAX_EXPOSURE_TRANSITION_SPEED, ease(abs(environment.camera_attributes.auto_exposure_scale - target_auto_exposure_scale)/0.12, EXPOSURE_CURVE_GOING_DOWN))
	else:
		auto_exposure_scale_transition_speed = lerp(MIN_EXPOSURE_TRANSITION_SPEED, MAX_EXPOSURE_TRANSITION_SPEED, ease(abs(environment.camera_attributes.auto_exposure_scale - target_auto_exposure_scale)/0.12, EXPOSURE_CURVE_GOING_UP))
	
	if target_auto_exposure_min_sensitivity < environment.camera_attributes.auto_exposure_min_sensitivity:
		auto_exposure_min_sensitivity_transition_speed = lerp(MIN_EXPOSURE_TRANSITION_SPEED, MAX_EXPOSURE_TRANSITION_SPEED, ease(abs(environment.camera_attributes.auto_exposure_min_sensitivity - target_auto_exposure_min_sensitivity)/1499950.0, EXPOSURE_CURVE_GOING_DOWN))
	else:
		auto_exposure_min_sensitivity_transition_speed = lerp(MIN_EXPOSURE_TRANSITION_SPEED, MAX_EXPOSURE_TRANSITION_SPEED, ease(abs(environment.camera_attributes.auto_exposure_min_sensitivity - target_auto_exposure_min_sensitivity)/1499950.0, EXPOSURE_CURVE_GOING_UP))
	
	if target_auto_exposure_max_sensitivity < environment.camera_attributes.auto_exposure_max_sensitivity:
		auto_exposure_max_sensitivity_transition_speed = lerp(MIN_EXPOSURE_TRANSITION_SPEED, MAX_EXPOSURE_TRANSITION_SPEED, ease(abs(environment.camera_attributes.auto_exposure_max_sensitivity - target_auto_exposure_max_sensitivity)/4999650.0, EXPOSURE_CURVE_GOING_DOWN))
	else:
		auto_exposure_max_sensitivity_transition_speed = lerp(MIN_EXPOSURE_TRANSITION_SPEED, MAX_EXPOSURE_TRANSITION_SPEED, ease(abs(environment.camera_attributes.auto_exposure_max_sensitivity - target_auto_exposure_max_sensitivity)/4999650.0, EXPOSURE_CURVE_GOING_UP))
	
	environment.camera_attributes.exposure_sensitivity = move_toward(environment.camera_attributes.exposure_sensitivity, target_exposure_sensitivity, (749875.0 * exposure_sensitivity_transition_speed) * delta)
	environment.camera_attributes.auto_exposure_scale = move_toward(environment.camera_attributes.auto_exposure_scale, target_auto_exposure_scale, (0.12 * auto_exposure_scale_transition_speed) * delta)
	environment.camera_attributes.auto_exposure_min_sensitivity = move_toward(environment.camera_attributes.auto_exposure_min_sensitivity, target_auto_exposure_min_sensitivity, (1499950.0 * auto_exposure_min_sensitivity_transition_speed) * delta)
	environment.camera_attributes.auto_exposure_max_sensitivity = move_toward(environment.camera_attributes.auto_exposure_max_sensitivity, target_auto_exposure_max_sensitivity, (4999650.0 * auto_exposure_max_sensitivity_transition_speed) * delta)
	
	if player_is_in_water_fog_area:
		global_fog_volume.material = underwater_fog
	else:
		global_fog_volume.material = normal_fog
	
	if Engine.is_editor_hint():
		environment.environment.sdfgi_enabled = false
		await get_tree().create_timer(0.1).timeout
		environment.environment.sdfgi_enabled = true

func dump_lighting_exec():
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
