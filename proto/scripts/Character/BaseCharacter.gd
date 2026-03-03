# Copied and simplified from Godot 4 Platformer by komehara

class_name BaseCharacter
extends CharacterBody2D


## Signal sent when character is despawned, whether after gameplay death or on level exit/restart
## (via clear or queue_free)
signal despawn

@export var animation_controller: AnimationControllerBase
@export var health: Health
@export var melee_attack: MeleeAttack
@export var directed_parent: Node2D
@export var sprite_with_properties_controller: CanvasItemWithPropertiesController

## True iff character is a boss
@export var is_boss: bool = false


## Remembers if node was enabled in scene, so we don't unexpectedly enable it on restart
var enabled_in_scene: bool

## Flag to remember this character was spawned from a spawn point,
## so we don't generate another one
var spawned_from_spawn_point: bool = false

## Initial local position, stored on _ready
var initial_local_position: Vector2

## Where the character wants to move horizontally this frame (negative for left, positive for right)
## Sticky during simulation
var horizontal_move_intention: float

## Where the character wants to move vertically this frame (negative for up, positive for down)
## Sticky during simulation
var vertical_move_intention: float

## True iff character wants to attack this frame
## Consumed during simulation
var attack_intention: bool

## Current horizontal direction
var direction: MathEnums.HorizontalDirection


func _ready():
	initialize()

	# no setup here to avoid redundant setup when respawned from spawn point
	# instead, it is done inside initialize, only if *not* spawned from spawn point


func initialize():
	assert(animation_controller, "animation_controller is not set on %s" % get_path())
	assert(health, "health is not set on %s" % get_path())
	assert(melee_attack, "melee_attack is not set on %s" % get_path())
	assert(directed_parent, "directed_parent is not set on %s" % get_path())
	assert(sprite_with_properties_controller, "sprite_with_properties_controller is not set on %s" % get_path())

	# We only use DISABLED mode when we want to temporarily disable some nodes for testing
	enabled_in_scene = process_mode != Node.PROCESS_MODE_DISABLED
	if not enabled_in_scene:
		# If disabled, also hide to avoid frozen sprite
		hide()

	initial_local_position = transform.origin

	# This is a player character, so always setup, there is no respawn via spawn point anyway
	# (just a warp to initial position)
	setup()

	health.damage_received.connect(_on_damage_received)
	health.death.connect(_on_death)


func setup():
	if enabled_in_scene:
		# in case character was dead, re-enable process and rendering
		process_mode = Node.PROCESS_MODE_INHERIT
		show()

	animation_controller.setup()
	health.setup()
	melee_attack.setup()
	sprite_with_properties_controller.setup()

	# Reset intentions
	horizontal_move_intention = 0.0
	vertical_move_intention = 0.0
	attack_intention = false

	# Character sprites must all face right, so use it as initial direction
	# Make sure to call _change_direction to also update sprite orientation
	_change_direction(MathEnums.HorizontalDirection.RIGHT)


## Clear character
## For instant death or called at end of Die animation
func clear():
	process_mode = PROCESS_MODE_DISABLED
	hide()

	despawn.emit()


# currently unused as we prefer clearing all characters, waiting, then
# setting them up again
func restart():
	clear()

	# Workaround for https://github.com/godotengine/godot/issues/76219
	# Wait 1 frame here to avoid edge case of
	# disabling Area2D and re-enabling it on the same frame
	# while Area2D contains a PhysicsBody2D, as it would register it forever
	# This corresponds to case a. in Level._unhandled_input > restart_player_character
	await get_tree().physics_frame

	warp_to_initial_position()
	setup()


func warp_to_initial_position():
	# We assume parent did not change, so warping to initial local position
	# will indeed warp to initial global position
	_warp_to_local(initial_local_position)


func _warp_to_local(to_local_position: Vector2):
	transform.origin = to_local_position

	# Also clear velocity in case character was moving (e.g. falling fast) before warp,
	# esp. on restart
	velocity = Vector2.ZERO


func _physics_process(delta: float):
	reset_transient_members()
	on_physics_process(delta)


# virtual
## Reset all members that are set once per frame, before their usage,
## typically state vars assigned during physics and used later in the frame
## by animation (in perfect sync when physics-driven)
func reset_transient_members():
	pass


# virtual
func on_physics_process(_delta: float):
	pass


## If character wants to attack this frame, return true and consume the intention flag
## Else, return false
func _consume_attack_intention() -> bool:
	if attack_intention:
		attack_intention = false
		return true
	else:
		return false


## Return true if character can change horizontal direction
func _can_change_direction() -> bool:
	return not health.is_hurting and not health.is_dead() \
		and melee_attack.can_change_direction()


## Return true if character can start attack or chain a new aattack
func _can_start_attack() -> bool:
	return not health.is_hurting and not health.is_dead() \
		and not melee_attack.is_attacking_and_cannot_chain()


## Change character direction, updating directed parent and all its children
func _change_direction(horizontal_direction: MathEnums.HorizontalDirection):
	direction = horizontal_direction

	NodeUtils.set_flip_x(directed_parent, horizontal_direction == MathEnums.HorizontalDirection.LEFT)


## If not already facing target in to_target_vector, change direction accordingly
func try_turn_toward_target_if_needed(to_target_vector: Vector2):
	if to_target_vector.x != 0:
		# Character is not at exact same X, turn toward it
		var horizontal_direction: MathEnums.HorizontalDirection

		if to_target_vector.x < 0:
			horizontal_direction = MathEnums.HorizontalDirection.LEFT
		elif to_target_vector.x > 0:
			horizontal_direction = MathEnums.HorizontalDirection.RIGHT

		try_change_direction(horizontal_direction)


func try_change_direction(horizontal_direction: MathEnums.HorizontalDirection):
	if _can_change_direction():
		_change_direction(horizontal_direction)


## Change direction of character toward signed x, bypassing restrictions
## UB unless signed_x is not zero
func force_change_direction_toward(signed_x: float):
	var horizontal_direction: MathEnums.HorizontalDirection

	if signed_x < 0:
		horizontal_direction = MathEnums.HorizontalDirection.LEFT
	elif signed_x > 0:
		horizontal_direction = MathEnums.HorizontalDirection.RIGHT
	else:
		push_error("[BaseCharacter] force_change_direction_toward: ",
			"signed_x is 0, expected non-zero value")
		return

	_change_direction(horizontal_direction)


func _get_current_direction_sign() -> int:
	return -1 if direction == MathEnums.HorizontalDirection.LEFT else 1


# virtual
func _on_damage_received():
	pass


# virtual
func _on_death():
	pass
