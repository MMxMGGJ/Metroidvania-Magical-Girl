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
	return [&"CanStartAction"]


# override
func get_attribute_modifiers() -> Array[AttributeModifier]:
	return []


# override
func on_enter():
	pass


# implement
func on_physics_process(delta: float):
	if character.move_x_intention < 0:
		character.change_direction(MathEnums.HorizontalDirection.LEFT)
	elif character.move_x_intention > 0:
		character.change_direction(MathEnums.HorizontalDirection.RIGHT)

	character.move_grounded_free(delta)


# override
func on_exit():
	pass
