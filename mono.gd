extends VehicleBody3D

@export var max_speed := 350
@export var look_ahead := 5
@export var num_rays := 16
@onready var navAgent = $NavigationAgent3D as NavigationAgent3D
@export var stuck_lenght = 10

# context array
var ray_directions :Array[Vector3]= []
var ray_directions_by_interest :Array[Vector3]= []
var ray_directions_by_interest_and_danger :Array[Vector3]= []
var interest = []
var danger = []
var ray_danger = []

var chosen_direction = Vector3.ZERO
var velocity = Vector2.ZERO
var acceleration = Vector2.ZERO

const DebugOverlay = preload("res://debug_overlay.gd")
var debug: DebugOverlay
var timer
var turnDirection
var backingOut := false
var isRight := false
var is_stuck := false
var is_initial := true
var previous_linear_velocity := 0.0
var delta_velocity := 0.0
var stuck_timeout := 3.0
var been_stuck_for_ms := 0.0
var stuck_total_time := 0.0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	navAgent.target_desired_distance = 2.5
	
	interest.resize(num_rays)
	danger.resize(num_rays)
	ray_directions.resize(num_rays)
	ray_directions_by_interest.resize(num_rays)
	ray_directions_by_interest_and_danger.resize(num_rays)
	ray_danger.resize(num_rays)

	for i in num_rays:
		var angle = i * 2 * PI / num_rays
		ray_directions[i] = (transform.basis.z).rotated(Vector3.UP, angle)

	# debug
	debug = get_parent().get_node("DebugOverlay") as DebugOverlay
	# for i in num_rays:
		# debug.draw.add_vector(self, func():return ray_directions[i].normalized(), 3, 2, Color(1,1,1) if i == 0 else Color(0.2, 1, 0.2) )
		# debug.draw.add_vector(self, func(): return ray_directions_by_interest_and_danger[i], 1, 2, Color(1,1,0))
		# debug.draw.add_vector(self, func(): return ray_danger[i], 2, 2, Color(1, 0, 0))

	# debug.draw.add_vector(self, func(): return chosen_direction.normalized(), 4, 2, Color(0, 0, 0.5))
	# debug.draw.add_property(self, "navAgent.target_position", func(): 
	# 	var t = navAgent.target_position
	# 	return " %.2f, %.2f, %.2f," % [t.x, t.y, t.z]
	# )
	# debug.draw.add_property(self, "previous_linear_velocity")
	# debug.draw.add_property(self, "delta_velocity")
	debug.draw.add_property(self, "is_stuck")
	debug.draw.add_property(self, "engine_force")
	debug.draw.add_property(self, "steering")
	debug.draw.add_property(self, "dot to chosen", func(): return "%.3f" % basis.z.normalized().dot(chosen_direction))
	# debug.draw.add_property(self, "chosen_dir")
	# debug.draw.add_property(self, "interest", func(): return interest.reduce(func(acc, i): return acc + ", %.2f" % i, ""))
	# debug.draw.add_property(self, "ray_directions_by_interest", func(): return ray_directions_by_interest.reduce(func(acc, i): return acc + ", [%.2f, %.2f, %.2f]" % [i.x, i.y, i.z], ""))
	# debug.draw.add_property(self, "linear_velocity")
	# debug.draw.add_property(self, "timer_nice", func(): return "%.2f" % timer.time_left)
	# debug.draw.add_property(self, "danger")
	# debug.draw.add_property(self, "steering")
	# debug.draw.add_property(self, "turnDirection")
	# debug.draw.add_property(self, "backingOut")
	# debug.draw.add_property(self, "isRight")
	# debug.draw.add_property(self, "transform.basis.z - chosen_dir", func(): return str(-transform.basis.z - chosen_dir))

func _physics_process(delta: float) -> void:
	if(is_stuck && been_stuck_for_ms < stuck_timeout):
		been_stuck_for_ms += delta
		return
	else:
		been_stuck_for_ms = 0.0 
		is_stuck = calculate_is_stuck(delta)

	for i in num_rays:
		var angle = i * 2 * PI / num_rays
		ray_directions[i] = (transform.basis.z).rotated(Vector3.UP, angle).normalized()
	# engine_force = max_speed

	steering = 0
	set_interest()
	set_danger()
	choose_direction()
	turnDirection = (transform.basis.z.normalized()).dot(chosen_direction.normalized())

	isRight = transform.basis.z.signed_angle_to(chosen_direction, Vector3.UP) < 0
	# if(backingOut): 
	# 	# until we've turned sufficiently - keep it going back
	# 	backingOut = turnDirection < 0.4 
	# else:
	# 	# only change steer when we are not backing out
	# 	backingOut = turnDirection < 0.2
	var steerDirection = -1 if isRight else 1
		# steerDirection = -steerDirection if backingOut else steerDirection
		## get the steering angle as what is left from the dot product to 1
		## if the turnDirection is 45 degress that's dot product (cos) of 0.5 so we steer 0.5
		## if the turnDirection is 22.5 degress that's dot product (cos) of 0.75 so we steer 0.25
	var turn = clampf(remap(turnDirection, 1.000, 0.89, 0.0, 0.4), 0, 0.41)
	steering = turn * steerDirection

	var deltaDirectionToDesire = basis.z.normalized().dot(chosen_direction)
	# if(deltaDirectionToDesire < 0.5):
	# when the direction we're going is too far away from the chosen - use lower engine force
	@warning_ignore("integer_division", "narrowing_conversion")
	engine_force = clampi(remap(deltaDirectionToDesire, -1, 0.7, max_speed / 5, max_speed), 0, max_speed)
	engine_force = -(abs(engine_force)) if backingOut else abs(engine_force)

	previous_linear_velocity = linear_velocity.length()
	if(is_stuck):
		engine_force = -(max_speed * 2 as float / 3)
		steering = -steering if abs(steering) > 0.3 else 0.3 


func set_interest():
	## when the navigation is finished and owner
	if(navAgent.is_navigation_finished() && owner and owner.has_method("get_next_position")):
		navAgent.target_position = owner.get_next_position(self)
		print("====== navigation finished %s" % str(navAgent.target_position))
	
	if(navAgent.target_position && navAgent.target_position != Vector3.ZERO):
		var target = -(global_transform.origin - navAgent.target_position);
		for i in num_rays:
			var d = ray_directions[i].normalized().dot(target)
			interest[i] = max(0, d)
			ray_directions_by_interest[i] = ray_directions[i] * interest[i]
	# If no world path, use default interest
	else:
		set_default_interest()

func set_default_interest():
	# Default to moving forward
	for i in num_rays:
		var d = ray_directions[i].dot(-transform.basis.z)
		interest[i] = max(0, d)

func set_danger():
	# Cast rays to find danger directions
	var space_state = get_world_3d().direct_space_state
	for i in num_rays:
		var result = space_state.intersect_ray(PhysicsRayQueryParameters3D.create(
			position,
			position + (ray_directions[i] * look_ahead),
			0b1111111111,
			[self.get_rid()]
		))
		# result.position holds the intersect point
		ray_danger[i] = Vector3.ZERO
		if result && result.has("position"): 
			# print("===== %s ray collided with %s" % [self.name, result.collider.name])
			ray_danger[i] = ray_directions[i]
		danger[i] = 1.0 if result else 0.0
		ray_directions_by_interest_and_danger[i] = Vector3.ZERO if result else ray_directions_by_interest[i]

func choose_direction():
	# Eliminate interest in slots with danger
	for i in num_rays:
		if ray_danger[i] != Vector3.ZERO:
			interest[i] = 0.0
	# Choose direction based on remaining interest
	chosen_direction = Vector3.ZERO
	for i in num_rays:
		chosen_direction += ray_directions[i] * interest[i]
	chosen_direction = chosen_direction.normalized()

func calculate_is_stuck(delta: float) -> bool:
	delta_velocity = linear_velocity.length() - previous_linear_velocity
	var isStuck = abs(delta_velocity) < 0.01 && abs(previous_linear_velocity) < 0.1

	if(isStuck):
		stuck_total_time += delta
	else:
		stuck_total_time = 0.0
	return stuck_total_time > 0.5