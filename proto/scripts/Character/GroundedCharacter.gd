# Copied and simplified from Godot 4 Platformer by komehara

class_name GroundedCharacter
extends BaseCharacter


# Layer number between 1 and 32
const ONE_WAY_PLATFORM_LAYER_NUMBER := 2


@export_group("Assets")

# Removed SFX


@export_group("Children")

@export var one_way_platform_raycast: RayCast2D
@export var body_collision_shape_standing: CollisionShape2D
@export var body_collision_shape_crouching: CollisionShape2D
@export var hurt_box_collision_shape_standing: CollisionShape2D
@export var hurt_box_collision_shape_crouching: CollisionShape2D


@export_group("Parameters")

## Max ground speed (px/s)
@export var max_horizontal_speed: float = 75.0

## Time (s) needed to decelerate completely from max_horizontal_speed to 0 after horizontal input release
@export var deceleration_time: float = 0.05

## Dash Attack constant speed (px/s) curve
@export var dash_attack_speed_curve: Curve

## Iff true, Dash Attack is cancelled when landing
@export var cancel_dash_attack_on_landing: bool = false

## Slide constant speed (px/s) when done from ground
@export var ground_slide_speed: float = 100.0

## Max horizontal speed overwrite during Air Slide (px/s)
## Acceleration X is immediate as usual, but deceleration may apply and character can even
## stop and move to the opposite direction during Air Slide, so it's not a constant speed
@export var air_slide_speed: float = 100.0

## Custom gravity
@export var gravity: float = 700.0

## Custom reduced gravity during wall slide, only when moving down
@export var gravity_during_wall_slide_downward: float = 300.0

## Max fall speed (px/s) (default is same as jump speed so it doesn't affect
## a full jump, but starts slowing down character if it jumps from a higher to
## a lower ground)
@export var max_fall_speed: float = 220

## Max fall speed (px/s) during wall slide
@export var max_fall_speed_during_wall_slide: float = 75.0

## Initial jump speed
@export var jump_speed: float = 220.0

## Initial wall jump vertical speed
@export var wall_jump_vertical_speed: float = 160.0

## Duration (s) to lock horizontal motion control after wall jump, to make sure
## character goes far enough from it before coming back
@export var wall_jump_locked_motion_duration: float = 0.1

## Velocity Y is set to the opposite of this value when character interrupts jump
## (for player character, it is done on jump input release)
## This is also the hop (smallest jump) speed.
## Must be less than jump_speed (the smaller, the faster the jump interruption)
@export var jump_interrupt_speed: float = 100.0

## Initial jump down one-way platform speed
## Must be >= 60px/s to move by at least 1 px in 1 frame
@export var jump_down_one_way_platform_speed: float = 100.0

## Maximum distance to snap down back to ground while walking across slopes or
## steps. This should be a bit more than the maximum expected vertical distance
## to ground after 1 frame stepping off from one flat ground/slope to a more
## descending slope. The higher max_horizontal_speed and the higher the max slope
## angle tolerated for snapping down, the higher this value must be.
## For instance, if you need to snap down when moving from flat ground to some
## slope angle, then the value must be at least:
## max_horizontal_speed * tan(slope angle) * delta
@export var ground_snap_down_distance: float = 2.0

## If true, character can attack mid-air
@export var can_attack_when_airborne: bool = true

## Duration (s) of Slide from ground
## Value should be at least the Slide animation duration to avoid interrupting
## animation before the end
@export var ground_slide_duration: float = 0.2

## Duration (s) of Slide mid-air
## Value should be at least the AirSlide animation duration to avoid interrupting
## animation before the end
@export var air_slide_duration: float = 0.5


## True iff character wants to jump this frame
## Consumed during simulation
var jump_intention: bool

## True iff character wants to hold jump this frame
## Sticky during simulation
var hold_jump_intention: bool

## True iff character wants to slide this frame
## Consumed during simulation
var slide_intention: bool

## True if character is actively trying to move horizontally, and they can
## This is true even if they are blocked by a wall.
## Used by CharacterAnim
var wants_to_and_can_freely_move_horizontally: bool

## True if character has jumped since last time it was grounded
## It may be moving up or down.
var has_jumped: bool

## True if character has already canceled their jump during this jump
var has_canceled_jump: bool

## True if character is crouching
var is_crouching: bool

## True if character is sliding on wall
var is_wall_sliding: bool

## True if character is sliding on ground, OR started sliding on ground
## and fell off a cliff but is still finishing the slide animation
var is_ground_sliding: bool

## True if character has started sliding mid-air and is still doing so
var is_air_sliding: bool

## Current floor tangent in the right direction
## When grounded, this is orthogonal to the floor normal, rotated by 90 degrees clockwise
## When airborne, this is irrelevant, and set to Vector2.ZERO to avoid unwanted usage
## Note that even when the character spawn on/inside floor, it is considered airborne for about 2
## frames, but since it is generally spawned on flat floor, and both moving on flat floor and in
## the air moves horizontally, this should not be perceptible.
var _current_floor_tangent_right: Vector2

## Current signed speed along floor tangent right
## When grounded, this is positive when moving right, negative when moving left
## When airborne, this is irrelevant, and set to 0 to avoid unwanted usage
var _current_signed_ground_speed: float

## Timer for Wall Jump action to lock motion temporarily (created on _ready)
var wall_jump_locked_motion_timer: Timer

## Timer for Slide action (created on _ready)
var slide_timer: Timer

## Cached Dash Attack animation duration
var dash_attack_animation_duration: float


func initialize():
	assert(one_way_platform_raycast, "one_way_platform_raycast is not set on %s" % get_path())
	assert(body_collision_shape_standing, "body_collision_shape_standing is not set on %s" % get_path())
	assert(hurt_box_collision_shape_standing, "hurt_box_collision_shape_standing is not set on %s" % get_path())

	super.initialize()

	# Don't set wait_time yet, as it depends on grounded vs airborne state, so keep default 1.0
	slide_timer = TimerUtils.create_one_shot_physics_timer_under(self, 1.0, _on_slide_timer_timeout)
	wall_jump_locked_motion_timer = TimerUtils.create_one_shot_physics_timer_under(self, wall_jump_locked_motion_duration)

	# Prepare/cache Dash Attack parameters, if character is using Dash
	if dash_attack_speed_curve:
		dash_attack_speed_curve.bake()

		var animation_player := animation_controller.animation_player
		var dash_attack_animation := animation_player.get_animation(&"DashAttack")
		dash_attack_animation_duration = dash_attack_animation.length


func setup():
	super.setup()

	jump_intention = false
	hold_jump_intention = false
	slide_intention = false

	wants_to_and_can_freely_move_horizontally = false
	has_jumped = false
	has_canceled_jump = false
	is_crouching = false
	is_wall_sliding = false
	is_ground_sliding = false
	is_air_sliding = false

	_current_floor_tangent_right = Vector2.ZERO
	_current_signed_ground_speed = 0.0

	_update_body_collision_shape()


## If character wants to jump this frame, return true and consume the intention flag
## Else, return false
func _consume_jump_intention() -> bool:
	if jump_intention:
		jump_intention = false
		return true
	else:
		return false


## If character wants to slide this frame, return true and consume the intention flag
## Else, return false
func _consume_slide_intention() -> bool:
	if slide_intention:
		slide_intention = false
		return true
	else:
		return false


## Return true if character can change horizontal direction
## Note that we check _can_freely_move_horizontally before, so we don't need
## to put all the redundant conditions here
func _can_change_direction() -> bool:
	return super._can_change_direction() and not is_crouching and not is_ground_sliding


func _can_freely_move_horizontally() -> bool:
	if is_on_floor():
		# when grounded, hurt, death and attack prevent move
		# ground slide forces horizontal motion and uses a different code branch,
		# so it doesn't matter but to be semantically correct, we check it too
		# same for wall jump lock timer
		return not health.is_hurting and not health.is_dead() \
			and melee_attack.can_freely_move_horizontally() and not is_crouching and not is_ground_sliding
	else:
		# when airborne, hurt and death prevent move, but you can still move during an attack
		# (as in Smash Bros)
		# ground slide continued in the air forces horizontal motion and uses a different code branch,
		# so it doesn't matter but to be semantically correct, we check it too
		# same for wall jump lock timer
		# air slide allows full control on X
		return not health.is_hurting and not health.is_dead() and not is_ground_sliding \
			and wall_jump_locked_motion_timer.is_stopped()


## Return true if character can move vertically (crouching and climbing ladders)
func _can_move_vertically() -> bool:
	# airborne, hurt, death and attack prevent vertical move
	return is_on_floor() and not health.is_hurting and not health.is_dead() \
		and melee_attack.can_move_vertically()


## Return true if character can jump
func _can_jump() -> bool:
	if is_on_floor():
		# when grounded: sliding, hurt, death and attack prevent jump
		return not is_sliding() and not health.is_hurting and not health.is_dead() \
			and melee_attack.can_jump()
	elif is_wall_sliding:
		return true
	else:
		# no Double jump
		return false


## Return true if character is sliding, either from ground or air
## ! this is about dodge sliding, and is unrelated to wall sliding !
func is_sliding() -> bool:
	return is_ground_sliding or is_air_sliding


## Return true if character can slide
func _can_slide() -> bool:
	# character can now slide on ground and in the air, but the animations and
	# gameplay effects differ
	# already sliding, hurt, death and attack prevent slide
	return not is_sliding() and not health.is_hurting and not health.is_dead() \
		and melee_attack.can_slide()


## Return true if character can start attack or chain a new attack
func _can_start_attack() -> bool:
	# Dash Attack is possible while sliding, so don't check not is_sliding()
	return super._can_start_attack() and (can_attack_when_airborne or is_on_floor())


func _move_grounded(delta: float):
	_current_floor_tangent_right = _get_floor_tangent()

	# Process vertical move (crouch)
	_process_vertical_move(vertical_move_intention)

	var has_jumped_down_one_way_platform := false

	# Check if can and wants to jump
	var wants_to_jump := _consume_jump_intention()
	var should_jump := _can_jump() and wants_to_jump
	if should_jump:
		# Check for down+jump on one-way platform
		if vertical_move_intention > 0.0 and one_way_platform_raycast.is_colliding():
			# Fall off the one-way platform
			# Tiles don't have an individual body to add_collision_exception_with
			# (just a body RID to get cell tile data), so use this hack:
			# temporarily disable collision with one-way platform entirely
			# and make sure to re-enable it very fast to avoid falling through
			# 2+ one-way platforms
			# Waiting 1 frame works as long as jump_down_one_way_platform_speed >= 60px/s
			# so character moves by at least 1 px in 1 frame. Else, increase deferred call delay
			set_collision_mask_value(ONE_WAY_PLATFORM_LAYER_NUMBER, false)
			set_collision_mask_value.call_deferred(ONE_WAY_PLATFORM_LAYER_NUMBER, true)

			velocity.y = jump_down_one_way_platform_speed
			has_jumped_down_one_way_platform = true
		else:
			# Normal jump

			# Apply jump velocity immediately
			# Since we have classic action-platformer physics, we don't apply ground slope normal
			# nor previous run momentum to the vertical velocity.
			# However, we do take into account any horizontal velocity, so if player releases input
			# just when jumping, they still decelerate horizontally as usually when airborne
			# It is easier to just consider the character airborne at this moment, so we apply the same
			# formula as in _move_airborne for X:

			# Update velocity horizontal component based on last value and current input
			velocity.x = _process_horizontal_move(horizontal_move_intention, velocity.x, delta)

			# Set velocity Y to jump (don't apply gravity on the first frame)
			_jump()
	else:
		# Staying on ground

		# Check if using Dash Attack
		if melee_attack.is_dash_attacking():
			# While sliding, move toward current direction at slide speed
			var dash_attack_animation_progress_ratio := melee_attack.time_since_attack_start / dash_attack_animation_duration
			var dash_attack_current_speed := dash_attack_speed_curve.sample(dash_attack_animation_progress_ratio)
			_current_signed_ground_speed = _get_current_direction_sign() * dash_attack_current_speed

			# Optional flag clear since Slide animation has priority over Run, but cleaner since
			# we expect it to be set each frame, but _process_horizontal_move is not called
			wants_to_and_can_freely_move_horizontally = false
		# Check if sliding on ground, whether starting this frame or mid-slide
		elif is_ground_sliding:
			# While sliding, move toward current direction at slide speed
			_current_signed_ground_speed = _get_current_direction_sign() * ground_slide_speed

			# Optional flag clear since Slide animation has priority over Run, but cleaner since
			# we expect it to be set each frame, but _process_horizontal_move is not called
			wants_to_and_can_freely_move_horizontally = false
		else:
			# Process horizontal move before slide to make sure that simultaneous move + slide
			# can change direction and slide in this new direction, starting next frame
			_current_signed_ground_speed = _process_horizontal_move(horizontal_move_intention,
				_current_signed_ground_speed, delta)

			# Check if can and wants to start sliding
			var wants_to_slide := _consume_slide_intention()
			var should_slide := _can_slide() and wants_to_slide
			if should_slide:
				_start_ground_slide()

		# Set velocity to (signed) ground speed along tangent
		velocity = _current_signed_ground_speed * _current_floor_tangent_right


	# Apply velocity to move and slide
	var _has_collided := move_and_slide()

	var is_on_floor_cached := is_on_floor()

	# Snap down hack
	# See https://github.com/godotengine/godot/issues/71993
	# Check for becoming airborne without intentional jump
	if not is_on_floor_cached and not should_jump:
		# The character just left the floor without an intentional jump.
		# This means that they either actually left ground (running off a cliff),
		# or that they reached a slope with a relatively lower angle (running toward hill top).
		# In the latter case, we must snap down to ground (up to ground_snap_down_distance).
		# We cannot count on PlayerCharacter.floor_snap_length to do this
		# automatically because it only works when velocity is downward,
		# to eject character out of floor.

		# Detect ground under the new intermediate position by simulating a
		# move from here
		var test_ground_kinematic_collision_2d := move_and_collide(
			ground_snap_down_distance * Vector2.DOWN, true)

		if test_ground_kinematic_collision_2d:
			# Character is still close to ground, snap back to it by moving by
			# the travel vector
			var travel = test_ground_kinematic_collision_2d.get_travel()

			# In principle we should apply an atomic move with move_and_collide,
			# but only move_and_slide will update the result of is_on_floor(),
			# so if we want to use it reliably, it's better to call
			# move_and_slide. It doesn't take argument however, so we must do
			# the frame trick: set the velocity to wanted travel / delta.
			# We add a margin to travel to make sure that we hit the ground so
			# is_on_floor() returns true after that. We found 0.5-1 DOWN to be
			# a good margin (the warning more below doesn't appear).
			# See https://github.com/godotengine/godot-proposals/issues/6170
			velocity = (travel + 1 * Vector2.DOWN) / delta
			move_and_slide()

			# If snapping worked, we should now be on floor
			# But just to be sure, check it again
			is_on_floor_cached = is_on_floor()
			if not is_on_floor_cached:
				push_warning("[PlayerCharacter] _move_grounded: snapping was ",
					"not enough to get character back on floor this frame")

	if not is_on_floor_cached:
		# Not on floor due to jump or fall

		if should_jump and not has_jumped_down_one_way_platform:
			# Jump up succeeded (no low ceiling blocking), set flag
			has_jumped = true

		# Reset ground state if needed
		if is_crouching:
			_stop_crouch()

		_current_floor_tangent_right = Vector2.ZERO
		_current_signed_ground_speed = 0


func _jump():
	velocity.y = -jump_speed


func _update_body_collision_shape():
	# crouch and ground slide are low positions
	# air slide is not
	var is_body_low = is_crouching or is_ground_sliding

	if body_collision_shape_crouching:
		# Both crouching and sliding use the body collision shape for crouching
		# For sliding, it only matters outside the invincibility timespan, if any
		body_collision_shape_crouching.disabled = not is_body_low
		body_collision_shape_standing.disabled = is_body_low
	else:
		# Character has no crouching variant for body collision shape
		# This typically happens for enemies who never crouch
		# Always use standing variant
		body_collision_shape_standing.disabled = false

		if is_body_low:
			push_error("[BaseChacter] _update_body_collision_shape: " +
				"is_body_low is true, yet " +
				"body_collision_shape_crouching is not set on %s, " % get_path() +
				"falling back to body_collision_shape_standing")

	# Same for Hurt Box
	if hurt_box_collision_shape_crouching:
		hurt_box_collision_shape_crouching.disabled = not is_body_low
		hurt_box_collision_shape_standing.disabled = is_body_low
	else:
		hurt_box_collision_shape_standing.disabled = false

		if is_body_low:
			push_error("[BaseChacter] _update_body_collision_shape: " +
				"is_body_low is true, yet " +
				"hurt_box_collision_shape_crouching is not set on %s, " % get_path() +
				"falling back to hurt_box_collision_shape_standing")


func _start_crouch():
	if not is_crouching:
		is_crouching = true
		_update_body_collision_shape()
	else:
		push_error("[BaseChacter] _start_crouch: character is already crouching")


func _stop_crouch():
	if is_crouching:
		is_crouching = false
		_update_body_collision_shape()
	else:
		push_error("[BaseChacter] _stop_crouch: character is not crouching")


func _start_ground_slide():
	# Unlike other start/stop methods, do not check `if not is_ground_sliding`
	# Indeed, it may be possible to chain slide at some point,
	# in which case we want to restart the Slide animation
	is_ground_sliding = true
	health.start_action_invincible()
	# current invincibility covers full Slide animation, so updating body collision
	# shape is not relevant, but later invincibility may be shorter, so still do it
	_update_body_collision_shape()
	slide_timer.start(ground_slide_duration)


func _start_air_slide():
	# Unlike other start/stop methods, do not check `if not is_air_sliding`
	# Indeed, it may be possible to chain slide at some point,
	# in which case we want to restart the Slide animation
	is_air_sliding = true
	health.start_action_invincible()
	slide_timer.start(air_slide_duration)


func stop_ground_slide():
	if is_ground_sliding:
		is_ground_sliding = false
		health.stop_action_invincible()
		_update_body_collision_shape()
	else:
		push_error("[BaseChacter] stop_ground_slide: character is not ground sliding")


func stop_air_slide():
	if is_air_sliding:
		is_air_sliding = false
		health.stop_action_invincible()
	else:
		push_error("[BaseChacter] stop_air_slide: character is not air sliding")


func _move_airborne(delta: float):
	# Remember that we can *start* a slide on the ground, fall off a cliff
	# and continue it a bit mid-air, so apply logic similar to _move_grounded
	if is_ground_sliding:
		# While ground sliding, move toward current direction at slide speed
		velocity.x = _get_current_direction_sign() * ground_slide_speed

		# Optional flag clear since Slide animation has priority over Jump/Fall, but cleaner since
		# we expect it to be set each frame, but _process_horizontal_move is not called
		wants_to_and_can_freely_move_horizontally = false
	elif is_air_sliding:
		# While air sliding, character is free to move horizontally,
		# but the usual speed X is overridden (this is done inside _process_horizontal_move)
		velocity.x = _process_horizontal_move(horizontal_move_intention, velocity.x, delta)

		# Optional flag clear since Air Slide animation has priority over other checks, but
		# semantically correct
		wants_to_and_can_freely_move_horizontally = true
	else:
		if is_wall_sliding:
			# Check for wall jump
			var wants_to_jump := _consume_jump_intention()
			var should_jump := _can_jump() and wants_to_jump
			if should_jump:
				velocity.y = -wall_jump_vertical_speed

				# Force character to move away from wall for a certain time
				# before potentially coming back
				# Also reverse horizontal direction so character can chain attack in the correct
				# Make sure to do this after using direction above for speed X
				var opposite_direction := MathUtils.horizontal_direction_to_opposite(direction)
				try_change_direction(opposite_direction)
				var opposite_direction_sign := MathUtils.horizontal_direction_to_sign(opposite_direction)
				velocity.x = opposite_direction_sign * max_horizontal_speed
				wall_jump_locked_motion_timer.start()

				# important to set this flag in case character has *fallen* onto the wall
				# as in this case flag is still false at this point but we need to enable
				# variable jump height (jump interrupt) too
				has_jumped = true

		# Do not update velocity X at all during wall jump lock, since we want fixed speed X
		# and no air friction
		if wall_jump_locked_motion_timer.is_stopped():
			# Update velocity horizontal component based on last value and current input
			# Process horizontal move before air slide to make sure that simultaneous move + slide
			# can change direction and slide in this new direction, starting next frame
			# (less important than ground slide since character retains horizontal control)
			velocity.x = _process_horizontal_move(horizontal_move_intention, velocity.x, delta)

		# Check if can and wants to start air sliding
		var wants_to_slide := _consume_slide_intention()
		var should_slide := _can_slide() and wants_to_slide
		if should_slide:
			_start_air_slide()

	# Add the gravity to vertical component
	var current_gravity := gravity_during_wall_slide_downward if is_wall_sliding and velocity.y >= 0.0 \
		else gravity
	velocity.y += current_gravity * delta

	# Check hold jump
	var signed_jump_interrupt_speed = -jump_interrupt_speed
	if has_jumped and not has_canceled_jump and not hold_jump_intention and velocity.y < signed_jump_interrupt_speed:
		velocity.y = signed_jump_interrupt_speed
		has_canceled_jump = true

	var current_max_fall_speed := max_fall_speed_during_wall_slide if is_wall_sliding else max_fall_speed
	velocity.y = min(velocity.y, current_max_fall_speed)

	# Apply velocity to move and slide
	var _has_collided = move_and_slide()

	# Check for landing
	if is_on_floor():
		# Exceptionally update floor tangent immediately instead of start of next physics step
		# so we can preserve tangential velocity component
		_current_floor_tangent_right = _get_floor_tangent()

		# Projecting current velocity onto ground in-place, and update signed ground speed
		# by retrieving the numerical abscissa via dot product
		velocity = velocity.project(_current_floor_tangent_right)
		_current_signed_ground_speed = velocity.dot(_current_floor_tangent_right)

		# Clear jump flag
		has_jumped = false
		has_canceled_jump = false

		# Interrupt attack still running based on settings
		if melee_attack.is_dash_attacking():
			if cancel_dash_attack_on_landing:
				melee_attack.stop_dash_attack()
		elif melee_attack.is_air_attacking():
			melee_attack.stop_air_attack()
		elif melee_attack.is_attacking():
			melee_attack.stop_attack()

		# Since the only way to transition from airborne to grounded is to go through
		# this block, we are ensuring that in grounded state, is_wall_sliding is always false
		# Also stop wall jump lock timer for clean state
		is_wall_sliding = false
		wall_jump_locked_motion_timer.stop()

	# Check for touching wall (but not floor), including passive touch (not moving toward wall)
	elif is_on_wall():
		is_wall_sliding = true
		# stopping motion lock doesn't matter too much in this game, but if there are very close walls
		# this allows chaining opposite wall jumps
		wall_jump_locked_motion_timer.stop()
	else:
		# free air motion
		is_wall_sliding = false


## Process horizontal move input value applied to old_horizontal_move_speed
## and return new horizontal move speed
## (tangential ground speed when grounded, velocity.x when airborne)
## Horizontal move input is ignored if character cannot move horizontally
func _process_horizontal_move(horizontal_move_input_value: float,
		old_horizontal_move_speed: float, delta: float) -> float:
	var new_horizontal_move_speed

	# if air sliding, overwrite max horizontal speed with air slide speed
	var current_max_horizontal_speed := air_slide_speed if is_air_sliding else max_horizontal_speed

	# Only process horizontal move input if character can move
	if _can_freely_move_horizontally() and horizontal_move_input_value != 0:
		# Player active horizontal move input

		# For a classic action-platformer, horizontal_move_input_value is -1 or 1 in this context,
		# so immediately set ground speed to max speed in this direction
		# But the formula allows for speed based on input magnitude if we want later
		new_horizontal_move_speed = horizontal_move_input_value * current_max_horizontal_speed

		# Animation
		# Only change direction if character can; else, apply moving while strafing
		if _can_change_direction():
			var horizontal_direction: MathEnums.HorizontalDirection

			if horizontal_move_input_value < 0:
				horizontal_direction = MathEnums.HorizontalDirection.LEFT
			else:
				horizontal_direction = MathEnums.HorizontalDirection.RIGHT

			_change_direction(horizontal_direction)

		wants_to_and_can_freely_move_horizontally = true
	else:
		# Horizontal move input is released, or character cannot move horizontally

		# Apply deceleration, computing deceleration value from max speed and deceleration time
		var deceleration = current_max_horizontal_speed / deceleration_time
		new_horizontal_move_speed = move_toward(old_horizontal_move_speed, 0, deceleration * delta)

		wants_to_and_can_freely_move_horizontally = false

	return new_horizontal_move_speed


## Process vertical move input value
## Vertical move input is ignored if character cannot move vertically
func _process_vertical_move(vertical_move_input_value: float):
	# Only process vertical move input if character can move vertically
	if _can_move_vertically() and vertical_move_input_value > 0:
		if not is_crouching:
			_start_crouch()
	else:
		# Vertical move input is released, or character cannot move vertically
		if is_crouching:
			_stop_crouch()


## Return floor tangent as a unit vector
## UB unless grounded. This is orthogonal to the floor normal, rotated by 90 degrees clockwise.
func _get_floor_tangent() -> Vector2:
	assert(is_on_floor(), "_get_floor_tangent: requires is_on_floor()")

	var floor_normal = get_floor_normal()

	if floor_normal == Vector2.ZERO:
		push_warning(is_on_floor(), "_get_floor_tangent: is_on_floor() is true yet get_floor_normal() ",
			"returned Vector2.ZERO. The result will be Vector2.ZERO.")

	var floor_tangent = floor_normal.rotated(deg_to_rad(90))

	if not is_equal_approx(floor_tangent.length_squared(), 1):
		push_warning("_get_floor_tangent: floor_tangent is not a unit vector, normalizing from ",
			floor_tangent, " to ", floor_tangent.normalized())
		floor_tangent = floor_tangent.normalized()

	return floor_tangent


func _on_slide_timer_timeout():
	if is_ground_sliding:
		stop_ground_slide()
	elif is_air_sliding:
		stop_air_slide()
	else:
		push_error("[BaseCharacter] _on_slide_timer_timeout: character is not sliding at all")


# override
func _on_damage_received():
	if is_ground_sliding:
		# Character was ground sliding, stop it (this also clears the animation)
		stop_ground_slide()
	elif is_air_sliding:
		# Character was air sliding, stop it (this also clears the animation)
		stop_air_slide()
