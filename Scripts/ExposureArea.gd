extends Area3D

@export var camera_tracker: Area3D
@export var lighting_changer: LightingChanger
@export var is_halfway: bool = false

func _ready():
	area_entered.connect(_on_body_entered)
	area_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body == camera_tracker:
		if is_halfway:
			lighting_changer.set_player_is_in_halfway_exposure_area(true)
		else:
			lighting_changer.set_player_is_in_max_exposure_area(true)

func _on_body_exited(body):
	if body == camera_tracker:
		if is_halfway:
			lighting_changer.set_player_is_in_halfway_exposure_area(false)
		else:
			lighting_changer.set_player_is_in_max_exposure_area(false)
