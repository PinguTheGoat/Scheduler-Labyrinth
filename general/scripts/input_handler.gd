## Centralized input handler for consistent input management
extends Node

class_name InputHandler

## Signal emitted when answer is submitted (for fill-in or multiple choice)
signal answer_submitted(answer: int)

## Signal emitted for navigational inputs
signal navigate_back
signal navigate_forward

## Maps UI elements to input events
var input_listeners: Dictionary = {}

func _game_config() -> Node:
	return get_node_or_null("/root/GameConfig")

## Register a callback for a specific input action
func register_action(action: String, callback: Callable) -> void:
	if not input_listeners.has(action):
		input_listeners[action] = []
	input_listeners[action].append(callback)

## Unregister a callback
func unregister_action(action: String, callback: Callable) -> void:
	if input_listeners.has(action):
		input_listeners[action].erase(callback)

## Handle standardized key inputs
func handle_key_input(key_event: InputEventKey) -> bool:
	if not key_event.pressed or key_event.echo:
		return false
	
	match key_event.keycode:
		KEY_ESCAPE:
			navigate_back.emit()
			return true
		KEY_ENTER, KEY_KP_ENTER:
			answer_submitted.emit(0)
			return true
	
	# Number keys for quick selection
	var game_config: Node = _game_config()
	if game_config != null and game_config.enable_keyboard_shortcuts:
		var shortcuts: Array[int] = game_config.keyboard_shortcut_keys
		for i in range(shortcuts.size()):
			if key_event.keycode == shortcuts[i]:
				answer_submitted.emit(i)
				return true
	
	return false

## Execute all registered callbacks for an action
func trigger_action(action: String, args: Array = []) -> void:
	if input_listeners.has(action):
		for callback in input_listeners[action]:
			callback.callv(args)
