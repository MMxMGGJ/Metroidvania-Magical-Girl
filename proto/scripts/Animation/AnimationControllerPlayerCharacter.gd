class_name AnimationControllerPlayerCharacter
extends AnimationControllerBase
## Animation controller for Player Character


## Player character owner
@export var player_character: PlayerCharacter

# Pseudo-constants initialized in _ready

## Regex pattern for the attack animation name
var attack_animation_regex := RegEx.new()


# override
func initialize():
	super.initialize()

	DebugUtils.assert_member_is_set(self, player_character, "player_character")

	attack_animation_regex.compile("Attack(\\d+)?")


# implement
## Return base animation based on owner state and last animation
func _get_base_animation(last_animation: StringName) -> StringName:
	var new_animation: String
	var should_not_loop: bool = false

	if player_character.is_wall_sliding:
		new_animation = &"WallSlide"
	# PC can keep sliding in the air so check is_ground_sliding before is_on_floor()
	elif player_character.is_ground_sliding:
		new_animation = &"Slide"
	# Air Slide *should* stop when landing, but if we decide to let it continue,
	# at least animation will go on thx to this early check
	elif player_character.is_air_sliding:
		new_animation = &"AirSlide"
	else:
		if player_character.is_on_floor():
			if player_character.is_crouching:
				# Transition code below will be simplified when switching to Animation Tree
				if last_animation in [&"Crouch", &"Slide"]:
					# Already crouching, keep it
					new_animation = &"Crouch"
				else:
					# Character comes from some standing animation, or is already playing IdleToCrouch,
					# so play transition (should not loop)
					new_animation = &"IdleToCrouch"
					should_not_loop = true
			elif player_character.wants_to_and_can_freely_move_horizontally:
				new_animation = &"Run"
			else:
				# Transition code below will be simplified when switching to Animation Tree
				if last_animation in [&"Crouch", &"CrouchToIdle"]:
					# Character was crouching, or already playing transition, so play transition
					# (should not loop)
					new_animation = &"CrouchToIdle"
					should_not_loop = true
				else:
					# Already idle, keep it
					new_animation = &"Idle"
		else:
			if player_character.has_jumped and player_character.velocity.y < 0:
				new_animation = &"Jump"
			else:
				# Transition code below will be simplified when switching to Animation Tree
				if last_animation in [&"Jump", &"UpToFall"]:
					# Falling from jump, or already in UpToFall, so continue with UpToFall transition
					# (should not loop)
					new_animation = &"UpToFall"
					should_not_loop = true
				else:
					# When falling directly from Idle/Run, or after UpToFall finished, continue with Fall
					new_animation = &"Fall"

	if OS.has_feature("debug"):
		if should_not_loop:
			# Retrieve Animation resource from the appropriate library and warn if not looping
			var animation_resource := animation_player.get_animation(new_animation)
			if animation_resource and animation_resource.loop_mode != Animation.LOOP_NONE:
				push_warning("[CharacterAnim] Animation '%s' is expected not to loop, but it does"
					% new_animation)

	return new_animation


# override
## Process animation end
func _process_animation_finished(anim_name: StringName):
	if anim_name == &"UpToFall":
		# UpToFall transition finished, continue with Fall
		play_animation(&"Fall")
	elif anim_name == &"IdleToCrouch":
		# IdleToCrouch transition finished, continue with Crouch
		play_animation(&"Crouch")
	elif anim_name == &"CrouchToIdle":
		# CrouchToIdle transition finished, continue with Idle
		play_animation(&"Idle")
	elif anim_name == &"Hurt":
		# Hurt animation finished, update health flag
		player_character.health.is_hurting = false
	elif anim_name == &"Die":
		# Die animation finished, clear player character (do not remove from scene to allow restart)
		player_character.clear()
	elif anim_name == &"DashAttack":
		player_character.melee_attack.on_attack_finished()
	else:
		var match_attack_animation = attack_animation_regex.search(anim_name)
		if match_attack_animation:
			# "Attack" or "Attack%d" animation finished, confirm attack end to
			# model (just call on_attack_finished(), no need to stop_attack()
			# since animation is already finished)
			player_character.melee_attack.on_attack_finished()
