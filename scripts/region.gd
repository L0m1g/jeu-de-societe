extends Node2D

@onready var polygon_2d: Polygon2D = $Area2D/Polygon2D

@export var border: bool = false

func _on_mouse_entered():
	polygon_2d.color = Color(1, 0, 0, 0.2)

func _on_mouse_exited():
	polygon_2d.color = Color(1, 0, 0, 0)
