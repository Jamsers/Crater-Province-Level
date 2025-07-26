extends Area3D

@export var float_force: float

@onready var space_state = get_world_3d().direct_space_state

func _physics_process(delta):
	for body in get_overlapping_bodies():
		if body is RigidBody3D and body.freeze == false:
			if is_point_inside_area(body.to_global(body.center_of_mass), self):
				body.apply_force(Vector3.UP * (body.mass * float_force), body.center_of_mass)

func is_point_inside_area(point, area):
	var query = PhysicsPointQueryParameters3D.new()
	query.position = point
	query.collide_with_areas = true
	
	var result = space_state.intersect_point(query)
	
	for res in result:
		if res.collider == area:
			return true
	return false
