extends Node

@export var heavy_shit: PackedScene
@export var should_load: bool = true

func _ready():
	if should_load:
		add_child(heavy_shit.instantiate())
