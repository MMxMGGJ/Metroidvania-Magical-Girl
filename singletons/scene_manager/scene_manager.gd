extends CanvasLayer

signal transition_scene_started
signal new_scene_ready(target_name: String, offset: Vector2)
signal transition_scene_finished
signal load_scene_finished

@onready var fade: Control = $Fade

func _ready() -> void:
	fade.visible = false


func transition_scene(new_scene: String, target_area: String, player_offset: Vector2, dir: String) -> void:
	get_tree().paused = true

	var fade_pos := get_fade_pos(dir)

	transition_scene_started.emit()

	# fade old scene out
	fade.visible = true
	await fade_screen(fade_pos, Vector2.ZERO)

	await get_tree().process_frame

	get_tree().change_scene_to_file(new_scene)

	await get_tree().scene_changed

	new_scene_ready.emit(target_area, player_offset)

	# fade new scene in
	await fade_screen(Vector2.ZERO, -fade_pos)
	fade.visible = false
	get_tree().paused = false

	transition_scene_finished.emit()
	load_scene_finished.emit()


func fade_screen(from: Vector2, to: Vector2) -> Signal:
	fade.position = from
	var tween := create_tween()
	tween.tween_property(fade, ^"position", to, 0.2)
	return tween.finished


func get_fade_pos(dir: String) -> Vector2:
	var pos := Vector2(2560 * 2, 1440 * 2)

	match dir:
		"left":
			pos *= Vector2(-1.0, 0.0)
		"right":
			pos *= Vector2(1.0, 0.0)
		"up":
			pos *= Vector2(0.0, -1.0)
		"down":
			pos *= Vector2(0.0, 1.0)

	return pos
