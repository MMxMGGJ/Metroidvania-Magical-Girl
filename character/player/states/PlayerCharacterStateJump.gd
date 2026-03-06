class_name PlayerCharacterStateJump
extends PlayerCharacterState


@export_group("SFX")

## SFX: Jump
@export var sfx: AudioStream


func _ready():
	initialize()


func initialize():
	DebugUtils.assert_member_is_set(self, sfx, "sfx")


# implement
func get_state_name() -> StringName:
	return &"Jump"


# implement
## Return base animation to play while this action is running
## Note that since Hero Actions have their own start/interrupt/complete system,
## using this with base animation supersedes the override animation system,
## which is not needed for Hero Actions
func get_base_animation() -> StringName:
	return &"Jump"


# override
## Return the list of tags that are activated while this action is running
func get_tags() -> Array[StringName]:
	return []


# override
## Return the list of attribute modifiers that are activated while this action is running
func get_attribute_modifiers() -> Array[AttributeModifier]:
	return []


# override
## Called on action start
func on_enter():
	# Apply upward velocity
	character.velocity.y = -character.jump_speed

	InGameManager.sfx_manager.spawn_sfx(sfx)


# implement
func on_physics_process(delta: float):
	character.update_velocity_airborne_free(delta)

	# Check hold jump
	var signed_jump_interrupt_speed = -character.jump_interrupt_speed
	if not character.hold_jump_intention and character.velocity.y < signed_jump_interrupt_speed:
		# Interrupt jump
		character.velocity.y = signed_jump_interrupt_speed

	character.move_and_slide()

	if character.is_on_floor():
		# Landed
		character.set_next_state_by_name(&"IdleRun")


# override
func on_exit():
	pass
