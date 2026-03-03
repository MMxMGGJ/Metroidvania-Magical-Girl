extends CharacterBody2D

@export var dummy_target: CharacterBody2D
@export var SPEED: int=50
@export var CHASE_SPEED: int = 150
@export var xSP: int = 300

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
	left_bounds = self.position + Vector2(-300,0)
	right_bounds = self.position + Vector2(300,0)

func _physics_process(delta: float) -> void:
	handle_gravity(delta)
	enemy_movement(delta)
	change_direction()
	collide_player()
	
func collide_player():
	if ray_cast_2d.is_colliding():
		var collider = ray_cast_2d.get_collider()
		if collider == dummy_target:
			chase_player()
		elif current_state == States.CHASE:
			stop_chase()
	elif current_state == States.CHASE:
		stop_chase()
		
func chase_player()->void:
	timer.stop()
	current_state = States.CHASE

func stop_chase() -> void:
	if timer.time_left <=0:
		timer.start()
	
	
	
func enemy_movement(delta:float) -> void:
	if current_state == States.PATROL:
		velocity = velocity.move_toward(direction * SPEED, xSP* delta)
	elif current_state == States.CHASE:
		velocity = velocity.move_toward(direction * CHASE_SPEED,	xSP* delta)
	move_and_slide()
	
	
func change_direction() -> void:
	if current_state == States.PATROL:
		if animated_sprite_2d.flip_h:
			if self.position.x <= right_bounds.x:
				direction = Vector2(1,0)
			else:
				animated_sprite_2d.flip_h = false
				ray_cast_2d.target_position = Vector2(-1000,0)
		else:
			if self.position.x >= left_bounds.x:
				direction = Vector2(-1,0)
			else:
				animated_sprite_2d.flip_h = true
				ray_cast_2d.target_position = Vector2(1000,0)
	elif current_state == States.CHASE:
		direction = (dummy_target.position - self.position).normalized()
		direction = sign(direction)
		if direction.x == 1:
			animated_sprite_2d.flip_h =true
			ray_cast_2d.target_position = Vector2(1000,0)
		else:
			animated_sprite_2d.flip_h=false
			ray_cast_2d.target_position=Vector2(-1000,0)
	
func handle_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity*delta



func _on_timer_timeout():
	current_state = States.PATROL
	
	
