extends VehicleBody3D

@export var max_speed := 350
@export var steer_force := 0.1
@export var look_ahead := 100
@export var num_rays := 8

# context array
var ray_directions = []
var interest = []
var danger = []

var chosen_dir = Vector2.ZERO
var velocity = Vector2.ZERO
var acceleration = Vector2.ZERO

const DebugOverlay = preload("res://debug_overlay.gd")


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interest.resize(num_rays)
	danger.resize(num_rays)
	ray_directions.resize(num_rays)
	var debug = get_parent().get_node("DebugOverlay") as DebugOverlay
	print(transform.basis)
	for i in num_rays:
		var angle = i * 2 * PI / num_rays
		ray_directions[i] = transform.origin.rotated(Vector3.UP, angle)
		var r = ray_directions[i]
		debug.draw.add_vector(self, func(): return r, 4, 2) 


# # Called every frame. 'delta' is the elapsed time since the previous frame.
# func _process(delta: float) -> void:
# 	pass

func _physics_process(_delta: float) -> void:
	engine_force = clamp(25.5 - _delta * 5, -20 ,5.5)
	steer_force = 2
	steering = -0.05
	# set_interest()
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
		var d = ray_directions[i].dot(transform.basis.x)
		interest[i] = max(0, d)

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
