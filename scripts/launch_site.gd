class_name LaunchSite
extends Node2D
# Sky, water surface and the boat ramp. Grey boxes until the sprite pass in milestone 5.


func _draw() -> void:
	draw_rect(Rect2(-8000, -6000, 400000, 6000), Color(0.55, 0.78, 0.9))            # sky
	draw_rect(Rect2(-8000, 0, 400000, 6), Color(0.85, 0.95, 1.0))                    # surface line
	var hull := PackedVector2Array([Vector2(-700, -170), Vector2(-60, -170), Vector2(-20, 0), Vector2(-640, 0)])
	draw_colored_polygon(hull, Color(0.8, 0.8, 0.85))                                 # Boat 07
	draw_line(Balance.RAMP_START + Vector2(-20, 16), Balance.RAMP_END + Vector2(0, 16), Color(0.35, 0.3, 0.3), 12.0)
	draw_line(Balance.RAMP_END + Vector2(0, 16), Balance.RAMP_END + Vector2(-60, 190), Color(0.35, 0.3, 0.3), 8.0)
