class_name MeleeAttackData
extends Resource
## Contains parameters for a single melee attack pattern


@export_group("SFX")

## SFX to play on action start
@export var sfx: AudioStream


@export_group("Parameters")

## Damage dealt by this attack pattern
@export var damage: int = 1

## Duration (s) before player can cancel action with the same repeated
## or another one
@export var duration_before_can_cancel: float = 3/12.0

## Duration (s) of action (default is full animation duration)
@export var action_duration: float = 5/12.0

## Speed forward of action (0.0 for no root motion)
@export var character_move_speed: float = 0.0
