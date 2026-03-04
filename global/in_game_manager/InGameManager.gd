class_name InGameManagerClass
extends Node
## In-game manager singleton class
## Provides access to important level objects and debug input
##
## Usage:
## - define input for the following actions:
##     debug_damage_player_character
##     debug_damage_boss


var player_character: PlayerCharacter


@onready var sfx_manager: SFXManager = $SFXManager


func _ready():
	pass


func _unhandled_input(event: InputEvent):
	# CHEAT INPUT
	if OS.has_feature("debug"):
		if event.is_action_pressed(&"debug_damage_player_character"):
			player_character.health.try_receive_damage(1, Enums.DamageType.NORMAL)
		elif event.is_action_pressed(&"debug_damage_boss"):
			var boss: Boss = get_tree().get_first_node_in_group("boss")
			if boss:
				boss.health.try_receive_damage(1, Enums.DamageType.NORMAL)
