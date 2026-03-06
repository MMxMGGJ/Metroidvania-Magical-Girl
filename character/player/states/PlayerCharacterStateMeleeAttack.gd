class_name PlayerCharacterStateMeleeAttack
extends PlayerCharacterState


@export_group("SFX")

## SFX to play on action start
@export var sfx: AudioStream


@export_group("Parameters")

## Duration (s) before player can cancel action with the same repeated
## or another one
@export var duration_before_can_cancel: float = 4/12.0

## Duration (s) of action (default is full animation duration)
@export var action_duration: float = 5/12.0

## Speed forward of action (0.0 for no root motion)
@export var character_move_speed: float = 0.0


## Timer to can cancel time
var can_cancel_timer: Timer

## Timer to end action
var action_timer: Timer


func _ready():
	initialize()


func initialize():
	DebugUtils.assert_member_is_set(self, sfx, "sfx")

	can_cancel_timer = TimerUtils.create_one_shot_physics_timer_under(
		self, duration_before_can_cancel, _on_can_cancel_timer_timeout)
	action_timer = TimerUtils.create_one_shot_physics_timer_under(
		self, action_duration, _on_action_timer_timeout)


# implement
func get_state_name() -> StringName:
	return &"MeleeAttack"


# implement
func get_base_animation() -> StringName:
	return &"MeleeAttack1"


# override
func get_tags() -> Array[StringName]:
	return []


# override
## Called on action start
func on_enter():
	var dir_sign := MathUtils.horizontal_direction_to_sign(character.direction)
	character.velocity.x = dir_sign * character_move_speed
	can_cancel_timer.start()
	action_timer.start()
	InGameManager.sfx_manager.spawn_sfx(sfx)


# implement
func on_physics_process(_delta: float):
	# Keep character_move_speed on X (set in on_enter), so don't call
	# update_velocity_grounded_free
	character.move_and_slide()


# override
## Called on action interrupt or completion
func on_exit():
	if can_cancel_timer.is_stopped():
		character.remove_active_tag(&"CanJump")
	else:
		can_cancel_timer.stop()

	if not action_timer.is_stopped():
		action_timer.stop()


func _on_can_cancel_timer_timeout():
	character.add_active_tag(&"CanJump")


func _on_action_timer_timeout():
	character.revert_to_default_contextual_state()
