class_name PlayerStateCrouch extends PlayerState

@export var deceleration_rate : float = 10

func init() -> void:
	pass

func enter() -> void:
	player.animation_player.play("crouch")
	pass

func exit() -> void:
	pass

func handle_input( event : InputEvent ) -> PlayerState:
	if event.is_action_pressed("jump"):
		return jump
	return next_state

func process( delta: float ) -> PlayerState:
	if player.direction.y <= 0.5:
		return idle
	return next_state

func physics_process( delta: float ) -> PlayerState:
	player.velocity.x -= player.velocity.x * deceleration_rate * delta
	if player.is_on_floor() == false:
		return fall
	return next_state
