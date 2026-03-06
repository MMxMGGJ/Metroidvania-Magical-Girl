class_name PlayerCharacterStateIdleRun
extends PlayerCharacterState


func _ready():
	initialize()


func initialize():
	pass


# implement
func get_state_name() -> StringName:
	return &"IdleRun"


# implement
func get_base_animation() -> StringName:
	if abs(character.velocity.x) > 0:
		return &"Run"
	else:
		return &"Idle"


# override
func get_tags() -> Array[StringName]:
	return [&"CanJump", &"CanMeleeAttack"]


# override
func get_attribute_modifiers() -> Array[AttributeModifier]:
	return []


# override
func on_enter():
	pass


# implement
func on_physics_process(delta: float):
	character.change_direction_to_match_move_x_intention()
	character.move_grounded_free(delta)

	if not character.is_on_floor():
		character.set_next_state_by_name(&"Fall")


# override
func on_exit():
	pass
