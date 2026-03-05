class_name PlayerCharacterStateIdle
extends PlayerCharacterState


func _ready():
	initialize()


func initialize():
	pass


# implement
func get_state_name() -> StringName:
	return &"Idle"


# implement
func get_base_animation() -> StringName:
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
	# Most of the time, character stands without moving, but due to speed momentum of last state
	# it may actually be moving or even airborne so we need to update its position or even
	# enter Fall state
	character.move_grounded_or_airborne_free(delta)


# override
func on_exit():
	pass
