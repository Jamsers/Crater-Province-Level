extends RichTextLabel

func _ready():
	refresh_performance()

func refresh_performance():
	var fps = "FPS: " + str(Performance.get_monitor(Performance.TIME_FPS))
	var frametime = "Frame time: " + str(snapped(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, 0.01)) + " ms"
	var physics_frametime = "Physics frame time: " + str(snapped(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.01)) + " ms"
	var draw_calls = "Draw calls: " + str(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var memory = "RAM: " + str(snapped(Performance.get_monitor(Performance.MEMORY_STATIC) * 0.000001, 0.01)) + " MB"
	var vram = "VRAM: " + str(snapped(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) * 0.000001, 0.01)) + " MB"
	
	text = fps + "\n" + frametime + "\n" + physics_frametime + "\n" + draw_calls + "\n" + memory + "\n" + vram
	
	await get_tree().create_timer(0.75).timeout
	
	refresh_performance()
