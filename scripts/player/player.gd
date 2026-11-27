extends CharacterBody2D
class_name Player
## Basic 2D pixel-art platformer player controller.
##
## Uses Godot's CharacterBody2D physics body with move_and_slide() for smooth
## horizontal movement, jumping with coyote time and jump buffering, gravity,
## ground detection, animation switching, out-of-bounds respawning, and
## shared Input Map support across keyboard, touchscreen, and gamepads.

const GAMEPLAY_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"jump"]

@export_group("Movement")
## Maximum horizontal running speed in pixels per second.
@export var move_speed: float = 135.0
## How quickly the player accelerates on the ground (pixels/sec^2).
@export var acceleration: float = 1200.0
## How quickly the player slows down when no movement key is held (pixels/sec^2).
@export var friction: float = 1400.0
## Horizontal acceleration while airborne (pixels/sec^2).
@export var air_acceleration: float = 900.0

@export_group("Jumping & Gravity")
## Initial upward velocity when jumping (negative Y points up in Godot 2D).
@export var jump_velocity: float = -320.0
## Downward gravitational acceleration in pixels/sec^2.
@export var gravity: float = 980.0
## Maximum downward falling speed to keep falls controllable.
@export var max_fall_speed: float = 520.0
## Grace period (seconds) to still allow jumping after walking off a ledge.
@export var coyote_time: float = 0.1
## Memory window (seconds) for a jump press made just before landing.
@export var jump_buffer_time: float = 0.1

@export_group("Safety & Respawn")
## Fallback Y coordinate below which the player respawns automatically.
@export var fall_limit_y: float = 600.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

## Position where the player spawns and respawns after falling out of bounds.
var spawn_position: Vector2 = Vector2.ZERO
var _was_on_floor: bool = false
var _is_landing: bool = false
var _last_air_vy: float = 0.0
var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _has_jumped: bool = false


func _ready() -> void:
	spawn_position = global_position
	_was_on_floor = is_on_floor()
	animated_sprite.animation_finished.connect(_on_animation_finished)
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	animated_sprite.play("idle")


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)


func _physics_process(delta: float) -> void:
	# 1. Track grounded grace period (coyote time) and apply gravity in the air.
	if is_on_floor():
		_coyote_timer = coyote_time
		_has_jumped = false
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		_last_air_vy = velocity.y

	# 2. Record jump input into the jump buffer, or count the buffer down.
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	# 3. Consume a buffered jump only when grounded or inside coyote time (never double-jump).
	var can_coyote_jump: bool = _coyote_timer > 0.0 and not _has_jumped
	if _jump_buffer_timer > 0.0 and (is_on_floor() or can_coyote_jump):
		velocity.y = jump_velocity
		_has_jumped = true
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		_is_landing = false
		_last_air_vy = velocity.y

	# 4. Read horizontal input (-1.0 for left, 0.0 for none, +1.0 for right).
	var direction: float = Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		var accel: float = acceleration if is_on_floor() else air_acceleration
		velocity.x = move_toward(velocity.x, direction * move_speed, accel * delta)
		animated_sprite.flip_h = direction < 0.0
		# Cancel the landing crouch immediately if the player starts moving.
		if is_on_floor():
			_is_landing = false
	else:
		var decel: float = friction if is_on_floor() else air_acceleration * 0.5
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)

	# 5. Move the CharacterBody2D and resolve platform collisions.
	move_and_slide()

	# 6. Detect genuine landing transition (was actually falling -> floor now).
	var on_floor_now: bool = is_on_floor()
	if on_floor_now and not _was_on_floor:
		if _last_air_vy > 100.0 and absf(velocity.x) < 10.0 and animated_sprite.sprite_frames.has_animation("land"):
			_is_landing = true
			animated_sprite.play("land")
		_last_air_vy = 0.0
	elif not on_floor_now:
		_is_landing = false
	_was_on_floor = on_floor_now

	# 7. Update the visible animation to match current physics state.
	_update_animation()

	# 8. Safety fallback respawn if the player falls below the level bounds.
	if global_position.y > fall_limit_y:
		respawn()


func _update_animation() -> void:
	if not is_on_floor():
		if velocity.y < 0.0:
			_play_if_not_playing("jump")
		else:
			_play_if_not_playing("fall")
		return

	if _is_landing:
		return

	# Check actual horizontal velocity so pushing against a wall keeps the player idle,
	# while even gentle analog-stick movement still animates running.
	if absf(velocity.x) > 4.0:
		_play_if_not_playing("run")
	else:
		_play_if_not_playing("idle")


func _play_if_not_playing(anim_name: StringName) -> void:
	if animated_sprite.animation != anim_name:
		animated_sprite.play(anim_name)


func _on_animation_finished() -> void:
	if animated_sprite.animation == &"land":
		_is_landing = false


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if connected:
		return
	# Clear any action left active by a controller that disconnected mid-input,
	# without interrupting keyboard keys, touch controls, or other controllers.
	for action_name: StringName in GAMEPLAY_ACTIONS:
		if not Input.is_action_pressed(action_name):
			continue
		if _is_keyboard_holding_action(action_name):
			continue
		if _is_touch_holding_action(action_name):
			continue
		if _is_other_joypad_holding_action(action_name):
			continue
		Input.action_release(action_name)


func _is_keyboard_holding_action(action_name: StringName) -> bool:
	for ev: InputEvent in InputMap.action_get_events(action_name):
		if ev is InputEventKey:
			var key_ev := ev as InputEventKey
			if key_ev.physical_keycode != KEY_NONE and Input.is_physical_key_pressed(key_ev.physical_keycode):
				return true
			if key_ev.keycode != KEY_NONE and Input.is_key_pressed(key_ev.keycode):
				return true
	return false


func _is_touch_holding_action(action_name: StringName) -> bool:
	if not is_inside_tree():
		return false
	for node: Node in get_tree().get_nodes_in_group("touch_controls"):
		if node.has_method("is_action_held") and node.is_action_held(action_name):
			return true
	return false


func _is_other_joypad_holding_action(action_name: StringName) -> bool:
	var deadzone: float = InputMap.action_get_deadzone(action_name)
	for dev: int in Input.get_connected_joypads():
		for ev: InputEvent in InputMap.action_get_events(action_name):
			if ev is InputEventJoypadButton:
				var jb := ev as InputEventJoypadButton
				if (jb.device == -1 or jb.device == dev) and Input.is_joy_button_pressed(dev, jb.button_index):
					return true
			elif ev is InputEventJoypadMotion:
				var jm := ev as InputEventJoypadMotion
				if jm.device == -1 or jm.device == dev:
					var axis_val: float = Input.get_joy_axis(dev, jm.axis)
					if signf(axis_val) == signf(jm.axis_value) and absf(axis_val) >= deadzone:
						return true
	return false


## Sets a new respawn point (used by the level's SpawnPoint).
func set_spawn_position(pos: Vector2) -> void:
	spawn_position = pos


## Resets the player to the spawn position, clears velocity/timers, and restores default facing.
func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	_is_landing = false
	_was_on_floor = false
	_last_air_vy = 0.0
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_has_jumped = false
	animated_sprite.flip_h = false
	animated_sprite.play("idle")
