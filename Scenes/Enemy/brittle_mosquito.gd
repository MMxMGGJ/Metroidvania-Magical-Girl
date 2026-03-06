extends CharacterBody2D

class_name enemy_mosquito


@export var dummy_target: CharacterBody2D
@export var SPEED: int=50
@export var CHASE_SPEED: int = 150
@export var xSP: int = 200
@export var HEALTH = 2
@export var MAX_HEALTH = 2
@export var MIN_HEALTH = 0
@export var DAMAGE = 1




var is_chasing_done = false

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var ray_cast_horizontal: RayCast2D = $AnimatedSprite2D/RayCastHorizontal
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var timer: Timer = $Timer
@onready var shape_cast_2d: ShapeCast2D = $AnimatedSprite2D/ShapeCast2D
@onready var ray_cast_vertical: RayCast2D = $AnimatedSprite2D/RayCastVertical

var direction: Vector2
var right_bounds: Vector2
var left_bounds: Vector2
var start_position: Vector2

enum States{
	PATROL,
	CHASE,
	RETURN,
	ATTACK,
	DEATH
}

var current_state = States.PATROL


func _ready():
	left_bounds = self.position + Vector2(-200,0)
	right_bounds = self.position + Vector2(200,0)
	Global.mosquitoDamage = DAMAGE
	# Global.mosquitoDamageArea = 
	start_position = global_position
	
func _physics_process(delta: float) -> void:
	#handle_animation()
	enemy_movement(delta)
	change_direction()
	collide_player()
		
#func handle_animation():
	
	
func collide_player():
	if ray_cast_horizontal.is_colliding():
		var collider = ray_cast_horizontal.get_collider()
		if collider == dummy_target:
			chase_player()
		elif current_state == States.CHASE:
			stop_chase()
	elif shape_cast_2d.is_colliding():
		for i in range(shape_cast_2d.get_collision_count()):
			var collider = shape_cast_2d.get_collider(i)
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
		is_chasing_done = false
		velocity = velocity.move_toward(direction * SPEED, xSP* delta)
	elif current_state == States.RETURN and start_position != global_position and is_chasing_done == true:
		velocity = position.direction_to(start_position) * CHASE_SPEED
		if(global_position.distance_to(start_position)<1):
			current_state = States.PATROL
	elif current_state == States.CHASE:
									 #Experimental											
		velocity = position.direction_to(dummy_target.position + Vector2(50,-50)) * CHASE_SPEED
	
	move_and_slide()
		
		
		
func change_direction() -> void:
	if current_state == States.PATROL:
		if animated_sprite_2d.flip_h:
			if self.position.x <= right_bounds.x:
				direction = Vector2(1,0)
			else:
				animated_sprite_2d.flip_h = false
				ray_cast_horizontal.target_position = Vector2(-500,0)
		else:
			if self.position.x >= left_bounds.x:
				direction = Vector2(-1,0)
			else:
				animated_sprite_2d.flip_h = true
				ray_cast_horizontal.target_position = Vector2(500,0)
	elif current_state == States.CHASE:
		direction = (dummy_target.position - self.position).normalized()
		direction = sign(direction)
		if direction.x == 1:
			animated_sprite_2d.flip_h =true
			ray_cast_horizontal.target_position = Vector2(500,0)
		else:
			animated_sprite_2d.flip_h=false
			ray_cast_horizontal.target_position=Vector2(-500,0)

func _on_timer_timeout() -> void:
	current_state = States.RETURN
	is_chasing_done = true
	
	
