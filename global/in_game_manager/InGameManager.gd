class_name InGameManagerClass
extends Node
## In-game manager singleton class
## Provides access to important level objects and debug input
##
## Usage:
## - define input for the following actions:
##     debug_damage_player_character
##     debug_damage_boss


@export var player_character_prefab: PackedScene


var room: Room
var player_character: PlayerCharacter


@onready var sfx_manager: SFXManager = $SFXManager
@onready var fx_manager: FXManager = $FXManager


func _ready():
	DebugUtils.assert_member_is_set(self, player_character_prefab, "player_character_prefab")

	SceneManager.transition_scene_started.connect(_on_transition_scene_started)


func _unhandled_input(event: InputEvent):
	# CHEAT INPUT
	if OS.has_feature("debug"):
		if event.is_action_pressed(&"debug_damage_player_character"):
			player_character.health.try_receive_damage(1, Enums.DamageType.NORMAL)
		elif event.is_action_pressed(&"debug_damage_boss"):
			var boss: Boss = get_tree().get_first_node_in_group("boss")
			if boss:
				boss.health.try_receive_damage(1, Enums.DamageType.NORMAL)


func spawn_player_character_and_start_ingame(spawn_position: Vector2):
		# Spawn player character at passed position
		player_character = NodeUtils.instantiate_under_at(player_character_prefab, get_tree().root, spawn_position)

		# TODO: play spawn animation

		# In-game start routine
		SceneManager.load_scene_finished.emit()


func _on_transition_scene_started():
	# Cleanup room immediately since SceneManager will soon unload current room scene
	room = null
