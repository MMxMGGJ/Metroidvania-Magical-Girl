class_name PlayerCharacterStateMeleeAttack
extends PlayerCharacterState
## Melee Attack state
## Requirements:
## - Animation Player in Physics process mode
## - Melee hitbox Area2D with one or several collision shapes for the different
##   attack variants enabled with the right timing (and all disabled on RESET)


enum AttackDirection {
	Forward,
	Upward,
	Downward
}


@export_group("Children")

## Hit box for the melee attack
## It may contain several different collision shapes for each of the combo variants
## Each melee attack animation should enable the appropriate collision shape at the right time
@export var melee_hit_area_2d: Area2D


@export_group("Parameters")

## Maximum number of melee attacks to chain
@export var max_melee_attack_count: int = 2

## List of melee attack data for each pattern, in order of combo
@export var melee_attack_data_list: Array[MeleeAttackData]


## Timer to can cancel time
var can_cancel_timer: Timer

## Timer to end action
var action_timer: Timer

## When _is_attacking is true, indicates direction of attack (ground or air)
## &"Forward", &"Upward", &"Downward"
var attack_direction: AttackDirection

## Attack pattern number
## Starts at 1 to match animation names, so kept at 0 when _is_attacking is false
## This applies to both Ground and Air attacks
var _attack_pattern: int

## Set of Health components hit during the current melee attack
## It is reset on melee attack end or chain
var _just_damaged_health_set: Dictionary#<Health, bool>



func _ready():
	initialize()
	setup()


func initialize():
	DebugUtils.assert_array_member_is_not_empty(self, melee_attack_data_list, "melee_attack_data_list")
	assert(melee_attack_data_list.size() == max_melee_attack_count,
		"melee_attack_data_list.size() is %d, but it should match max_melee_attack_count (%d)" %
			[melee_attack_data_list.size(), max_melee_attack_count])

	DebugUtils.assert_member_is_set(self, melee_hit_area_2d, "melee_hit_area_2d")

	# Note: we pass a dummy duration, but we'll pass the actual durations
	# for each attack pattern on timer start
	can_cancel_timer = TimerUtils.create_one_shot_physics_timer_under(
		self, 1.0, _on_can_cancel_timer_timeout)
	action_timer = TimerUtils.create_one_shot_physics_timer_under(
		self, 1.0, _on_action_timer_timeout)

	melee_hit_area_2d.body_entered.connect(_on_melee_hit_area_2d_body_entered)


func setup():
	attack_direction = AttackDirection.Forward
	_attack_pattern = 0
	_just_damaged_health_set.clear()


# implement
func get_state_name() -> StringName:
	return &"MeleeAttack"


# implement
func get_base_animation() -> StringName:
	return "MeleeAttack%d" % _attack_pattern


# override
func get_tags() -> Array[StringName]:
	return []


# override
## Called on action start
func on_enter():
	setup()
	start_next_attack(AttackDirection.Forward)


func start_next_attack(direction: AttackDirection):
	if _attack_pattern >= max_melee_attack_count:
		push_error("_attack_pattern is %d, should be less than max_melee_attack_count (%d)"
			% [_attack_pattern, max_melee_attack_count])
		return

	attack_direction = direction
	_attack_pattern = _attack_pattern + 1
	character.try_remove_active_tag(&"CanJump")

	# Clear set of damaged health components, in case we are chaining an attack
	# over a previous one, so we can hit the same health components again
	_just_damaged_health_set.clear()

	var melee_attack_data := melee_attack_data_list[_attack_pattern - 1]

	var dir_sign := MathUtils.horizontal_direction_to_sign(character.direction)
	character.velocity.x = dir_sign * melee_attack_data.character_move_speed
	can_cancel_timer.start(melee_attack_data.duration_before_can_cancel)
	action_timer.start(melee_attack_data.action_duration)
	InGameManager.sfx_manager.spawn_sfx(melee_attack_data.sfx)


# implement
func on_physics_process(_delta: float):
	# We could do this check at PlayerCharacter level to put all input->action
	# at the same level, but it would require casting the &"MeleeAttack" state
	# to call the `start_next_attack` method. Plus, there is no 1 frame delay
	# in checking this here since we don't change state, just start next animation
	# so it's easier just check next melee attack intention here
	if character.melee_attack_intention and can_cancel_timer.is_stopped():
		# Consume intention and attack
		character.melee_attack_intention = false
		start_next_attack(AttackDirection.Forward)

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

func _on_melee_hit_area_2d_body_entered(body: Node2D):
	var target := body as CharacterBase
	if target != null:
		var health = target.health
		_try_damage_health_once(health)


## Try to hit the body if it has not already been hit during the current melee
## attack
func _try_damage_health_once(health: Health):
	if health not in _just_damaged_health_set:
		_just_damaged_health_set[health] = true

		var damage := _get_damage_from_current_attack_type()

		# A damage can ultimately change a character state and call CharacterAnim.play_animation,
		# causing the following error:
		# > play_animation(): Can't change this state while flushing queries.
		# > Use call_deferred() or set_deferred() to change monitoring state instead.
		# To avoid this, we defer the damage as suggested. Since we already had 1 frame of visual
		# lag on hurt animation + FX anyway, this shouldn't be a big issue and even help us resync
		# model and visual update to the start of the next frame
		health.try_receive_damage.call_deferred(damage, Enums.DamageType.NORMAL)


## Return damage to deal with current attack type
## UB unless character is attacking
func _get_damage_from_current_attack_type() -> int:
	# RISK OF 1 FRAME LAG and checking new attack pattern (_attack_pattern-1) for damage!
	# TODO for testing: create a melee hit that is instant (frame 1)
	# with a very different damage value and check if it's not used by the old attack hit
	# a bit hard to trigger as I must press attack input on the frame of hit...
	# consider automation via puppet simulation
	return melee_attack_data_list[_attack_pattern].damage
