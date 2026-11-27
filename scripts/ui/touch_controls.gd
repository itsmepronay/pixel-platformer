extends CanvasLayer
## On-screen touch controls for mobile (and touch-emulated desktop testing).
##
## Uses Godot's TouchScreenButton nodes bound to the shared Input Map actions
## ("move_left", "move_right", "jump") so mobile touch and desktop keyboard
## drive the exact same player logic.

@onready var left_button: TouchScreenButton = $HudRoot/BottomLeft/LeftButton
@onready var right_button: TouchScreenButton = $HudRoot/BottomLeft/RightButton
@onready var jump_button: TouchScreenButton = $HudRoot/BottomRight/JumpButton

## Tracks actions currently held via touch so focus-loss cleanup never
## interferes with keyboard input.
var _held_touch_actions: Dictionary = {}


func _ready() -> void:
	add_to_group("touch_controls")
	_connect_button(left_button, &"move_left")
	_connect_button(right_button, &"move_right")
	_connect_button(jump_button, &"jump")
	visibility_changed.connect(_on_visibility_changed)


func is_action_held(action_name: StringName) -> bool:
	return _held_touch_actions.has(action_name)


func _connect_button(button: TouchScreenButton, action_name: StringName) -> void:
	if button == null:
		return
	button.pressed.connect(func() -> void:
		_held_touch_actions[action_name] = true
	)
	button.released.connect(func() -> void:
		_held_touch_actions.erase(action_name)
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all_touch_actions()


func _exit_tree() -> void:
	_release_all_touch_actions()


func _on_visibility_changed() -> void:
	if not visible:
		_release_all_touch_actions()


func _release_all_touch_actions() -> void:
	for action_name: StringName in _held_touch_actions.keys():
		if Input.is_action_pressed(action_name):
			Input.action_release(action_name)
	_held_touch_actions.clear()
