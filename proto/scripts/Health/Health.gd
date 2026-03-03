# Copied and simplified from Godot 4 Platformer by komehara

class_name Health
extends Node


signal value_changed(new_value: int)
signal damage_received
signal death

## Maximum health (HP)
@export var max_health: int = 1

## Color tint when character is hurt
@export var hurt_color: Color = Color.RED

## Brightness when hurt
@export var hurt_brightness: float = 0.5

## Duration of hurt visual feedback (s)
@export var hurt_feedback_duration: float = 0.5

## Color tint when character is invincible thanks to an action
@export var action_invincible_color: Color = Color.CYAN

## Color extra brightness when character is invincible thanks to an action
@export var action_invincible_brightness: float = 0.0

## Current health (HP)
var current_health: int = max_health

## True when character is invincible
var _is_invincible: bool

## True when character is hurting (hurt and still playing hurt animation)
var is_hurting: bool

@onready var character: BaseCharacter = $".."
@onready var sprite_with_properties_controller: CanvasItemWithPropertiesController = \
	character.sprite_with_properties_controller


func _ready():
	initialize()
	# Do not call setup, as this script is managed by a master script


func initialize():
	DebugUtils.assert_member_is_set(self, character, "character")


func setup():
	# It is important to use setter to emit value_changed signal
	# so health gauge is properly updated on start/restart for PC
	# (who doesn't bind and refresh gauge view on setup)
	set_current_health(max_health)

	_is_invincible = false
	is_hurting = false


func set_current_health(new_value: int):
	current_health = new_value
	value_changed.emit(current_health)


func get_health_ratio() -> float:
	return current_health as float / max_health


func is_dead() -> bool:
	return current_health <= 0


func _can_receive_damage():
	return not _is_invincible and not is_dead()


## Make character invincible and feedback with color to show it's invincible thanks to an action
func start_action_invincible():
	_is_invincible = true
	sprite_with_properties_controller.start_override_brightness(action_invincible_brightness)
	sprite_with_properties_controller.start_override_modulate(action_invincible_color)


## End character invincibility due to action, and stop feedback
func stop_action_invincible():
	_is_invincible = false
	sprite_with_properties_controller.stop_override_brightness()
	sprite_with_properties_controller.stop_override_modulate()


## End character invincibility due to hurt, and stop feedback
## Currently UNUSED
func stop_hurt_invincible():
	_is_invincible = false
	sprite_with_properties_controller.stop_override_modulate()


func try_receive_damage(damage: int):
	if _can_receive_damage():
		_receive_damage(damage)


func _receive_damage(damage: int):
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
		# will be cleared by Hurt animation end
		is_hurting = true
		character.animation_controller.play_override_animation("Hurt", false)

	# Play feedback, whether character dies or not
	sprite_with_properties_controller.override_properties_for_duration(hurt_brightness,
		hurt_color, hurt_feedback_duration)
