@tool
extends EditorPlugin

var import_plugin

const EXCLUDED_PATHS_SETTING = "jj_import_fixes/excluded_paths"

func _enter_tree():
	import_plugin = preload("fix_import.gd").new()

	if ProjectSettings.has_setting(EXCLUDED_PATHS_SETTING) == false:
		ProjectSettings.set_setting(EXCLUDED_PATHS_SETTING, ["res://jj_import_fixes_example_folder/", "res://jj_import_fixes_example_file.glb"])
		ProjectSettings.save() 

	add_scene_post_import_plugin(import_plugin)

func _exit_tree():
	remove_scene_post_import_plugin(import_plugin)
	import_plugin = null
