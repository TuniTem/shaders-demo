extends Control

func _process(delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	#print(DisplayServer.window_get_size())
	draw_circle(size *0.5, 1, Color(1.0, 1.0, 1.0, 0.3), true, -1.0, true)
