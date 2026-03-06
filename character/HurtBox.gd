class_name HurtBox
extends Area2D
## Hurt Box
## It is just for detection and refers to owner CharacterBase, which can in return point to Health


## Owning character
@export var character: CharacterBase


func _ready():
	DebugUtils.assert_member_is_set(self, character, "character")
