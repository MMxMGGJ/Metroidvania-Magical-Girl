class_name CharacterBase
extends CharacterBody2D

@export var health: Health


## NOT CALLED
## Clear character
## For instant death or called at end of Die animation
func clear():
    health.clear()
