@tool
extends Label3D

func _ready():
	set_text(get_parent().name)

func _process(_delta: float) -> void:
	set_text(get_parent().name)