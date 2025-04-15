extends CanvasLayer

const DebugDraw3D := preload("res://debug_draw_3d.gd")

@onready var draw: DebugDraw3D

func _ready():
	draw = $DebugDraw3D
	if not InputMap.has_action("toggle_debug"):
		InputMap.add_action("toggle_debug")
		var ev = InputEventKey.new()
		ev.keycode = KEY_BACKSLASH
		InputMap.action_add_event("toggle_debug", ev)

func _input(event):
	if event.is_action_pressed("toggle_debug"):
		for n in get_children():
			n.visible = not n.visible
