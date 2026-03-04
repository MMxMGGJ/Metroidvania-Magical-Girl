@icon("res://general/icons/player_spawn.svg")
class_name PlayerSpawn
extends Node2D


@export var player_prefab: PackedScene


func _ready() -> void:
	visible = false

	# Not really needed since if player comes from another scene, it's already here,
	# but safer
	await get_tree().process_frame

	# Check to see if we already have a player
	var player := get_tree().get_first_node_in_group(&"Player")

	if not player:
		# Instantiate a new instance of player at spawn position
		NodeUtils.instantiate_under_at(player_prefab, get_tree().root, global_position)
		# In-game start routine
		SceneManager.load_scene_finished.emit()
