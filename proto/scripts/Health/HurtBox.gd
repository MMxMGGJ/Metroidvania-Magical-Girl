# Copied from Godot 4 Platformer by komehara

class_name HurtBox
extends Area2D
## Hurt Box
## It is just for detection and refers to owner BaseCharacter, which can in return point to Health


## Owning character
@export var character: BaseCharacter


func _ready():
	DebugUtils.assert_member_is_set(self, character, "character")
