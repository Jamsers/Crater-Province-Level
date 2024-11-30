extends RichTextLabel

@export_category("References")
@export var tod_system: TimeOfDaySystem

func _ready():
	refresh_performance()

func refresh_performance():
	var tod = "Time of day: " + human_tod(tod_system.time)
	var fps = "FPS: " + str(Performance.get_monitor(Performance.TIME_FPS))
	var frametime = "Frame time: " + str(snapped(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01)) + " ms"
	var physics_frametime = "Physics frame time: " + str(snapped(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01)) + " ms"
	var draw_calls = "Draw calls: " + str(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var memory = "RAM: " + str(snapped(Performance.get_monitor(Performance.MEMORY_STATIC) * 0.000001, 0.01)) + " MB"
	var vram = "VRAM: " + str(snapped(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) * 0.000001, 0.01)) + " MB"
	
	text = tod + "\n" + fps + "\n" + frametime + "\n" + physics_frametime + "\n" + draw_calls + "\n" + memory + "\n" + vram
	
	await get_tree().create_timer(0.75).timeout
	
	refresh_performance()

func human_tod(time):
	var hour = floor(time)
	var mins = time - hour
	mins = lerp(0, 60, mins)
	
	var is_pm = false
	if hour == 0:
		hour = 12
		is_pm = true
	elif hour > 12:
		hour = hour - 12
		is_pm = true
	
	if hour == 12:
		is_pm = !is_pm
	
	var suffix
	if is_pm:
		suffix = "PM"
	else:
		suffix = "AM"
	
	return ("%1d:%02d" % [hour, mins]) + " " + suffix
