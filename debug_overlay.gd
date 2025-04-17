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



func _on_restart_pressed() -> void:
	get_tree().get_root().get_child(0).queue_free()
	get_tree().get_root().add_child(load("res://navmesh_chhunks_demo_3d.tscn").instantiate())


func _on_pause_button_toggled(toggled_on:bool) -> void:
	get_tree().paused = toggled_on 

func _on_fps_value_changed(value: float) -> void:
	Engine.max_fps = clamp(value, 5, 60)
