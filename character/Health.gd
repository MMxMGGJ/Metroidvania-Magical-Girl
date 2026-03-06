class_name Health
extends Node
## Character health component


signal value_changed(new_value: int)
signal damage_received
signal death

## Maximum health (HP)
@export var max_health: int = 1

## Duration of hurt stun (s)
## This defines how long the character is unable to move after being hurt
## Character may also receive knockback impulse when hurt, although its effect
## may end earlier than stun thanks to friction
@export var hurt_stun_duration: float = 0.5

## Color tint when character is hurt (before invincibility frames)
@export var hurt_color: Color = Color.RED

## Brightness when hurt (before invincibility frames)
@export var hurt_brightness: float = 0.5

## Duration of hurt visual feedback (s)
## Set it to 0 to remove initial hurt feedback entirely and replace it
## with only invincibility feedback, as in classic games
@export var hurt_feedback_duration: float = 0.5

## Color tint when character is invincible after being hurt
## Use alpha to approximate classic game blinking at high FPS
@export var hurt_invincible_color: Color = Color(Color.WHITE, 0.5)

## Brightness when character is invincible after being hurt
@export var hurt_invincible_brightness: float = 0.0

## Duration of invincibility after being hurt (s)
## This includes hurt_feedback_duration, so we expect it to be greater
## If less than or equal to hurt_feedback_duration, then hurt invincibility feedback is never shown
@export var hurt_invincible_duration: float = 1.0

## Color tint when character is invincible thanks to an action
@export var action_invincible_color: Color = Color.CYAN

## Color extra brightness when character is invincible thanks to an action
@export var action_invincible_brightness: float = 0.0

## SFX played when owning character is hurt by attack of type NORMAL
@export var hurt_sfx_normal: AudioStream

## SFX played when owning character is hurt by attack of type NORMAL
@export var hurt_sfx_water: AudioStream

## SFX played when owning character is hurt by attack of type NORMAL
@export var hurt_sfx_fire: AudioStream

## Current health (HP)
var current_health: int = max_health

## True when character is invincible due to current action
var _is_invincible_by_action: bool

## Optional hurt stun timer
## If not set, there is no stun after hurt
@export var hurt_stun_timer: Timer

## Optional hurt invincibility timer
## If not set, there is no invincibility after hurt
@export var hurt_invincibility_timer: Timer

@onready var character: CharacterBase = $".."
@onready var sprite_with_properties_controller: CanvasItemWithPropertiesController = \
	character.sprite_with_properties_controller


func _ready():
	initialize()
	# Do not call setup, as this script is managed by a master script


func initialize():
	DebugUtils.assert_member_is_set(self, character, "character")

	# If no invincibility timer (e.g. enemies), ignore hurt invincibility
	if hurt_invincibility_timer:
		hurt_invincibility_timer.timeout.connect(_on_hurt_invincibility_timer_timeout)


func setup():
	# It is important to use setter to emit value_changed signal
	# so health gauge is properly updated on start/restart for PC
	# (who doesn't bind and refresh gauge view on setup)
	set_current_health(max_health)

	_is_invincible_by_action = false


func clear():
	if hurt_stun_timer:
		hurt_stun_timer.stop()
	if hurt_invincibility_timer:
		hurt_invincibility_timer.stop()


func set_current_health(new_value: int):
	current_health = new_value
	value_changed.emit(current_health)


func get_health_ratio() -> float:
	return current_health as float / max_health


func is_dead() -> bool:
	return current_health <= 0


func is_stunned():
	return hurt_stun_timer and not hurt_stun_timer.is_stopped()


func _is_invincible():
	return _is_invincible_by_action or hurt_invincibility_timer and not hurt_invincibility_timer.is_stopped()


func _can_receive_damage():
	return not _is_invincible() and not is_dead()


## Make character invincible and feedback with color to show it's invincible thanks to an action
func start_action_invincible():
	_is_invincible_by_action = true
	sprite_with_properties_controller.start_override_brightness(action_invincible_brightness)
	sprite_with_properties_controller.start_override_modulate(action_invincible_color)


## End character invincibility due to action, and stop feedback
func stop_action_invincible():
	_is_invincible_by_action = false
	sprite_with_properties_controller.stop_override_brightness()
	sprite_with_properties_controller.stop_override_modulate()


## Start feedback for character invincibility due to hurt
func start_hurt_invincible_feedback():
	# Only start if invincibility is still running at this point
	# When this is called after hurt feedback
	# (sprite_with_properties_controller.properties_override_timer.timeout),
	# this is equivalent to checking hurt_invincible_duration > hurt_feedback_duration
	if hurt_invincibility_timer and not hurt_invincibility_timer.is_stopped():
		sprite_with_properties_controller.start_override_brightness(hurt_invincible_brightness)
		sprite_with_properties_controller.start_override_modulate(hurt_invincible_color)


## End feedback for character invincibility due to hurt
func stop_hurt_invincible_feedback():
	# We don't have a flag to track if hurt feedback is still running,
	# so here it's easier to just compare timer durations to see if hurt invincible
	# feedback should be played after hurt feedback
	if hurt_invincible_duration > hurt_feedback_duration:
		sprite_with_properties_controller.stop_override_modulate()


func try_receive_damage(damage: int, damage_type: Enums.DamageType) -> bool:
	if _can_receive_damage():
		_receive_damage(damage, damage_type)
		return true
	return false


func _receive_damage(damage: int, damage_type: Enums.DamageType):
	# always send health change signals before death signal, as death signal may clear things
	# such as HUD health gauge references, preventing other signals to work
	# note that set_current_health sends value_changed signal
	set_current_health(max(0, current_health - damage))
	print("%s receives %d damage! health -> %d" % [character.name, damage, current_health])

	damage_received.emit()

	if character.melee_attack.is_attacking():
		# Character was attacking, interrupt (force-finish) attack on model side
		character.melee_attack.on_attack_finished()

	# Play hurt animation (will replace attack animation if playing)
	if current_health == 0:
		death.emit()
		character.animation_controller.play_override_animation("Die")
	else:
		# Start hurt stun immediately (it covers hurt feedback and overlaps invincibility)
		if hurt_stun_timer and hurt_stun_duration > 0.0:
			hurt_stun_timer.start(hurt_stun_duration)

		# Start hurt invincibility immediately (it covers hurt feedback and overlaps stun)
		if hurt_invincibility_timer and hurt_invincible_duration > 0.0:
			hurt_invincibility_timer.start(hurt_invincible_duration)

	if hurt_feedback_duration > 0.0:
		# Play feedback, whether character dies or not
		sprite_with_properties_controller.override_properties_for_duration(hurt_brightness,
			hurt_color, hurt_feedback_duration)
		if hurt_invincibility_timer:
			sprite_with_properties_controller.properties_override_timer.timeout.connect(start_hurt_invincible_feedback)
	else:
		# Not hurt feedback, so immediately play hurt invincible feedback
		start_hurt_invincible_feedback()

	var sfx: AudioStream
	match damage_type:
		Enums.DamageType.NORMAL:
			sfx = hurt_sfx_normal
		Enums.DamageType.WATER:
			sfx = hurt_sfx_water
		Enums.DamageType.FIRE:
			sfx = hurt_sfx_fire

	if sfx:
		InGameManager.sfx_manager.spawn_sfx(sfx)


func _on_hurt_invincibility_timer_timeout():
	stop_hurt_invincible_feedback()
