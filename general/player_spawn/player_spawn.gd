@icon("res://general/icons/player_spawn.svg")
class_name PlayerSpawn
extends Node2D


@export var player_prefab: PackedScene


func _ready() -> void:
	visible = false

	await get_tree().process_frame

	# Check to see if we already have a player
	var player := get_tree().get_first_node_in_group(&"Player")

	# If we have a player, do nothing
	if player:
		return

	# Instantiate a new instance of player at spawn position
	NodeUtils.instantiate_under_at(player_prefab, get_tree().root, global_position)
