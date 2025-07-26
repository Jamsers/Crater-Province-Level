@tool
extends EditorScenePostImportPlugin

const EXCLUDED_PATHS_SETTING = "jj_import_fixes/excluded_paths"

var import_hint_definitions = [
	{"string": "-animatable", "type": AnimatableBody3D},
	{"string": "-static", "type": StaticBody3D},
	{"string": "-rigid", "type": RigidBody3D},
	{"string": "-area", "type": Area3D}
]

var scene_path

func _get_import_options(path):
	scene_path = path

func _post_process(scene):
	var excluded_paths = ProjectSettings.get_setting(EXCLUDED_PATHS_SETTING, ["res://jj_import_fixes_example_folder/", "res://jj_import_fixes_example_file.glb"])
	var current_scene_path_normalized = scene_path.simplify_path()

	for excluded_pattern in excluded_paths:
		var normalized_excluded_pattern = excluded_pattern.simplify_path()

		if normalized_excluded_pattern.is_empty():
			continue

		if current_scene_path_normalized == normalized_excluded_pattern:
			return scene

		var folder_excluded_pattern = normalized_excluded_pattern
		if not folder_excluded_pattern.ends_with("/"):
			folder_excluded_pattern += "/"

		if current_scene_path_normalized.begins_with(folder_excluded_pattern):
			return scene

	scene = custom_import_hints(scene)
	scene = fix_skeletons(scene)
	scene = fix_colliders(scene)
	scene = solo_fix(scene)

	return scene

func custom_import_hints(scene):
	for node in get_all_children(scene):
		for import_hint in import_hint_definitions:
			if node.name.ends_with(import_hint.string):
				var original_transform = node.transform
				var original_name = node.name.rstrip(import_hint.string)
				
				var node_type = import_hint.type
				var new_node = node_type.new()
				
				node.replace_by(new_node)
				
				new_node.transform = original_transform
				new_node.name = original_name
				
				break
	return scene

func fix_colliders(scene):
	var parents_to_delete = []
	
	for node in get_all_children(scene):
		var parent = node.get_parent()
		var parent_of_parent = parent.get_parent()
		var original_name = parent.name
		var original_transform = parent.transform
		
		if node is CollisionShape3D and parent_of_parent is CollisionObject3D:
			parent.name = "If I'm still here, something went wrong"
			
			node.reparent(parent_of_parent)
			node.name = original_name
			node.transform = original_transform
			
			for child in parent.get_children():
				var child_original_transform = child.transform
				child.reparent(node)
				child.transform = child_original_transform
			
			if parent is CollisionObject3D and not parents_to_delete.has(parent):
				parents_to_delete.append(parent)
	
	for parent in parents_to_delete:
		scene.remove_child(parent)
		parent.owner = null
	
	return scene

func fix_skeletons(scene):
	var parents_to_delete = []
	
	for node in get_all_children(scene):
		var parent = node.get_parent()
		var parent_of_parent = parent.get_parent()
		var original_name = parent.name
		var original_transform = parent.transform
		var node_name = node.name
		
		if node is Skeleton3D and parent.get_class() == "Node3D":
			parent.name = "If I'm still here, something went wrong"
			
			node.reparent(parent_of_parent)
			node.name = original_name
			node.transform = original_transform
			
			for child in parent.get_children():
				var child_original_transform = child.transform
				child.reparent(node)
				child.transform = child_original_transform
			
			# This works. But only in the editor.
			# This is because this only changes the intermediate scene that gets imported. For this to work properly,
			# you'll need to actually save these changes to an animation library file, then point the scene to that file.
			# That's beyond the scope of this plugin, so this is commented out.
			# If you have any animated models, you should exempt them from this plugin,
			# or uncomment this code and implement the whole animation library saving kerfluffle.
			#
			# for parent_sibling in parent_of_parent.get_children():
			# 	if parent_sibling is AnimationPlayer:
			# 		for anim_name in parent_sibling.get_animation_list():
			# 			var animation = parent_sibling.get_animation(anim_name)
			# 			for i in range(animation.get_track_count()):
			# 				var path_names = animation.track_get_path(i).get_concatenated_names()
			# 				var path_subnames = animation.track_get_path(i).get_concatenated_subnames()
			#				
			# 				var current_path
			# 				if path_subnames == "":
			# 					current_path = path_names
			# 				else:
			# 					current_path = path_names + ":" + path_subnames
			#				
			# 				if current_path.begins_with(original_name + "/" + node_name):
			# 					current_path = current_path.replace(original_name + "/" + node_name, original_name)
			# 					animation.track_set_path(i, NodePath(current_path))
			
			if parent is Node3D and not parents_to_delete.has(parent):
				parents_to_delete.append(parent)
	
	for parent in parents_to_delete:
		scene.remove_child(parent)
		parent.owner = null
	
	return scene

func solo_fix(scene):
	var original_name = scene.name
	var child_to_remove = scene.get_child(0)
	
	if scene.get_child_count() == 1 and scene.get_class() == child_to_remove.get_class() and child_to_remove.transform == Transform3D.IDENTITY:
		copy_properties(child_to_remove, scene)
		scene.name = original_name
		
		for child in child_to_remove.get_children():
			var original_transform = child.transform
			child.reparent(scene)
			child.transform = original_transform
		
		scene.remove_child(child_to_remove)
		child_to_remove.owner = null
	
	return scene

func copy_properties(source_node, target_node):
	for property_info in source_node.get_property_list():
		var property_name = property_info.name
		
		if property_info.usage & PROPERTY_USAGE_STORAGE == 0:
			continue
		if property_info.usage & PROPERTY_USAGE_EDITOR == 0:
			continue
		if property_info.usage & PROPERTY_USAGE_INTERNAL == 1:
			continue
		if property_info.usage & PROPERTY_USAGE_SCRIPT_VARIABLE == 1:
			continue
		if property_info.usage & PROPERTY_USAGE_CATEGORY == 1:
			continue
		if property_info.usage & PROPERTY_USAGE_GROUP == 1:
			continue
		if target_node.has_node(property_name):
			continue
		
		var value = source_node.get(property_name)
		
		target_node.set(property_name, value)

func get_all_children(parent):
	var all_children = []
	
	for node in parent.get_children():
		if node.get_child_count() > 0:
			all_children.append(node)
			all_children.append_array(get_all_children(node))
		else:
			all_children.append(node)
	
	return all_children
