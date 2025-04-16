extends VehicleBody3D

@export var max_speed := 350
@export var steer_force := 0.1
@export var look_ahead := 100
@export var num_rays := 8

# context array
var ray_directions :Array[Vector3]= []
var interest = []
var danger = []

var chosen_dir = Vector2.ZERO
var velocity = Vector2.ZERO
var acceleration = Vector2.ZERO

const DebugOverlay = preload("res://debug_overlay.gd")
var debug: DebugOverlay
var timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interest.resize(num_rays)
	danger.resize(num_rays)
	ray_directions.resize(num_rays)
	debug = get_parent().get_node("DebugOverlay") as DebugOverlay
	for i in num_rays:
		var angle = i * 2 * PI / num_rays
		ray_directions[i] = (transform.basis.z).rotated(Vector3.UP, angle)
		# var r = ray_directions[i]
		var color = Color(1,1,0) if i == 0 else Color(0,0,1)

		debug.draw.add_vector(self, func():return transform.basis.z, 4, 2, color)
	debug.draw.add_property(self, "linear_velocity")
	
	# timer for engine force 
	timer = Timer.new()
	add_child(timer)
	timer.one_shot = true;
	timer.start(2.5)
	debug.draw.add_property(self, "timer_nice", func(): return "%4.4f" % timer.time_left)
	debug.draw.add_property(timer, "time_left")


# # Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta: float) -> void:
# 	pass

func _physics_process(_delta: float) -> void:

	for i in num_rays:
		var angle = i * 2 * PI / num_rays
		ray_directions[i] = (transform.basis.z).rotated(Vector3.UP, angle)
	engine_force = 20

	if(timer.is_stopped()):
		engine_force = 0;
	steer_force = 2
	steering = -0.05
	set_interest()
	# set_danger()
	# choose_direction()
	# var desired_velocity = chosen_dir.rotated(rotation) * max_speed
	# velocity = velocity.linear_interpolate(desired_velocity, steer_force)
	# rotation = velocity.angle()
	# move_and_collide(velocity * delta)
	
	

func set_interest():
	# Set interest in each slot based on world direction
	if owner and owner.has_method("get_path_direction"):
		var path_direction = owner.get_path_direction(position)
		for i in num_rays:
			var d = ray_directions[i].dot(path_direction)
			interest[i] = max(0, d)
	# If no world path, use default interest
	else:
		set_default_interest()

func set_default_interest():
	# Default to moving forward
	for i in num_rays:
		var d = ray_directions[i].dot(-transform.basis.z)
		interest[i] = max(0, d)
		# var r = interest[i]
		# debug.draw.add_vector(self, func():return r, 6, 2) 
	# print(interest)

# func set_danger():
# 	# Cast rays to find danger directions
# 	var space_state = get_world_2d().direct_space_state
# 	for i in num_rays:
# 		var result = space_state.intersect_ray(position,
# 				position + ray_directions[i].rotated(rotation) * look_ahead,
# 				[self])
# 		danger[i] = 1.0 if result else 0.0

# func choose_direction():
# 	# Eliminate interest in slots with danger
# 	for i in num_rays:
# 		if danger[i] > 0.0:
# 			interest[i] = 0.0
# 	# Choose direction based on remaining interest
# 	chosen_dir = Vector2.ZERO
# 	for i in num_rays:
# 		chosen_dir += ray_directions[i] * interest[i]
# 	chosen_dir = chosen_dir.normalized()



#### Defaults
	# set_interest()
	# set_danger()
	# choose_direction()
	# var desired_velocity = chosen_dir.rotated(rotation) * max_speed
	# velocity = velocity.linear_interpolate(desired_velocity, steer_force)
	# rotation = velocity.angle()
	# move_and_collide(velocity * delta)
	
	

# func set_interest():
# 	# Set interest in each slot based on world direction
# 	if owner and owner.has_method("get_path_direction"):
# 		var path_direction = owner.get_path_direction(position)
# 		for i in num_rays:
# 			var d = ray_directions[i].rotated(rotation).dot(path_direction)
# 			interest[i] = max(0, d)
# 	# If no world path, use default interest
# 	else:
# 		set_default_interest()

# func set_default_interest():
# 	# Default to moving forward
# 	for i in num_rays:
# 		var d = ray_directions[i].rotated(rotation).dot(transform.x)
# 		interest[i] = max(0, d)

# func set_danger():
# 	# Cast rays to find danger directions
# 	var space_state = get_world_2d().direct_space_state
# 	for i in num_rays:
# 		var result = space_state.intersect_ray(position,
# 				position + ray_directions[i].rotated(rotation) * look_ahead,
# 				[self])
# 		danger[i] = 1.0 if result else 0.0

# func choose_direction():
# 	# Eliminate interest in slots with danger
# 	for i in num_rays:
# 		if danger[i] > 0.0:
# 			interest[i] = 0.0
# 	# Choose direction based on remaining interest
# 	chosen_dir = Vector2.ZERO
# 	for i in num_rays:
# 		chosen_dir += ray_directions[i] * interest[i]
# 	chosen_dir = chosen_dir.normalized()