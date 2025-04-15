extends Control

func draw_triangle(pos, dir, _size = 1.0, color = Color(0, 1, 0)):
	var a = pos + dir * _size
	var b = pos + dir.rotated(2*PI/3) * _size
	var c = pos + dir.rotated(4*PI/3) * _size
	var points = PackedVector2Array([a, b, c])
	draw_polygon(points, PackedColorArray([color]))

var vectors = []  # Array to hold all registered values.

func _process(_delta):
	if not visible:
		return
	queue_redraw()

func _draw():
	var camera = get_viewport().get_camera_3d()
	for vector in vectors:
		vector.draw(self, camera)

func add_vector(object, property, _scale = 1.0, width = 1.0, color = Color(0, 1, 0)):
	vectors.append(Vector.new(object, property, _scale, width, color))

class Vector:
	var object: Variant # The node to follow
	var property: StringName  # The property to draw
	var scale:= 1.0  # Scale factor
	var width:= 1.0  # Line width
	var color: Color  # Draw color

	func _init(_object: Variant, _property: String, _scale = 1.0, _width = 1.0, _color = Color(0, 1, 0)):
		object = _object
		property = _property
		scale = _scale
		width = _width
		color = _color

	func draw(debugCanvas: Control, camera: Camera3D):
		if(object == null || object.global_transform == null):
			return
		var prop = object.get(property)
		if(prop == null): 
			prop = object.get_meta(property)
		if(prop != null):
			var start = camera.unproject_position(object.global_transform.origin)
			var end = camera.unproject_position(prop * scale)
			debugCanvas.draw_line(start, end, color, width)
			debugCanvas.draw_triangle(end, start.direction_to(end), width*2, color)
