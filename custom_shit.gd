@tool
extends Node

@export var og: Node3D
@export var new: Node3D

@export_tool_button("exec")
var exec = exec_exec

func exec_exec():
	shuffle()
	shuffle()
	
	var og_cars = og.get_children()
	
	for car in og_cars:
		new.get_child(car.get_index()).transform = car.transform

func shuffle():
	var children = new.get_children()
	children.shuffle()
	
	var indexes = []
	var index = 0
	while index < new.get_child_count():
		indexes.append(index)
		index = index + 1
	
	for ind in indexes:
		new.move_child(children[ind], ind)
