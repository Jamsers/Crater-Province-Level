extends Node3D

@export var follow_target: Node3D
@export var camera: Camera3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func activate():
	camera.current = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	camera.look_at(follow_target.global_position)
	if camera.current:
		#dof logic
		if !get_node("%Scenario Manager").list_of_following_cameras_active.has(self):
			get_node("%Scenario Manager").list_of_following_cameras_active.append(self)
	else:
		if get_node("%Scenario Manager").list_of_following_cameras_active.has(self):
			get_node("%Scenario Manager").list_of_following_cameras_active.erase(self)
