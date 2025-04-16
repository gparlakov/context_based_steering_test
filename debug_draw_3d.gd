extends Control

@onready var propsContainer = $PropsContainer/VBoxContainer

func draw_triangle(pos, dir, _size = 1.0, color = Color(0, 1, 0)):
	var a = pos + dir * _size
	var b = pos + dir.rotated(2*PI/3) * _size
	var c = pos + dir.rotated(4*PI/3) * _size
	var points = PackedVector2Array([a, b, c])
	draw_polygon(points, PackedColorArray([color]))

var vectors = []  # Array to hold all registered values.
var props = []  # An array of the tracked properties.

func _process(_delta):
	if not visible:
		return
	queue_redraw()
	
	for prop in props:
		prop.set_label()

func _draw():
	var camera = get_viewport().get_camera_3d()
	for vector in vectors:
		vector.draw(self, camera)

func add_vector(object, property, _scale = 1.0, width = 1.0, color = Color(0, 1, 0)):
	vectors.append(Vector.new(object, property, _scale, width, color))

## test this Property [br]
## 
## [param display] can be one of "", "length", "round" or a Callable that returns the value already formatted
func add_property(object, property, display = ""):
	var label = Label.new()
	# label.set("custom_fonts/font", load("res://debug/roboto_16.tres"))
	propsContainer.add_child(label)
	props.append(Property.new(object, property, label, display))

func remove_property(object, property):
	for prop in props:
		if prop.object == object and prop.property == property:
			props.erase(prop)
class Vector:
	var object: Variant # The node to follow
	var property: Callable  # The property to draw
	var scale:= 1.0  # Scale factor
	var width:= 1.0  # Line width
	var color: Color  # Draw color

	func _init(_object: Variant, _property: Callable, _scale = 1.0, _width = 1.0, _color = Color(0, 1, 0)):
		object = _object
		property = _property
		scale = _scale
		width = _width
		color = _color

	func draw(debugCanvas: Control, camera: Camera3D):
		if(object == null || object.global_transform == null || property == null):
			return
		var prop = property.call()
		
		if(prop != null):
			var start = camera.unproject_position(object.global_transform.origin)
			var end = camera.unproject_position(object.global_transform.origin + prop * scale)
			debugCanvas.draw_line(start, end, color, width)
			debugCanvas.draw_triangle(end, start.direction_to(end), width*2, color)


enum DebugPropDisplay {
	Plain,
	Length,
	Round
}
	

## 
## Create a property that will fill the [param _label] with the text of [param _object.name] [param _property]: object.property (or display is Callable => ([param display] as Callable).call()) [br]
## @tutorial: https://example.com/tutorial 
class Property:

	var num_format = "%4.2f"
	var object  # The object being tracked.
	var property  # The property to display (NodePath).
	var label_ref  # A reference to the Label.
	var display  # Display option (rounded, etc. or Callable)


	
	func _init(_object, _property, _label, _display):
		object = _object
		property = _property
		label_ref = _label
		display = _display

	func set_label():
		# Sets the label's text.
		var s = object.name + "/" + property + " : "
		var p = object.get_indexed(property)
		match typeof(display):
			TYPE_STRING: 
				match display:
					"":
						s += str(p)
					"length":
						s += num_format % p.length()
					"round":
						match typeof(p):
							TYPE_INT, TYPE_FLOAT:
								s += num_format % p
							TYPE_VECTOR2, TYPE_VECTOR3:
								s += str(p.round())
			TYPE_CALLABLE:
				s += (display as Callable).call()
		label_ref.text = s

