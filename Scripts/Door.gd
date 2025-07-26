extends Node3D

@export var parent: StaticBody3D
@export var hinge: HingeJoint3D

func _ready():
	if parent != null:
		hinge.node_a = parent.get_path()
