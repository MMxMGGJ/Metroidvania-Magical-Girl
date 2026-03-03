class_name Player extends CharacterBody2D

func _process(delta:float) -> void:
	pass

func _physics_process(delta: float) -> void:
	velocity.x = 0
	if Input.is_action_pressed("move_left"):
		velocity.x = -250
	if Input.is_action_pressed("move_right"):
		velocity.x = 250
	velocity.y = velocity.y + 980 * delta
	move_and_slide()
	pass
