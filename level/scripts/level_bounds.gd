@tool
@icon("res://general/icons/level_bounds.svg")
class_name LevelBounds
extends Node2D

@export_range(2496, 2688 * 3, 96, "or_greater", "suffix:px") var width: int = 2688:
	set = _on_width_changed
@export_range(1440, 1440 * 3, 96, "or_greater", "suffix:px") var height: int = 1440:
	set = _on_height_changed

func _ready() -> void:
	# Show above everything else
	z_index = 256

	if Engine.is_editor_hint():
		return

	# Check for and get reference to our camera
	var camera: Camera2D = null

	# Kinda ugly but safer in case it takes a few frames to
	# load the full level with camera
	while not camera:
		await get_tree().process_frame
		camera = get_viewport().get_camera_2d()

	# Update camera's limits
	camera.limit_left = floori(global_position.x)
	camera.limit_top = floori(global_position.y)
	camera.limit_right = floori(global_position.x) + width
	camera.limit_bottom = floori(global_position.y) + height

func _draw() -> void:
	if Engine.is_editor_hint():
		# draw a box
		var r := Rect2(Vector2.ZERO, Vector2(width, height))
		draw_rect(r, Color(0.0, 0.45, 1.0, 0.6), false, 24.0)
		draw_rect(r, Color(0.0, 0.75, 1.0), false, 8.0)
	pass


func _on_width_changed(new_width: int) -> void:
	width = new_width
	queue_redraw()


func _on_height_changed(new_height: int) -> void:
	height = new_height
	queue_redraw()
