class_name PlayerCharacterStateFall
extends PlayerCharacterState
## State in which character is simply falling, without possibility to extend jump height like Jump
## It is entered after running off a cliff, finishing some aerial actions,
## or getting hurt mid-air if Hurt timer finishes before landing.
## Some actions may be usable even in this state.


func _ready():
	initialize()


func initialize():
	pass


# implement
func get_state_name() -> StringName:
	return &"Fall"


# implement
func get_base_animation() -> StringName:
	return &"Fall"


# override
func get_tags() -> Array[StringName]:
	return []


# override
func get_attribute_modifiers() -> Array[AttributeModifier]:
	return []


# override
## Called on action start
func on_enter():
	# Fall doesn't set velocity and just keeps the one from last state
	pass


# implement
func on_physics_process(delta: float):
	character.update_velocity_airborne_free(delta)
	character.move_and_slide()

	if character.is_on_floor():
		# Landed
		character.set_next_state_by_name(&"IdleRun")

# override
func on_exit():
	pass
