extends KinematicBody2D
##From TheoTheTorch:
# This character controller was created with the intent of being a decent starting point for Platformers.
#
# Instead of teaching the basics, I tried to implement more advanced considerations.
# That's why I call it 'Movement 2'. This is a sequel to learning demos of similar a kind.
# Beyond coyote time and a jump buffer I go through all the things listed in the following video:
# https://www.youtube.com/watch?v=2S3g8CgBG1g
# Except for separate air and ground acceleration, as I don't think it's necessary.


# BASIC MOVEMENT VARIABLES ---------------- #
var velocity := Vector2(0,0)
var face_direction := 1

export(float, 0, 1) var run_threshold: float = 0.8  # in [0.1] set to 0 to disable walk detection
export var max_walk_speed: float = 100.0
export var max_run_speed: float = 280.0
export var acceleration: float = 2016.0
export var turning_acceleration : float = 6720.0
export var deceleration: float = 2240.0
# ------------------------------------------ #

# GRAVITY ----- #
export var gravity_acceleration : float = 1920.0
export var gravity_max : float = 510.0
# ------------- #

# JUMP VARIABLES ------------------- #
export var jump_force : float = 600.0
export var jump_cut : float = 0.25
export var jump_gravity_max : float = 500.0
export var jump_hang_treshold : float = 2.0
export var jump_hang_gravity_mult : float = 0.1
# Timers
export var jump_coyote : float = 0.08
export var jump_buffer : float = 0.1

var jump_coyote_timer : float = 0
var jump_buffer_timer : float = 0
var is_jumping := false
# ----------------------------------- #

signal jump


# All inputs we want to keep track of
func get_input() -> Dictionary:
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	return {
		"x": move.x,
		"y": move.y,
		"just_jump": Input.is_action_just_pressed("action1"),
		"jump": Input.is_action_pressed("action1"),
		"released_jump": Input.is_action_just_released("action1"),
		"walk": Input.is_action_pressed("action2"),
	}


func _physics_process(delta: float) -> void:
	x_movement(delta)
	jump_logic(delta)
	apply_gravity(delta)

	timers(delta)
	apply_velocity()


func apply_velocity() -> void:
	if is_jumping:
		velocity = move_and_slide(velocity, Vector2.UP)
	else:
		velocity = move_and_slide_with_snap(velocity, Vector2(0, 16), Vector2.UP)


func x_movement(delta: float) -> void:
	var x_val = get_input().x
	var x_abs = abs(x_val)
	var x_sign = sign(x_val)
	var x_int = int(ceil(x_abs) * x_sign)
	var is_walking = x_abs < run_threshold or get_input().walk

	# Brake if we're not doing movement inputs or slowing to walk
	if x_abs <= 0.1 or (is_walking and abs(velocity.x) >= max_walk_speed):
		velocity.x = Vector2(velocity.x, 0).move_toward(Vector2.ZERO, deceleration * delta).x
		return

	var does_input_dir_follow_momentum = sign(velocity.x) == x_sign

	# If we are doing movement inputs and above max speed, don't accelerate nor decelerate
	# Except if we are turning or walking
	# (This keeps our momentum gained from outside or slopes)
	if not is_walking and abs(velocity.x) >= max_run_speed and does_input_dir_follow_momentum:
		return

	# Are we turning?
	# Deciding between acceleration and turn_acceleration
	var accel_rate : float = acceleration if does_input_dir_follow_momentum else turning_acceleration

	# Accelerate
	velocity.x += x_val * accel_rate * delta

	set_direction(round(x_int)) # This is purely for visuals


func set_direction(hor_direction) -> void:
	# This is purely for visuals
	# Turning relies on the scale of the player
	# To animate, only scale the sprite
	if hor_direction == 0:
		return
	apply_scale(Vector2(hor_direction * face_direction, 1)) # flip
	face_direction = hor_direction # remember direction


func jump_logic(_delta: float) -> void:
	# Reset our jump requirements
	if is_on_floor():
		jump_coyote_timer = jump_coyote
		is_jumping = false
	if get_input().just_jump:
		jump_buffer_timer = jump_buffer

	# Jump if grounded, there is jump input, and we aren't jumping already
	if jump_coyote_timer > 0 and jump_buffer_timer > 0 and not is_jumping:
		is_jumping = true
		jump_coyote_timer = 0
		jump_buffer_timer = 0
		# If falling, account for that lost speed
		if velocity.y > 0:
			velocity.y -= velocity.y

		velocity.y = -jump_force
		emit_signal("jump")
		get_node("JumpSound").play()

	# We're not actually interested in checking if the player is holding the jump button
#	if get_input().jump:pass

	# Cut the velocity if let go of jump. This means our jumpheight is variable
	# This should only happen when moving upwards, as doing this while falling would lead to
	# The ability to stutter our player mid falling
	if get_input().released_jump and velocity.y < 0:
		velocity.y -= (jump_cut * velocity.y)

	# This way we won't start slowly descending / floating once hit a ceiling
	# The value added to the threshold is arbitrary,
	# But it solves a problem where jumping into
	if is_on_ceiling(): velocity.y = jump_hang_treshold + 100.0


func apply_gravity(delta: float) -> void:
	var applied_gravity : float = 0

	# No gravity if we are grounded
	if jump_coyote_timer > 0:
		return

	# Normal gravity limit
	if velocity.y <= gravity_max:
		applied_gravity = gravity_acceleration * delta

	# If moving upwards while jumping, the limit is jump_gravity_max to achieve lower gravity
	if (is_jumping and velocity.y < 0) and velocity.y > jump_gravity_max:
		applied_gravity = 0

	# Lower the gravity at the peak of our jump (where velocity is the smallest)
	if is_jumping and abs(velocity.y) < jump_hang_treshold:
		applied_gravity *= jump_hang_gravity_mult

	velocity.y += applied_gravity


func timers(delta: float) -> void:
	# Using timer nodes here would mean unnecessary functions and node calls
	# This way everything is contained in just 1 script with no node requirements
	jump_coyote_timer -= delta
	jump_buffer_timer -= delta

