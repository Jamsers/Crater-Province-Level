extends Node

@export var animation_player: AnimationPlayer
@export var scenario_name: String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func play_scenario():
	animation_player.play(scenario_name)
	
