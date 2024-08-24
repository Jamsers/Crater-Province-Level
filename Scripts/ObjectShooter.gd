extends Node3D

@export var object_to_shoot: PackedScene

var objects_shot = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func cleanup():
	for object in objects_shot:
		object.queue_free()
	objects_shot.clear()

func shoot():
	var object = object_to_shoot.instantiate()
	objects_shot.append(object)
	get_node("../").add_child(object)
	object.global_position = global_position
	object.global_rotation = global_rotation
	#object.global_basis.z = global_basis.y
	#object.global_basis.y = -global_basis.z
	object.apply_central_impulse(-global_basis.z * 500)
