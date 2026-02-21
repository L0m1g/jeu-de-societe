extends Area2D

@onready var polygon_2d: Polygon2D = $Polygon2D

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	polygon_2d.color = Color(0, 1, 0, 0.1)

func _on_mouse_exited():
	polygon_2d.color = Color(0, 1, 0, 0)
