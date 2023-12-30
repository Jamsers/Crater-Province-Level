extends Resource

class_name Lighting

@export_category("Time")
@export var military_time_hour: int = 12
@export var military_time_mins: int = 0

@export_category("Sun")
@export var sun_intensity_lux: float = 100000
@export var sun_temperature: float = 6500
@export var sun_rotation: Vector3 = Vector3(-90, 90, 0)

@export_category("Sky")
@export var sky_intensity_nits: float = 30000
@export var sky_top_color: Color = Color(0.384, 0.455, 0.549)
@export var sky_horizon_color: Color = Color(0.647, 0.655, 0.671)

@export_category("Exposure")
@export var exposure_sensitivity: float = 100

@export_category("Auto Exposure")
@export var auto_exposure_scale: float = 0.4
@export var auto_exposure_min_sensitivity: float = 10
@export var auto_exposure_max_sensitivity: float = 800
