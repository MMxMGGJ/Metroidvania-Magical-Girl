# Copied and simplified from Godot 4 Platformer by komehara

class_name MeleeAttack
extends Node


@export_group("Assets")

# Removed SFX


@export_group("Children")

@export var melee_hit_area_2d: Area2D


@export_group("Parameters")

## Maximum number of melee attacks to chain
@export var max_melee_attack_count: int = 2

## Damage dealt by a normal attack
@export var normal_attack_damage: int = 1

## Damage dealt by an Air attack (any direction)
@export var air_attack_damage: int = 1

## Damage dealt by a Dash attack
@export var dash_attack_damage: int = 2

## Time elapsed since start of the current attack (0 if not attacking)
var time_since_attack_start: float

## True when character is doing melee attack (including Dash Attack & Air Attack)
var _is_attacking: bool

## True when character is doing Air Attack
var _is_air_attacking: bool

## When _is_attacking is true, indicates direction of attack (ground or air)
## &"Forward", &"Upward", &"Downward"
var attack_direction_string_name: StringName

## True when character is doing Dash Attack
var _is_dash_attacking: bool

## Attack pattern number
## Starts at 1 to match animation names, so kept at 0 when _is_attacking is false
## This applies to both Ground and Air attacks
var _attack_pattern: int

## True when character can chain next attack
## Kept false when _is_attacking is false
var _can_chain_next_attack: bool

## True when character can freely move
## True when _is_attacking is false
var _can_freely_move: bool

## Set of Health components hit during the current melee attack
## It is reset on melee attack end or chain
var _just_damaged_health_set: Dictionary#<Health, bool>

## Duplicate of melee_hit_area_2d specialized into target detection
## Unlike melee_hit_area_2d, its collision shapes are always enabled but don't
## damage targets they overlap
var _melee_scan_area_2d: Area2D


@onready var character: BaseCharacter = $".."
@onready var animation_controller = character.animation_controller


func _ready():
	initialize()
	setup()


func initialize():
	assert(character, "character is not set on %s" % get_path())
	assert(melee_hit_area_2d, "melee_hit_area_2d is not set on %s" % get_path())

	# Duplicate melee_hit_area_2d into a scan version, under same parent
	# Only duplicate the node, since the signal is specific to melee hit and used
	# to actually damage targets entering the area
	# We use DUPLICATE_USE_INSTANTIATION so any changes on the hit area are
	# reflected on the scan area
	_melee_scan_area_2d = melee_hit_area_2d.duplicate(DUPLICATE_USE_INSTANTIATION)
	melee_hit_area_2d.get_parent().add_child(_melee_scan_area_2d)

	melee_hit_area_2d.body_entered.connect(_on_melee_hit_area_2d_body_entered)

	for child in _melee_scan_area_2d.get_children():
		# In the scan version, collision shapes are always enabled:
		# this allows us to detect potential targets at any time,
		# while not damaging overlapped targets
		var body := child as CollisionShape2D
		body.disabled = false

		# Also change debug color to a green hue with lower alpha
		# so we don't confuse both areas when debugging collision shapes
		body.debug_color = Color.hex(0x5c9b4f24)


func setup():
	time_since_attack_start = 0.0
	_is_attacking = false
	_is_air_attacking = false
	attack_direction_string_name = &""
	_is_dash_attacking = false
	_attack_pattern = 0
	_can_chain_next_attack = false
	_can_freely_move = true
	_just_damaged_health_set.clear()


func _physics_process(delta: float):
	time_since_attack_start += delta


## Return true if player character is in the middle of an attack (including Dash Attack)
## (independently of cancel phase)
func is_attacking() -> bool:
	return _is_attacking


## Return true if player character is in the middle of an Air Attack
func is_air_attacking() -> bool:
	return _is_air_attacking


## Return true if player character is in the middle of a Dash Attack
func is_dash_attacking() -> bool:
	return _is_dash_attacking


## Return true if player character is in the middle of an attack
## and cannot cancel it to chain with another attack yet
## Note that this is only a base to help the character master script decide if
## the character can actually start an attack, as it may need to check other
## character-specific state vars
func is_attacking_and_cannot_chain() -> bool:
	return _is_attacking and not _can_chain_next_attack


func start_attack(direction_string_name: StringName):
	time_since_attack_start = 0.0

	if _is_attacking:
		# We were already attacking and chaining attack
		# so we exceptionally bypass _can_change_direction and directly check move intention
		# and update direction accordingly to allow changing direction on next attack
		# This also works when chaining upward attacks using diagonal input:
		# character will face the opposite direction but still attack upward
		# If no move intention, preserve same direction
		if character.horizontal_move_intention != 0:
			character.force_change_direction_toward(character.horizontal_move_intention)
	else:
		_is_attacking = true

	attack_direction_string_name = direction_string_name

	# Cycle all attack patterns
	# Note that attack pattern is counted from 1, so we must subtract 1
	# before applying modulo, and re-add 1 at the end, which gives:
	# `(_attack_pattern + 1 - 1) % max_melee_attack_count + 1`
	# so we can simplify `+ 1 - 1`
	_attack_pattern = _attack_pattern % max_melee_attack_count + 1

	# We cannot chain next attack at first
	# (only needs to be reset when we just chained to next attack)
	_can_chain_next_attack = false

	# We cannot freely move at first
	_can_freely_move = false

	# Clear set of damaged health components, in case we are chaining an attack
	# over a previous one, so we can hit the same health components again
	_just_damaged_health_set.clear()

	# Animation
	var attack_anim_name: String = _get_attack_animation_name(_attack_pattern, false)
	animation_controller.play_override_animation(attack_anim_name)


## Start air attack with passed direction:
## &"Forward", &"Upward" or &"Downward"
func start_air_attack(direction_string_name: StringName):
	time_since_attack_start = 0.0

	if _is_air_attacking:
		# Allow changing direction on next attack chain
		# This also works when chaining upward attacks using diagonal input:
		# character will face the opposite direction but still attack upward
		if character.horizontal_move_intention != 0:
			character.force_change_direction_toward(character.horizontal_move_intention)
	else:
		_is_air_attacking = true

	attack_direction_string_name = direction_string_name

	_is_attacking = true

	# Cycle all attack patterns
	_attack_pattern = _attack_pattern % max_melee_attack_count + 1

	# We cannot chain next attack at first
	# (only needs to be reset when we just chained to next attack)
	_can_chain_next_attack = false

	# Clear set of damaged health components, in case we are chaining an attack
	# over a previous one, so we can hit the same health components again
	_just_damaged_health_set.clear()

	# Animation
	var attack_anim_name: String = _get_attack_animation_name(_attack_pattern, true)
	animation_controller.play_override_animation(attack_anim_name)


func start_dash_attack():
	time_since_attack_start = 0.0
	_is_attacking = true
	_is_dash_attacking = true

	# Dash attack has only one pattern, so don't bother setting it

	# We cannot chain next attack at all with Dash attack
	_can_chain_next_attack = false

	# We cannot freely move at all during Dash attack
	_can_freely_move = false

	# Dash attack cannot chain, so we shouldn't have to clear set of damaged health components

	# Animation
	var attack_anim_name: String = &"DashAttack"
	animation_controller.play_override_animation(attack_anim_name)


## Immediately stop the current attack
## Only used for interruption without chain, without being hurt, such as landing
func stop_attack():
	assert(_is_attacking, "[MeleeAttack] stop_attack: _is_attacking is false")

	# Store attack pattern before attack state is reset
	var old_attack_pattern = _attack_pattern

	# Model
	on_attack_finished()

	# Visual
	var attack_anim_name: String = _get_attack_animation_name(old_attack_pattern, false)
	animation_controller.clear_override_animation(attack_anim_name)


## Immediately stop the current Air attack
## Only used for interruption without chain, without being hurt, such as landing
func stop_air_attack():
	assert(_is_air_attacking, "[MeleeAttack] stop_air_attack: _is_air_attacking is false")

	# Store attack animation name before attack state is reset by on_attack_finished
	var attack_anim_name: String = _get_attack_animation_name(_attack_pattern, true)

	# Model
	on_attack_finished()

	# Visual
	animation_controller.clear_override_animation(attack_anim_name)


## Immediately stop the current Dash attack
## Only used for interruption without being hurt, such as landing
func stop_dash_attack():
	assert(_is_dash_attacking, "[MeleeAttack] stop_dash_attack: _is_dash_attacking is false")

	# Model
	on_attack_finished()

	# Visual
	animation_controller.clear_override_animation(&"DashAttack")


func _get_attack_animation_name(attack_pattern: int, is_airborne: bool) -> String:
	var new_animation_basename: String

	if is_airborne:
		new_animation_basename = "AirAttack%s" % attack_direction_string_name
	else:
		new_animation_basename = "Attack%s" % attack_direction_string_name

	var new_animation: String

	var new_animation_numbered := "%s%d" % [new_animation_basename, attack_pattern]
	if animation_controller.animation_player.has_animation(new_animation_numbered):
		# Use numbered animation
		# Ex: "Attack2": for the 2nd attack pattern
		new_animation = new_animation_numbered
	else:
		# No numbered animation, fallback to basename
		# Ex: "Attack"
		new_animation = new_animation_basename

	return new_animation


func on_attack_finished():
	time_since_attack_start = 0.0
	_is_attacking = false
	_is_air_attacking = false
	attack_direction_string_name = &""
	_is_dash_attacking = false
	_attack_pattern = 0
	# no attack anymore, so no chain (but can start new attack cycle)
	_can_chain_next_attack = false
	# generally an animation callback will set this to true earlier,
	# but as safety we enable move at the latest at the end of the attack
	_can_freely_move = true
	_just_damaged_health_set.clear()


## Return all targets that would be hit by a melee attack if hit was applied
## on this frame
## _on_melee_hit_area_2d_body_entered handles hit directly on specific body,
## but this method is useful for AI to determine if an opponent is in hit range
func find_melee_hit_targets_in_range() -> Array[BaseCharacter]:
	# melee_hit_area_2d Mask must be set to collision layers that must be hit,
	# e.g. EnemyCharacter
	# However, for target detection we use _melee_scan_area_2d which is always
	# enabled without damaging targets it overlaps
	var hit_bodies := _melee_scan_area_2d.get_overlapping_bodies()
	var hit_targets: Array[BaseCharacter] = []

	for hit_body in hit_bodies:
		var target := hit_body as BaseCharacter
		if target:
			hit_targets.append(target)

	return hit_targets


## Return true if this component allows character to change horizontal direction
## (but other factors may prevent it)
func can_change_direction() -> bool:
	# currently it is bound to moving (no strafing)
	return _can_freely_move


## Return true if this component allows character to freely (not part of some preset motion)
## move horizontally
## (but other factors may prevent it)
func can_freely_move_horizontally() -> bool:
	return _can_freely_move


## Return true if this component allows character to move vertically (crouching and climbing ladders)
## (but other factors may prevent it)
func can_move_vertically() -> bool:
	# currently it is bound to moving (if can move, can crouch)
	return _can_freely_move


## Return true if this component allows character to jump
## (but other factors may prevent it)
func can_jump() -> bool:
	# currently it is bound to moving (if can move, can jump)
	return _can_freely_move


## Return true if this component allows character to slide
## (but other factors may prevent it)
func can_slide() -> bool:
	# currently it is bound to moving (if can move, can slide)
	return _can_freely_move


## Called when character can cancel the end of the current attack animation to
## chain with another attack
func animation_set_can_chain_true():
	_can_chain_next_attack = true


## Called when character can cancel the end of the current attack animation to
## move (horizontally, crouch, jump)
func animation_set_can_freely_move_true():
	_can_freely_move = true


func _on_melee_hit_area_2d_body_entered(body: Node2D):
	var target := body as BaseCharacter
	if target != null:
		var health = target.health
		_try_damage_health_once(health)


## Try to hit the body if it has not already been hit during the current melee
## attack
func _try_damage_health_once(health: Health):
	if health not in _just_damaged_health_set:
		_just_damaged_health_set[health] = true

		var damage := _get_damage_from_current_attack_type()

		# A damage can ultimately change a character state an call CharacterAnim.play_animation,
		# causing the following error:
		# > play_animation(): Can't change this state while flushing queries.
		# > Use call_deferred() or set_deferred() to change monitoring state instead.
		# To avoid this, we defer the damage as suggested. Since we already had 1 frame of visual
		# lag on hurt animation + FX anyway, this shouldn't be a big issue and even help us resync
		# model and visual update to the start of the next frame
		health.try_receive_damage.call_deferred(damage, Enums.DamageType.SWORD)


## Return damage to deal with current attack type
## UB unless character is attacking
func _get_damage_from_current_attack_type() -> int:
	# remember that _is_attacking is also true during Dash attack
	# so check _is_dash_attacking first
	if _is_dash_attacking:
		return dash_attack_damage
	elif _is_air_attacking:
		return air_attack_damage
	elif _is_attacking:
		return normal_attack_damage
	else:
		push_error("[MeleeAttack] _get_damage_from_current_attack_type: ",
			"_is_attacking is false, expected it to be true. Possible cause: ",
			"MeleeHitCollisionShape2D is not disabled in RESET animation.")
		return 0
