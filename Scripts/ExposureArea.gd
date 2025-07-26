extends Area3D

enum AreaType {MAX_EXPOSURE, HALFWAY_EXPOSURE, WATER_FOG}

@export var area_type: AreaType

func _ready():
	area_entered.connect(_on_body_entered)
	area_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body == LightingChanger.self_reference.camera_tracker:
		match area_type:
			AreaType.MAX_EXPOSURE:
				LightingChanger.self_reference.set_player_is_in_max_exposure_area(true)
			AreaType.HALFWAY_EXPOSURE:
				LightingChanger.self_reference.set_player_is_in_halfway_exposure_area(true)
			AreaType.WATER_FOG:
				LightingChanger.self_reference.set_player_is_in_water_fog_area(true)

func _on_body_exited(body):
	if body == LightingChanger.self_reference.camera_tracker:
		match area_type:
			AreaType.MAX_EXPOSURE:
				LightingChanger.self_reference.set_player_is_in_max_exposure_area(false)
			AreaType.HALFWAY_EXPOSURE:
				LightingChanger.self_reference.set_player_is_in_halfway_exposure_area(false)
			AreaType.WATER_FOG:
				LightingChanger.self_reference.set_player_is_in_water_fog_area(false)
