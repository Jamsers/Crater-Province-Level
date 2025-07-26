@tool
extends Node

@export_tool_button("exec")
var exec = exec_exec

func exec_exec():
	var children = get_children()
	children.shuffle()

	for child in get_children():
		remove_child(child)
	
	for child in children:
		add_child(child)
