@tool
@icon("res://general/icons/level_transition.svg")
class_name LevelTransition
extends Node2D

enum SIDE { LEFT, RIGHT, TOP, DOWN }

@export_range(2, 12, 1, "or_greater")
var size: int = 2:
	set(value):
		size = value
		apply_area_settings()

@export var location: SIDE = SIDE.LEFT:
	set(value):
		location = value
		apply_area_settings()

@export_file("*.tscn") var target_level_path: String = ""
var target_level: PackedScene
@export var target_area_name: String = "LevelTransition"

@onready var area_2d: Area2D = $Area2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	# Always initialize area at runtime
	# (since setter only works at edit time, and Editable Children is generally disabled so changes
	# on Area2D are not saved in the scene)
	apply_area_settings()

	SceneManager.new_scene_ready.connect(_on_new_scene_ready)
	SceneManager.load_scene_finished.connect(_on_load_scene_finished)


func apply_area_settings() -> void:
	if not area_2d:
		return

	if location == SIDE.LEFT or location == SIDE.RIGHT:
		area_2d.scale.y = size
		if location == SIDE.LEFT:
			# negative scale X usually causes troubles at runtime
			# but it works fine in @tool
			area_2d.scale.x = -1
		else:
			area_2d.scale.x = 1
	else:
		area_2d.scale.x = size
		if location == SIDE.TOP:
			area_2d.scale.y = 1
		else:
			area_2d.scale.y = -1


func get_offset(player_character: PlayerCharacter) -> Vector2:
	var offset := Vector2.ZERO
	var player_pos = player_character.global_position

	if location == SIDE.LEFT or location == SIDE.RIGHT:
		# Preserve relative height when crossing horizontal gate
		offset.y = player_pos.y - global_position.y

		if location == SIDE.LEFT:
			offset.x = -40.0
		else:
			offset.x = 40.0
	else:
		# Preserve relative X when crossing horizontal gate
		offset.x = player_pos.x - global_position.x

		if location == SIDE.TOP:
			# Origin is at character bottom so doesn't need a lot of offset
			offset.y = -10.0
		else:
			# On the opposite, here we need a lot of offset to cover distance head -> feet
			offset.y = 20.0

	return offset


func get_transition_direction() -> String:
	match location:
		SIDE.LEFT:
			return "left"
		SIDE.RIGHT:
			return "right"
		SIDE.TOP:
			return "up"
		_:
			return "down"


func _on_new_scene_ready(target_name: String, offset: Vector2) -> void:
	# Position player
	if target_name == name:
		# This is the area where the player is respawning
		var player := get_tree().get_first_node_in_group(&"Player") as Node2D
		player.global_position = global_position + offset

func _on_load_scene_finished() -> void:
	# Delay level transition trigger activation until scene is fully loaded
	# to avoid player character accidentally chain-triggering level transitions
	# if spawning at the wrong place

	# Note: We must wait 2 frames before connecting signal because Area2D adds an extra frame of
	# delay in processing that the Player Character is gone, as explained in Metroidvania tutorial
	# Note: unlike Metroidvania tutorial, we await *before* connect, in counterpart, no need to
	# temporarily disable area_2d.monitoring
	await get_tree().physics_frame
	await get_tree().physics_frame
	area_2d.body_entered.connect(_on_area_2d_body_entered)

func _on_area_2d_body_entered(body: Node2D) -> void:
	# in principle, we should check that body is really Player
	var player_character := body as PlayerCharacter
	if player_character:
		SceneManager.transition_scene(target_level_path, target_area_name, get_offset(player_character), get_transition_direction())
