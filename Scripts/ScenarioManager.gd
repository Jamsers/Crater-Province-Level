extends Node

@export var menu: Control
@export var quit: Button
@export var ghfs_button: Button
@export var reloading_label: RichTextLabel
@export var menu_camera: Camera3D
@export var ghfs: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func switch_to_ghfs():
	var ghfs_instantiated = ghfs.instantiate()
	ghfs_instantiated.enable_physics_gun = true
	ghfs_instantiated.enable_depth_of_field = true
	ghfs_instantiated.position = Vector3(-201.846, 2.18, 38.889)
	ghfs_instantiated.rotation_degrees = Vector3(0, -125.4, 0)
	get_node("../").add_child(ghfs_instantiated)

func play_scenario():
	menu.visible = false
	ghfs_button.visible = false
	quit.visible = true

func stop_scenario():
	reloading_label.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().reload_current_scene()