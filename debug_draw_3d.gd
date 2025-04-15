extends Control

var player
var camera

@export var width:= 1.0

func _draw():
    var color = Color(0, 1, 0)
    var start = camera.unproject_position(player.global_transform.origin)
    var end = camera.unproject_position(player.global_transform.origin + player.velocity)
    draw_line(start, end, color, width)
    draw_triangle(end, start.direction_to(end), width*2, color)

func draw_triangle(pos: Vector2, dir: Vector2, _size: float, color: Color):
    var a = pos + dir * _size
    var b = pos + dir.rotated(2*PI/3) * _size
    var c = pos + dir.rotated(4*PI/3) * _size
    var points = PackedVector2Array([a, b, c])
    draw_polygon(points, PackedColorArray([color]))