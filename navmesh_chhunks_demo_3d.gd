extends Node3D


static var map_cell_size: float = 0.25
static var chunk_size: int = 16
static var cell_size: float = 0.25
static var agent_radius: float = 0.5
static var chunk_id_to_region: Dictionary = {}

var character_speed := 10

@onready var player: Node3D = $Obj
@onready var playerNavAgent := $Obj/NavigationAgent3D as NavigationAgent3D
@onready var player2: Node3D = $Obj2
@onready var playerNavAgent2 := $Obj2/NavigationAgent3D as NavigationAgent3D
@onready var checkpoints := [$ParseRootNode/Checkpoint_1, $ParseRootNode/Checkpoint_2, $ParseRootNode/Checkpoint_3 ]
@onready var currentCheckpoint: Area3D = $ParseRootNode/Checkpoint_1


@onready var mono: VehicleBody3D = $Mono
@onready var monoNavAgent := $Mono/NavigationAgent3D as NavigationAgent3D
@onready var monoCurrentCheckpoint: Area3D = $ParseRootNode/Checkpoint_1

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



var path_start_position: Vector3

func _ready() -> void:
	NavigationServer3D.set_debug_enabled(true)

	path_start_position = %DebugPaths.global_position

	var map: RID = get_world_3d().navigation_map
	NavigationServer3D.map_set_cell_size(map, map_cell_size)

	# Disable performance costly edge connection margin feature.
	# This feature is not needed to merge navigation mesh edges.
	# If edges are well aligned they will merge just fine by edge key.
	NavigationServer3D.map_set_use_edge_connections(map, false)

	# Parse the collision shapes below our parse root node.
	var source_geometry: NavigationMeshSourceGeometryData3D = NavigationMeshSourceGeometryData3D.new()
	var parse_settings: NavigationMesh = NavigationMesh.new()
	parse_settings.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	NavigationServer3D.parse_source_geometry_data(parse_settings, source_geometry, %ParseRootNode)

	create_region_chunks(%ChunksContainer, source_geometry, chunk_size * cell_size, agent_radius)

	interest.resize(num_rays)
	danger.resize(num_rays)
	ray_directions.resize(num_rays)
	for i in num_rays:
		var angle = i * 2 * PI / num_rays
		ray_directions[i] = Vector2.RIGHT.rotated(angle)

	player.set_meta("next_position", Vector3.ZERO)
	$DebugOverlay.draw.add_vector(player, "next_position", 2, 4, Color(1,1,1))

static func create_region_chunks(chunks_root_node: Node, p_source_geometry: NavigationMeshSourceGeometryData3D, p_chunk_size: float, p_agent_radius: float) -> void:
	# We need to know how many chunks are required for the input geometry.
	# So first get an axis aligned bounding box that covers all vertices.
	var input_geometry_bounds: AABB = calculate_source_geometry_bounds(p_source_geometry)

	# Rasterize bounding box into chunk grid to know range of required chunks.
	var start_chunk: Vector3 = floor(
		input_geometry_bounds.position / p_chunk_size
	)
	var end_chunk: Vector3 = floor(
		(input_geometry_bounds.position + input_geometry_bounds.size)
		/ p_chunk_size
	)

	# NavigationMesh.border_size is limited to the xz-axis.
	# So we can only bake one chunk for the y-axis and also
	# need to span the bake bounds over the entire y-axis.
	# If we dont do this we would create duplicated polygons
	# and stack them on top of each other causing merge errors.
	var bounds_min_height: float = start_chunk.y
	var bounds_max_height: float = end_chunk.y + p_chunk_size
	var chunk_y: int = 0

	for chunk_z in range(start_chunk.z, end_chunk.z + 1):
		for chunk_x in range(start_chunk.x, end_chunk.x + 1):
			var chunk_id: Vector3i = Vector3i(chunk_x, chunk_y, chunk_z)

			var chunk_bounding_box: AABB = AABB(
				Vector3(chunk_x, bounds_min_height, chunk_z) * p_chunk_size,
				Vector3(p_chunk_size, bounds_max_height, p_chunk_size),
			)
			# We grow the chunk bounding box to include geometry
			# from all the neighbor chunks so edges can align.
			# The border size is the same value as our grow amount so
			# the final navigation mesh ends up with the intended chunk size.
			var baking_bounds: AABB = chunk_bounding_box.grow(p_chunk_size)

			var chunk_navmesh: NavigationMesh = NavigationMesh.new()
			chunk_navmesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
			chunk_navmesh.cell_size = cell_size
			chunk_navmesh.cell_height = cell_size
			chunk_navmesh.filter_baking_aabb = baking_bounds
			chunk_navmesh.border_size = p_chunk_size
			chunk_navmesh.agent_radius = p_agent_radius
			NavigationServer3D.bake_from_source_geometry_data(chunk_navmesh, p_source_geometry)

			# The only reason we reset the baking bounds here is to not render its debug.
			chunk_navmesh.filter_baking_aabb = AABB()

			# Snap vertex positions to avoid most rasterization issues with float precision.
			var navmesh_vertices: PackedVector3Array = chunk_navmesh.vertices
			for i in navmesh_vertices.size():
				var vertex: Vector3 = navmesh_vertices[i]
				navmesh_vertices[i] = vertex.snappedf(map_cell_size * 0.1)
			chunk_navmesh.vertices = navmesh_vertices

			var chunk_region: NavigationRegion3D = NavigationRegion3D.new()
			chunk_region.navigation_mesh = chunk_navmesh
			chunks_root_node.add_child(chunk_region)

			chunk_id_to_region[chunk_id] = chunk_region


static func calculate_source_geometry_bounds(p_source_geometry: NavigationMeshSourceGeometryData3D) -> AABB:
	if p_source_geometry.has_method("get_bounds"):
		# Godot 4.3 Patch added get_bounds() function that does the same but faster.
		return p_source_geometry.call("get_bounds")

	var bounds: AABB = AABB()
	var first_vertex: bool = true

	var vertices: PackedFloat32Array = p_source_geometry.get_vertices()
	var vertices_count: int = vertices.size() / 3
	for i in vertices_count:
		var vertex: Vector3 = Vector3(vertices[i * 3], vertices[i * 3 + 1], vertices[i * 3 + 2])
		if first_vertex:
			first_vertex = false
			bounds.position = vertex
		else:
			bounds = bounds.expand(vertex)

	for projected_obstruction: Dictionary in p_source_geometry.get_projected_obstructions():
		var projected_obstruction_vertices: PackedFloat32Array = projected_obstruction["vertices"]
		for i in projected_obstruction_vertices.size() / 3:
			var vertex: Vector3 = Vector3(projected_obstruction.vertices[i * 3], projected_obstruction.vertices[i * 3 + 1], projected_obstruction.vertices[i * 3 + 2]);
			if first_vertex:
				first_vertex = false
				bounds.position = vertex
			else:
				bounds = bounds.expand(vertex)

	return bounds


# func _process(_delta: float) -> void:
	# var mouse_cursor_position: Vector2 = get_viewport().get_mouse_position()

	# var map: RID = get_world_3d().navigation_map
	# # Do not query when the map has never synchronized and is empty.
	# if NavigationServer3D.map_get_iteration_id(map) == 0:
	# 	return

	# var camera: Camera3D = get_viewport().get_camera_3d()
	# var camera_ray_length: float = 1000.0
	# var camera_ray_start: Vector3 = camera.project_ray_origin(mouse_cursor_position)
	# var camera_ray_end: Vector3 = camera_ray_start + camera.project_ray_normal(mouse_cursor_position) * camera_ray_length
	# var closest_point_on_navmesh: Vector3 = NavigationServer3D.map_get_closest_point_to_segment(
	# 	map,
	# 	camera_ray_start,
	# 	camera_ray_end
	# )

	# if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
	# 	path_start_position = closest_point_on_navmesh

	# %DebugPaths.global_position = path_start_position

	# %PathDebugCorridorFunnel.target_position = closest_point_on_navmesh
	# %PathDebugEdgeCentered.target_position = closest_point_on_navmesh

	# %PathDebugCorridorFunnel.get_next_path_position()
	# %PathDebugEdgeCentered.get_next_path_position()

func _physics_process(delta: float) -> void:
	_player_process(delta, player, playerNavAgent)
	_player_process(delta, player2, playerNavAgent2)

	# if monoNavAgent.is_navigation_finished():
	# 	var currentIndex = checkpoints.find(monoCurrentCheckpoint)
	# 	var next = wrap(currentIndex + 1, 0, 3)
	# 	monoCurrentCheckpoint = checkpoints[next]
	# 	monoNavAgent.set_target_position(monoCurrentCheckpoint.global_position)
	# 	return
	

	#var next_position := monoNavAgent.get_next_path_position()
	# get the steering based on whether the next waypoint is to the left or right (the dot product ?)
	# then apply engine force forward or back 
	# if we are going to hit an obsticle we need to 
	# either slow down and avoid 
	# or back away if stopped (or almost stopped)

	#mono.steering = move_toward(mono.steering, next_position, 3.0 * delta)
	# var offset := next_position - mono.global_position
	# mono.global_position = mono.global_position.move_toward(next_position, delta * character_speed)

	# # Make the robot look at the direction we're traveling.
	# # Clamp Y to 0 so the robot only looks left and right, not up/down.
	# offset.y = 0
	# if not offset.is_zero_approx():
	# 	mono.look_at(mono.global_position + offset, Vector3.UP)
# 	set_interest()
# 	set_danger()
# 	choose_direction()
# 	var desired_velocity = chosen_dir.rotated(rotation) * max_speed
# 	velocity = velocity.linear_interpolate(desired_velocity, steer_force)
# 	rotation = velocity.angle()
# 	move_and_collide(velocity * delta)
	
	

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

func _player_process(delta: float, p: Node3D, navAgent: NavigationAgent3D) -> void: 
	if navAgent.is_navigation_finished():
		var currentIndex = checkpoints.find(currentCheckpoint)
		var next = wrap(currentIndex + 1, 0, 3)
		currentCheckpoint = checkpoints[next]
		navAgent.set_target_position(currentCheckpoint.global_position)
		return
	
	var next_position := navAgent.get_next_path_position()
	p.set_meta("next_position", next_position)
	var offset := next_position - p.global_position
	p.global_position = p.global_position.move_toward(next_position, delta * character_speed)
	# Make the robot look at the direction we're traveling.
	# Clamp Y to 0 so the robot only looks left and right, not up/down.
	offset.y = 0
	if not offset.is_zero_approx():
		p.look_at(p.global_position + offset, Vector3.UP)
