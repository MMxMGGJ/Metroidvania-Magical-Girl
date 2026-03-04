class_name BossHurtBox
extends Area2D
## Handles getting hurt by player character attack


@export_group("Parent")

## Owning boss
@export var boss: Boss


@export_group("Parameters")

## Invincible flag
## If true, this boss cannot receive damage
## This can be set permanently in inspector on some boss parts, or changed at runtime for temporary
## invincibility
@export var invincible: bool = false


## Type of the last player character action that dealt damage to this boss
var last_damage_type: Enums.DamageType

## If true, this hurt box is invincible against damage of type [immunity_type]
var enabled_immunity: bool

## Type to be immune again, if enabled_immunity is true
var immunity_type: Enums.DamageType


func _ready():
	initialize()
	setup()


func initialize():
	DebugUtils.assert_member_is_set(self, boss, "boss")


func setup():
	last_damage_type = Enums.DamageType.NORMAL  # irrelevant as long as count is 0
	disable_immunity()


# currently unused
func enable_immunity_against(damage_type: Enums.DamageType):
	enabled_immunity = true
	immunity_type = damage_type


func disable_immunity():
	enabled_immunity = false
	immunity_type = Enums.DamageType.NORMAL  # irrelevant when enabled_immunity is false


func invincible_against_damage_type(damage_type: Enums.DamageType):
	return invincible or enabled_immunity and immunity_type == damage_type


func try_receive_damage(damage: int, damaging_player_character: PlayerCharacterBase, damage_type: Enums.DamageType):
	if not invincible_against_damage_type(damage_type):
		var success := boss.health.try_receive_damage(damage, damage_type)
		if success:
			last_damage_type = damage_type
