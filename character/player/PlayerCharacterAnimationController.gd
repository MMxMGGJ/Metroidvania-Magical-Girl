class_name PlayerCharacterAnimationController
extends AnimationControllerBase
## Base class for animation controller for player character (PlayerCharacterBase children)


## Owner
@export var character: PlayerCharacterBase


# override
func initialize():
	super.initialize()

	DebugUtils.assert_member_is_set(self, character, "character")


# implement
## Return base animation based on owner state
func _get_base_animation(_last_animation: StringName) -> StringName:
	if character.current_state:
		return character.current_state.get_base_animation()
	else:
		# Current state may be null for 1 frame on initialization,
		# in this case just default to Idle animation
		return &"Idle"
