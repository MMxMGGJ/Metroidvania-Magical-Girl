@icon("res://general/icons/player_spawn.svg")
class_name PlayerSpawn
extends Node2D


@export var player_prefab: PackedScene


func _ready() -> void:
	DebugUtils.assert_member_is_set(self, player_prefab, "player_prefab")

	visible = false

	# Not really needed since if player comes from another scene, it's already here,
	# but safer
	await get_tree().process_frame

	# Check to see if we already have a player
	var player := get_tree().get_first_node_in_group(&"Player")

	if not player:
		InGameManager.spawn_player_character_and_start_ingame(global_position)
