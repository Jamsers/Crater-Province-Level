extends Node

@export var animation_player: AnimationPlayer
@export var menu: Control
@export var quit: Button
@export var reloading_label: RichTextLabel
@export var menu_camera: Camera3D
@export var camera: Camera3D
@export var scenario_name: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func play_scenario():
	animation_player.play(scenario_name)
	camera.current = true
	menu.visible = false
	quit.visible = true

func stop_scenario():
	reloading_label.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().reload_current_scene()
