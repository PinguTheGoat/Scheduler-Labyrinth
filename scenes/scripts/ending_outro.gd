extends Control

@onready var credits_text: RichTextLabel = %CreditsText
@onready var hint_label: Label = %HintLabel

@export var scroll_speed: float = 28.0
@export var auto_return_delay: float = 6.0

var _finished_roll: bool = false
var _finish_timer: float = 0.0

func _ready() -> void:
	credits_text.text = _build_credits_text()
	hint_label.visible = false
	# Start below the viewport so the credits can roll upward.
	credits_text.position.y = size.y + 24.0
	set_process(true)

func _process(delta: float) -> void:
	if _finished_roll:
		_finish_timer += delta
		if _finish_timer >= auto_return_delay:
			_return_to_main_menu()
		return

	credits_text.position.y -= scroll_speed * delta
	var content_height: float = maxf(credits_text.get_content_height(), credits_text.size.y)
	var credits_bottom: float = credits_text.position.y + content_height
	if credits_bottom < -40.0:
		_finished_roll = true
		hint_label.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER or key_event.keycode == KEY_SPACE or key_event.keycode == KEY_ESCAPE:
		_return_to_main_menu()
		get_viewport().set_input_as_handled()

func _return_to_main_menu() -> void:
	if has_node("/root/SceneManager"):
		var scene_manager: Node = get_node("/root/SceneManager")
		if scene_manager.has_method("return_to_main_menu"):
			scene_manager.call("return_to_main_menu")
			return
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _build_credits_text() -> String:
	var lines: Array[String] = [
		"[center][font_size=44]Scheduler's Labyrinth[/font_size][/center]",
		"",
		"[center][font_size=24]A journey through CPU scheduling[/font_size][/center]",
		"",
		"",
		"[center][font_size=30]The Final Reward[/font_size][/center]",
		"[center]You earned the Friendship Badge.[/center]",
		"[center]The labyrinth remembers your persistence.[/center]",
		"",
		"",
		"[center][font_size=30]Created By[/font_size][/center]",
		"[center]Developed by Lebron Catubao[/center]",
		"[center]Documented by Group 3[/center]",
		"",
		"",
		"[center][font_size=30]Sprite Credits[/font_size][/center]",
		"[center]Michael Games[/center]",
		"[center]Cethiel[/center]",
		"[center]CreativeKind[/center]",
		"[center]CharmedWheat[/center]",
		"[center]rvros[/center]",
		"",
		"",
		"[center][font_size=30]Special Thanks[/font_size][/center]",
		"[center]To everyone who explored the scheduler's maze[/center]",
		"[center]and kept learning through every battle.[/center]",
		"",
		"",
		"[center][font_size=26]The End[/font_size][/center]"
	]
	return "\n".join(lines)
