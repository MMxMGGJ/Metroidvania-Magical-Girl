# Note: PlayerCharacter and related classes were copied over from komehara's Super Sonic Heroes
# and adapted for this game, so there may be some code that doesn't look intuitive
# because it was made to support 3 different Sonic-style characters

class_name PlayerCharacter
extends CharacterBase
## Base class for player characters
##
## Debug input:
## - debug_toggle_player_character


@export_group("Debug")

## Flag to enable visual debug
@export var enable_debug: bool = false

## Color used for immediate debug text
@export var debug_color: Color = Color.WHITE


@export_group("Visual")

## (Optional) FX: Prefab of trail behind character during certain actions
@export var fx_trail_prefab: PackedScene

## Color to apply to FX trail modulate, on top of Gradient
## and self-modulate which already sets the global transparency
## This is a pure color and shouldn't include transparency,
## unless this is required for a specific color that works best
## with a stronger transparency
@export var fx_trail_color: Color = Color.WHITE

## Time (s) between invincibility blinks
## (note that invincibility_blink_duration can increase the total period)
@export var invincibility_blink_interval: float = 0.3

## Duration (s) of invincibility blink tween from and to alpha = 0
@export var invincibility_blink_alpha_transition_duration: float = 5./60.

## Duration (s) of invincibility blink itself (when alpha = 0)
@export var invincibility_blink_duration: float = 0.03


@export_group("Components")

@export var animation_controller: PlayerCharacterAnimationController

## Parent node of all Player Character States
@export var states_parent: Node


@export_group("Children")

@export var animated_sprite: AnimatedSprite2D
@export var move_box_shape: CollisionShape2D
@export var hurt_box: HurtBox


@export_group("Parameters")

## Max speed along X
@export var max_free_move_speed_x: float = 200.0

## For how long (s) is Player Character invincible after being hurt
## Note that timer starts immediately when hurt, not when Hurt state ends
@export var invincibility_duration_on_hurt: float = 2.0


@export_subgroup("Grounded")

## Base grounded acceleration (px/s) along X
## Base value for attribute "grounded_accel_x"
@export var base_grounded_accel_x: float = 400

## Grounded active deceleration along X
@export var grounded_active_decel_x: float = 1800

## Grounded passive deceleration aka friction along X
@export var grounded_passive_decel_x: float = 168.75


@export_subgroup("Airborne")

## Custom gravity
## Default value is the default physics 2D gravity
@export var gravity: float = 980.0

## Airborne acceleration (passive and active) along X
@export var airborne_accel_x: float = 337.5

## Air drag factor to apply every frame
## Formula is 1-(1/(0.125*256)), no scaling by 60 since still a factor per frame
@export var air_drag_factor_per_frame: float = 0.96875

## Multiply absolute speed by this factor to get rebound speed
## Note that velocity direction is always opposed, so velocity is multiplied
## by (-rebound_speed_abs_factor)
## According to SPG, Classic Sonic uses 0.5 on bosses
@export var rebound_speed_abs_factor: float = 0.5


# Parameters

## Dictionary of state name: StringName => state: PlayerCharacterState
var states_dict: Dictionary#<StringName, PlayerCharacterState>

## Base attributes dictionary
## Filled in initialize from @export variables
var base_attributes := {}


# State

## Flag to track when deferred setup is over so we can start to process safely
## (this is only to avoid processing in an invalid state during the first frame)
var is_setup: bool

## Current state
var current_state: PlayerCharacterState

## State to start on next frame, if any (null to keep same state as before)
var next_state: PlayerCharacterState

## Timer to track horizontal control lock, created on start
## It is only used for control lock when not hurt, since we check for Hurt state
## variants manually
var horizontal_control_lock_timer: Timer

## Timer to track Hurt state variants, created on start
var hurt_timer: Timer

## Timers to track invincibility, created on start
## This differs from hurt timer as character may regain control quickly (not Hurt
## anymore), yet preserve invincibility for longer as a compensation
var invincibility_timer: Timer

## Tween handling invincibility blink
var invincibility_blink_tween: Tween

## List of tags currently active on the character
## Tags are added by character states on start, and removed on finally
var active_tags: Array[StringName]

## List of attribute modifiers currently active on the character
## Attribute modifiers are added by character states on start, and removed on finally
var active_attribute_modifiers: Array[AttributeModifier]

## Current attributes dictionary
## Initialized with base_attributes and updated with Action attribute modifiers at runtime
var current_attributes := {}

## Current FX trail playing, if any
## Note that it is cleared as soon as we stop tracking self, but it may still be visible during
## its final fade out (oldest point smooth motion and clearance)
var current_fx_trail: Trail2D

## Move X intention (-1.0 to 1.0)
## Human control uses arcade ternary (-1, 0, +1)
## AI control allows intermediate values for fine control (slow down near target position)
var move_x_intention: float

## Move X intention (-1.0 to 1.0)
## Human control uses arcade ternary (-1, 0, +1)
## AI control allows intermediate values for fine control (slow down near target position)
var move_y_intention: float

## Jump intention: true iff character wants to start jumping this frame
var jump_intention: bool

## Hold jump intention: true iff character wants to keep jumping higher
var hold_jump_intention: bool

## Action 1 intention: true iff character wants to execute Action 1 this frame
var action1_intention: bool

## Hold action 1 intention: true iff character wants to keep executing Action 1 this frame
## (only relevant for actions that use held input)
var hold_action1_intention: bool

## Action 2 intention: true iff character wants to execute Action 2 this frame
var action2_intention: bool

## Hold action 2 intention: true iff character wants to keep executing Action 2 this frame
## (only relevant for actions that use held input)
var hold_action2_intention: bool


@onready var sfx_manager: SFXManager = InGameManager.sfx_manager
@onready var fx_manager: FXManager = get_tree().get_first_node_in_group(&"fx_manager")


func _ready():
	initialize()
	setup()


func initialize():
	is_setup = false

	DebugUtils.assert_member_is_set(self, animation_controller, "animation_controller")
	DebugUtils.assert_member_is_set(self, states_parent, "states_parent")
	DebugUtils.assert_member_is_set(self, animated_sprite, "animated_sprite")
	DebugUtils.assert_member_is_set(self, move_box_shape, "move_box_shape")
	DebugUtils.assert_member_is_set(self, hurt_box, "hurt_box")

	horizontal_control_lock_timer = TimerUtils.create_one_shot_physics_timer_under(self)
	hurt_timer = TimerUtils.create_one_shot_physics_timer_under(self, 1.0, _on_hurt_timer_timeout)
	invincibility_timer = TimerUtils.create_one_shot_physics_timer_under(self, invincibility_duration_on_hurt, _on_invincibility_timer_timeout)

	# Fill base_attributes from @export vars
	base_attributes[&"grounded_accel_x"] = base_grounded_accel_x

	# Character States
	for child in states_parent.get_children():
		var state := child as PlayerCharacterState
		if not state:
			push_error("[PlayerCharacter] child '%s' is under states_parent, yet not a PlayerCharacterState" % child.get_path())
			continue

		# Assign character to state and store in dict so it's accessible by its name identifier
		state.character = self
		states_dict[state.get_state_name()] = state


func setup():
	# Instead of setting the current state, set the next state to make sure that
	# State enter logic is applied to the initial state
	current_state = null
	next_state = null
	set_next_state_by_name(&"Idle")

	# Tags and attributes

	active_tags.clear()
	active_attribute_modifiers.clear()

	# Merge base attributes into current attributes with overwrite:
	# - on first deferred_setup, this will effectively copy base attributes
	# - on further deferred_setup calls, this will reset all current attributes
	current_attributes.merge(base_attributes, true)

	current_fx_trail = null

	on_setup()

	# Set flag only after complete setup, including child on_setup, has been done
	is_setup = true


# virtual
func on_setup():
	pass


func _unhandled_input(event: InputEvent):
	if OS.has_feature("debug"):
		if event.is_action_pressed(&"debug_toggle_player_character", false, true):
			get_viewport().set_input_as_handled()

			enable_debug = not enable_debug


func _process(delta: float) -> void:
	if OS.has_feature("debug") and enable_debug:
		DebugDraw2D.begin_text_group("-- %s --" % name, 0, debug_color, true, 50, 45)
		# show for only 1 frame to make sure it disappears immediately when disabling debug
		DebugDraw2D.set_text(" State", get_current_state_name(), 0, Color(0, 0, 0, 0), delta)


func _physics_process(delta: float):
	if not is_setup:
		return

	# AI: FSM pattern
	_check_next_state()

	_process_player_input()

	# Custom physics process, including starting character action on intention
	# TIMING NOTE: implementation calls change_state_by_name for maximum
	# reactivity. So current_state below may be affected by on_physics_process.
	on_physics_process(delta)

	if current_state != null:
		current_state.on_physics_process(delta)


## Return state with passed name
func get_state_by_name(state_name: StringName) -> PlayerCharacterState:
	var state = states_dict.get(state_name) as PlayerCharacterState

	if not state:
		push_error("[PlayerCharacter] %s: get_state_by_name: state_name '%s' is not in states_dict keys" %
			[name, state_name])

	return state


## Instantly change state by name and return new state
## If allow_restart is true, allow setting the same state as current state (it will be restarted)
## Else, do nothing else and warn if already in target state
func change_state_by_name(next_state_name: StringName, allow_restart: bool = false) -> PlayerCharacterState:
	var stored_next_state := set_next_state_by_name(next_state_name, allow_restart)

	# just in case next_state was already set, check stored_next_state
	# to make sure that this is the last call to set_next_state_by_name that set it
	if stored_next_state:
		_check_next_state()

	return stored_next_state


## Similar to change_state_by_name, but assume allow_restart = false and
## don't warn if trying to set the same state again, just do nothing
func try_change_state_by_name_without_restart(next_state_name: StringName):
	if get_current_state_name() == next_state_name:
		return

	change_state_by_name(next_state_name, false)


## Set the state to start on next frame by name and return that state
## If allow_restart is true, allow setting the same state as current state (it will be restarted on next frame)
## Else, do nothing else and warn if already in target state
## Setting next state multiple times in a row is not supported (you must wait for next frame to set next state again)
func set_next_state_by_name(next_state_name: StringName, allow_restart: bool = false) -> PlayerCharacterState:
	if next_state:
		if next_state_name == next_state.get_state_name():
			push_warning("%s: set_next_state_by_name('%s', %s): next_state is already '%s'. " %
					[name, next_state_name, allow_restart, next_state_name],
				"No need to set next state, just return the same state.")
			return next_state
		else:
			push_error("%s: set_next_state_by_name('%s', %s): next_state is already set to another state '%s'. " %
					[name, next_state_name, allow_restart, next_state.get_state_name()],
				"This may happen when simultaneously colliding with 2 hitboxes or jumping and getting hurt at the same time. ",
				"For safety, keep the last next state request (see issue #29 for fix proposals).")

	var found_next_state = states_dict.get(next_state_name) as PlayerCharacterState

	if not found_next_state:
		push_error("[PlayerCharacter] %s: set_next_state_by_name: next_state_name '%s' " %
				[name, next_state_name],
			"is not in states_dict keys. Return null.")
		return null

	if current_state == found_next_state and not allow_restart:
		push_warning("[PlayerCharacter] %s: set_next_state_by_name: character is already in state '%s' " %
				[name, next_state_name],
			"and allow_repeat_from_start is false. We won't restart the state, so return null.")
		return null

	next_state = found_next_state
	return found_next_state


## Similar to set_next_state_by_name, but assume allow_restart = false and
## don't warn if trying to set the same state again, just do nothing
func try_set_next_state_by_name_without_restart(next_state_name: StringName):
	if get_current_state_name() == next_state_name:
		return

	set_next_state_by_name(next_state_name, false)


## If next state is set, clear it and change state to that next state
func _check_next_state():
	if next_state != null:
		# Store and consume next value immediately so _change_state can safely
		# set the next state in case of immediate chained transition
		var stored_next_state = next_state
		next_state = null

		_change_state(stored_next_state)


## Change state behavior (can go from and to null)
func _change_state(new_state: PlayerCharacterState):
	if current_state:
		current_state.exit()
		remove_state_tags_and_attribute_modifiers(current_state)
		current_state.on_transition_to(new_state)

	var old_state := current_state
	current_state = new_state

	current_state.on_enter()
	add_state_tags_and_attribute_modifiers(current_state)

	if old_state == new_state:
		# We only allow transitioning to the same state when we explicitly want to restart
		# that state (calling set_next_state_by_name with allow_restart = true),
		# so replay animation from start
		var action_base_animation := current_state.get_base_animation()
		animation_controller.play_animation(action_base_animation)

	return current_state


# virtual
func on_physics_process(_delta: float):
	pass


## Return true iff taking player horizontal input into account for move intention X
## Note that this is to ignore horizontal input in states that would otherwise use it
## States that do not call _compute_next_grounded_speed_x/_compute_next_airborne_speed_x at all
## will ignore it anyway
func _can_control_horizontal_motion() -> bool:
	return horizontal_control_lock_timer.is_stopped()


## Process player input (called when character is leader)
func _process_player_input():
	if _can_control_horizontal_motion():
		# Apply ternary snapping (-1, 0, +1) for arcade controls even with analog stick
		move_x_intention = signf(Input.get_axis("move_left", "move_right"))
	else:
		# horizontal control is locked, do as if player was not using any
		# horizontal input
		move_x_intention = 0.0

	move_y_intention = signf(Input.get_axis("move_up", "move_down"))

	jump_intention = Input.is_action_just_pressed("jump", true)
	hold_jump_intention = Input.is_action_pressed("jump", true)

	action1_intention = Input.is_action_just_pressed("action1", true)
	hold_action1_intention = Input.is_action_pressed("action1", true)

	action2_intention = Input.is_action_just_pressed("action2", true)
	hold_action2_intention = Input.is_action_pressed("action2", true)


## Clear all intentions (useful for AI which may not set all intention vars)
func clear_intentions():
	move_x_intention = 0.0
	move_y_intention = 0.0

	jump_intention = false
	hold_jump_intention = false
	action1_intention = false
	hold_action1_intention = false
	action2_intention = false
	hold_action2_intention = false


## Change state to default based on current context (grounded or airborne)
## Use this after finalizing a State including special state (Hurt)
## to fall back to a meaningful state
func revert_to_default_contextual_state():
	if is_on_floor():
		try_set_next_state_by_name_without_restart(&"Idle")
	else:
		try_set_next_state_by_name_without_restart(&"Fall")


func add_active_tag(tag: StringName):
	var tag_index := active_tags.find(tag)
	if tag_index >= 0:
		push_warning("[PlayerCharacter] add_active_tag: tag '%s' is already active, " % tag,
			"but we will still add it (redundant tags are supported but not expected)")
		return

	active_tags.append(tag)


func remove_active_tag(tag: StringName):
	var tag_index := active_tags.find(tag)
	if tag_index < 0:
		push_warning("[PlayerCharacter] remove_active_tag: could not find tag '%s'" % tag)
		return

	# Note that an array is not the most performant data structure for set-like operations,
	# but it supports redundant tags without having to manually track tag count
	# Here, it will just erase the first tag it finds
	active_tags.remove_at(tag_index)


func try_remove_active_tag(tag: StringName):
	active_tags.erase(tag)


## Return current character state name if any, empty StringName else
func get_current_state_name() -> StringName:
	if current_state:
		return current_state.get_state_name()
	else:
		# Rare, but may happen on first frame during initialization
		return &""


## Add all tags and attribute modifiers associated to passed state
func add_state_tags_and_attribute_modifiers(state: PlayerCharacterState):
	add_state_active_tags(state)
	add_state_attribute_modifiers(state)


## Remove all tags and attribute modifiers associated to passed state
func remove_state_tags_and_attribute_modifiers(state: PlayerCharacterState):
	remove_state_active_tags(state)
	remove_state_attribute_modifiers(state)


func add_state_active_tags(state: PlayerCharacterState):
	active_tags.append_array(state.get_tags())


func remove_state_active_tags(state: PlayerCharacterState):
	for tag in state.get_tags():
		# Note that an array is not the most performant data structure for set-like operations,
		# but it supports redundant tags without having to manually track tag count
		# Here, it will just erase the first tag it finds
		active_tags.erase(tag)


func add_state_attribute_modifiers(state: PlayerCharacterState):
	add_attribute_modifiers(state.get_attribute_modifiers())


func add_attribute_modifiers(attribute_modifiers: Array[AttributeModifier]):
	active_attribute_modifiers.append_array(attribute_modifiers)

	# Update all dirty attributes
	# Note: this is suboptimal when character state contains multiple
	# attribute modifiers targeting the same attribute as only the final update
	# for this attribute will matter, but this is a rare case
	for attribute_modifier in attribute_modifiers:
		update_current_attribute(attribute_modifier.attribute_name)


func remove_state_attribute_modifiers(state: PlayerCharacterState):
	remove_character_attribute_modifiers(state.get_attribute_modifiers())


func remove_character_attribute_modifiers(attribute_modifiers: Array[AttributeModifier]):
	for attribute_modifier in attribute_modifiers:
		active_attribute_modifiers.erase(attribute_modifier)

	# Update all dirty attributes
	# Note: this is suboptimal in rare case, see add_attribute_modifiers
	for attribute_modifier in attribute_modifiers:
		update_current_attribute(attribute_modifier.attribute_name)


func update_current_attribute(attribute_name: StringName):
	var final_multiplier := 1.0
	for active_attribute_modifier in active_attribute_modifiers:
		final_multiplier *= active_attribute_modifier.multiplier

	current_attributes[attribute_name] = final_multiplier * base_attributes[attribute_name]


## Return true if character can jump
func _can_jump() -> bool:
	# Since character state can override move process, each of them can disable jump
	# by simply not calling check_jump. So we only need to check general state:
	# being grounded or not being hurt (which is a non-action state)
	return is_on_floor() and not is_hurt()


## Process horizontal move input and return next grounded speed along X
func _compute_next_grounded_speed_x(_delta: float) -> float:
	var next_grounded_speed_x

	if move_x_intention != 0.0:
		if velocity.x == 0.0 or sign(move_x_intention) == sign(velocity.x):
			# Accel (from 0 or keeping same direction)
			var grounded_accel_x: float = current_attributes[&"grounded_accel_x"]
			next_grounded_speed_x = velocity.x + move_x_intention * grounded_accel_x * _delta
		else:
			# Active decel
			next_grounded_speed_x = velocity.x + move_x_intention * grounded_active_decel_x * _delta
	else:
		# Passive decel (friction)
		next_grounded_speed_x = move_toward(velocity.x, 0.0, grounded_passive_decel_x * _delta)

	return clampf(next_grounded_speed_x, -max_free_move_speed_x, max_free_move_speed_x)


## Update velocity when grounded with free control
func update_velocity_grounded_free(delta: float):
	velocity.x = _compute_next_grounded_speed_x(delta)


## Move character when grounded with free control
func _move_grounded_free(delta: float):
	update_velocity_grounded_free(delta)
	check_jump()
	move_and_slide()


func check_jump():
	var should_jump := jump_intention and _can_jump()
	if should_jump:
		# Consume intention and jump
		jump_intention = false
		start_jump()


func start_jump():
	# Immediate?
	set_next_state_by_name(&"Jump")


## Process horizontal move input and return next airborne speed along X
func _compute_next_airborne_speed_x(_delta: float) -> float:
	# Accel
	var next_airborne_speed_x := velocity.x + move_x_intention * airborne_accel_x * _delta

	# Air drag
	next_airborne_speed_x *= air_drag_factor_per_frame

	return clampf(next_airborne_speed_x, -max_free_move_speed_x, max_free_move_speed_x)


## Update velocity when airborne with free control
func update_velocity_airborne_free(delta: float):
	# Apply speed on X
	velocity.x = _compute_next_airborne_speed_x(delta)

	apply_gravity(delta)


## Apply gravity to velocity Y over delta seconds
func apply_gravity(delta: float):
	# Apply gravity
	velocity.y = velocity.y + gravity * delta


## Apply gravity if character is airborne
func apply_gravity_if_grounded(delta: float):
	if not is_on_floor():
		apply_gravity(delta)


## Move character when airborne with free control
func _move_airborne_free(delta: float):
	update_velocity_airborne_free(delta)
	move_and_slide()


func move_grounded_or_airborne_free(delta: float):
	if is_on_floor():
		_move_grounded_free(delta)
	else:
		_move_airborne_free(delta)


func _can_be_hurt():
	return invincibility_timer.is_stopped()


## Enter some Hurt state variant for given duration,
## if this character can be hurt
func try_get_hurt(hurt_duration: float) -> bool:
	if _can_be_hurt():
		get_hurt(hurt_duration)
		return true
	else:
		return false


## Enter some Hurt state variant for given duration
## Often called with lock_horizontal_control(...)
func get_hurt(hurt_duration: float):
	set_next_state_by_name(&"Hurt")
	hurt_timer.start(hurt_duration)
	invincibility_timer.start()
	start_invincibility_blink_tween()


func start_invincibility_blink_tween():
	# Start invincibility blink tweening
	invincibility_blink_tween = create_tween()
	invincibility_blink_tween.tween_property(animated_sprite, "modulate:a", 0.0, invincibility_blink_alpha_transition_duration)
	invincibility_blink_tween.tween_interval(invincibility_blink_duration)
	invincibility_blink_tween.tween_property(animated_sprite, "modulate:a", 1.0, invincibility_blink_alpha_transition_duration)
	invincibility_blink_tween.tween_interval(invincibility_blink_interval)
	invincibility_blink_tween.set_loops()


func stop_invincibility_blink_tween():
	if invincibility_blink_tween:
		# Make sure to reset sprite state in case we were in the middle of the blink
		animated_sprite.modulate.a = 1.0
		invincibility_blink_tween.stop()
		invincibility_blink_tween = null
	else:
		push_error("[PlayerCharacter] stop_invincibility_blink_tween: invincibility_blink_tween is not set")


## Prevent horizontal control on this character for given duration
func lock_horizontal_control(horizontal_control_lock_duration: float):
	# For now it only works on leader = character controlled by player
	horizontal_control_lock_timer.start(horizontal_control_lock_duration)


## Return true iff character is in hurt state
func is_hurt() -> bool:
	return get_current_state_name() == &"Hurt"


## Return true iff character should not be hit by anything (going through colliders)
## It may still hit by other things, check ignore_hit_boxes
func ignore_hit_boxes() -> bool:
	return &"IgnoreHitBox" in active_tags


## Return true iff character should not hit anything (going through colliders)
## It may still be hit by other things, check ignore_hurt_boxes
func ignore_hurt_boxes() -> bool:
	return &"IgnoreHurtBox" in active_tags


func spawn_fx_trail_and_start_tracking_self():
	# We don't support multiple trails at once (we only keep reference to last
	# so we'd be unable to stop the older ones), so if already trailing, stop previous one
	# for safety
	if current_fx_trail:
		push_warning("[PlayerCharacter] spawn_fx_trail_and_start_tracking_self: has already ",
			"current FX trail, stopping it for safety")
		current_fx_trail.stop_tracking_target()
		# clear ref in case we return early below, otherwise optional since we're gonna
		# reassign more below
		current_fx_trail = null

	if not fx_trail_prefab:
		push_error("[PlayerCharacter] spawn_fx_trail_and_start_tracking_self: no fx_trail_prefab assigned")
		return

	# Trails automatically adjust their relative point positions
	# to their own position to track target, so their own position doesn't matter,
	# so just pass ZERO
	var fx_trail := fx_manager.spawn_fx(fx_trail_prefab, Vector2.ZERO) as Trail2D
	if not fx_trail:
		push_error("[PlayerCharacter] spawn_fx_trail_and_start_tracking_self: fx_trail is null, ",
			"fx_trail_prefab '%s' is not a Trail2D" % fx_trail_prefab.resource_path)
		return

	fx_trail.start_tracking_target(self)
	# self_modulate is already used to apply a global alpha transparency
	# on top of the gradient (which uses its own progressive alpha)
	# so we must either modify only the color, but not alpha,
	# of self_modulate, or simpler, set modulate instead (what we do here)
	fx_trail.modulate = fx_trail_color
	current_fx_trail = fx_trail


func stop_fx_trail_tracking_self():
	if not current_fx_trail:
		push_error("[PlayerCharacter] stop_fx_trail_tracking_self: current_fx_trail is null")

	current_fx_trail.stop_tracking_target()
	current_fx_trail = null


func _on_hurt_timer_timeout():
	revert_to_default_contextual_state()


func _on_invincibility_timer_timeout():
	stop_invincibility_blink_tween()
