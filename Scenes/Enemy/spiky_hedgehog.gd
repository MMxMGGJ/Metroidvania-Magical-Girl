extends CharacterBody2D

@export var dummy_target: CharacterBody2D
@export var SPEED: int=50
@export var CHASE_SPEED: int = 150

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast_2d: RayCast2D = $AnimatedSprite2D/RayCast2D
@onready var timer: Timer = $Timer

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var direction: Vector2
var right_bounds: Vector2
var left_bounds: Vector2

enum States{
	PATROL,
	CHASE
}
var current_state = States.PATROL

func _ready():
	left_bounds = self.position + Vector2(-100,0)
	right_bounds = self.position + Vector2(100,0)
