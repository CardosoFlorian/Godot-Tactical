extends Node2D
## Simple procedural selection indicator so no extra art asset is needed.

@export var radius: float = 14.0
@export var ring_color: Color = Color(1.0, 0.95, 0.3, 0.9)

func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, ring_color, 2.0)
