# Copied and simplified from Godot 4 Platformer by komehara
class_name PlayerCharacter

extends GroundedCharacter


## Timer used to buffer attack input, can set attack_intention with some delay if needed
## It is consumed at the same time as the attack intention
@export var attack_input_buffer_timer: Timer

## Stick vertical axis input threshold to recognize intention to attack upward
## or downward in the air
@export var air_attack_vertical_input_threshold: float = 1.0 / sqrt(2.0)

## Current control mode
var control_mode: Enums.ControlMode


func initialize():
	# Debug: Brutal code to delete any redundant player character nodes placed in the various
	# level scenes for testing, when the "true" player is coming from another scene
	if get_tree().get_first_node_in_group(&"Player") != self:
		queue_free()

	super.initialize()

	DebugUtils.assert_member_is_set(self, attack_input_buffer_timer, "attack_input_buffer_timer")

	# Always attach Player character to root so it's never deleted by scene change
	reparent.call_deferred(get_tree().root)


func setup():
	super.setup()

	control_mode = Enums.ControlMode.PLAYER_INPUT


func on_physics_process(delta: float):
	# Centralize update here, so we can delegate checks and actions to each
	# component in a controlled order

	# Usually input is processed in _process, but because of timer things
	# we exceptionally do it in _physics_process (ideally we'd just process the input
	# part in _process, store some flags, and start the timer on _physics_process
	# for exact timing)
	# We could also check one-time input (jump, attack) in _unhandled_input
	_update_move_intention()

	if is_on_floor():
		_move_grounded(delta)
	else:
		_move_airborne(delta)

	if _can_start_attack() and _consume_attack_intention():
		# Consume attack input buffer too, so it is not reused next frame
		attack_input_buffer_timer.stop()
		if is_sliding():
			# Only allow Dash Attack if speed curve is defined
			if dash_attack_speed_curve:
				melee_attack.start_dash_attack()
		elif is_on_floor():
			if vertical_move_intention <= -air_attack_vertical_input_threshold:
				melee_attack.start_attack(&"Upward")
			else:
				melee_attack.start_attack(&"Forward")
		else:
			var air_attack_direction_string_name: StringName
			if vertical_move_intention <= -air_attack_vertical_input_threshold:
				air_attack_direction_string_name = &"Upward"
			elif vertical_move_intention < air_attack_vertical_input_threshold:
				air_attack_direction_string_name = &"Forward"
			else:
				air_attack_direction_string_name = &"Downward"

			melee_attack.start_air_attack(air_attack_direction_string_name)


func _update_move_intention():
	if control_mode == Enums.ControlMode.PLAYER_INPUT:
		horizontal_move_intention = _get_horizontal_move_input_value()
		vertical_move_intention = _get_vertical_move_input_value()
		jump_intention = _get_jump_input()
		hold_jump_intention = _get_hold_jump_input()
		slide_intention = _get_slide_input()

		# Attack intention uses buffer system

		# 1. Start buffer on input press
		if _get_attack_input():
			attack_input_buffer_timer.start()

		# 2. Whether pressed this frame or earlier, if buffer is still active,
		#    recognize attack intention
		#    Note that even if player doesn't keep holding the attack input this frame,
		#    it will be recognized
		attack_intention = not attack_input_buffer_timer.is_stopped()

	# else, control mode is SIMULATION
	# do nothing in this case, so we can use the values set directly in managing code
	# move intention values are sticky while one-time action intention values are consumed


## Return the horizontal move input direction
## Value can be -1 (left), 0 or 1 (right)
func _get_horizontal_move_input_value() -> float:
	return Input.get_axis(&"move_left", &"move_right")


## Return the vertical move input direction
## Value can be -1 (up), 0 or 1 (down)
func _get_vertical_move_input_value() -> float:
	return Input.get_axis(&"move_up", &"move_down")


## Return true if player pressed jump input
func _get_jump_input() -> bool:
	return Input.is_action_just_pressed(&"jump")


## Return true if player is holding jump input
func _get_hold_jump_input() -> bool:
	return Input.is_action_pressed(&"jump")


## Return true if player pressed slide input
func _get_slide_input() -> bool:
	return Input.is_action_just_pressed(&"slide")


## Return true if player pressed attack input
func _get_attack_input() -> bool:
	return Input.is_action_just_pressed(&"attack")
