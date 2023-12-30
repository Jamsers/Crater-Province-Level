extends Node

@export_category("Pause")
@export var time_pause: bool = false

@export_category("Time Scale")
## The length of a day, in minutes.
@export var day_length_mins: float = 20

@export_category("References")
@export var lighting_changer: LightingChanger

var time = 0.0

func _ready():
	var mins_converted = float(lighting_changer.military_time_mins) / 60.0
	time = float(lighting_changer.military_time_hour) + mins_converted

func _process(delta):
	if time_pause:
		return
	
	var hour = floor(time)
	var mins = time - hour
	mins = lerp(0, 60, mins)
	lighting_changer.apply_lighting(hour, mins)
	
	time += delta * ((24.0 / day_length_mins) / 60.0)
	
	if time >= 24.0:
		time = 0.0
