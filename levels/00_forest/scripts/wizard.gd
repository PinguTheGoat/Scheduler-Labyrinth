extends CharacterBody2D

@export var interact_distance: float = 72.0
@export var dialogue_char_delay: float = 0.02

const ENDING_OUTRO_SCENE: String = "res://scenes/ending_outro.tscn"

var _player_in_range: bool = false
var _dialogue_active: bool = false
var _is_typing: bool = false
var _current_line: String = ""
var _line_index: int = -1
var _dialogue_lines: Array[String] = []
var _reward_dialogue: bool = false
var _launch_outro_after_dialogue: bool = false

var _prompt_label: Label
var _overlay: ColorRect
var _dialogue_panel: Panel
var _dialogue_label: Label
var _continue_button: Button
var _portrait: TextureRect
var _quest_panel: Panel
var _quest_label: Label
var _typing_timer: Timer
@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_setup_world_prompt()
	_setup_dialogue_ui()
	_apply_ui_styles()

func _process(_delta: float) -> void:
	_update_player_range()
	_update_prompt()
	_update_continue_button()
	_update_quest_tracker()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("action"):
		return

	if _dialogue_active:
		if _is_typing:
			_finish_typing()
		else:
			_advance_dialogue()
		return

	if _player_in_range:
		_start_interaction()

func _setup_world_prompt() -> void:
	_prompt_label = Label.new()
	_prompt_label.text = "Press E to talk"
	_prompt_label.visible = false
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_font_size_override("font_size", 13)
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72, 1.0))
	_prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	_prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	_prompt_label.position = Vector2(-40, -34)
	add_child(_prompt_label)

func _setup_dialogue_ui() -> void:
	var root: CanvasLayer = CanvasLayer.new()
	root.layer = 40
	add_child(root)

	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.48)
	_overlay.visible = false
	root.add_child(_overlay)

	_dialogue_panel = Panel.new()
	_dialogue_panel.anchor_left = 0.08
	_dialogue_panel.anchor_top = 0.70
	_dialogue_panel.anchor_right = 0.92
	_dialogue_panel.anchor_bottom = 0.95
	_dialogue_panel.visible = false
	root.add_child(_dialogue_panel)

	_dialogue_label = Label.new()
	_dialogue_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialogue_label.offset_left = 14
	_dialogue_label.offset_top = 10
	_dialogue_label.offset_right = -14
	_dialogue_label.offset_bottom = -38
	_dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_dialogue_label.add_theme_font_size_override("font_size", 16)
	_dialogue_label.add_theme_color_override("font_color", Color(0.93, 0.96, 1.0, 1.0))
	_dialogue_panel.add_child(_dialogue_label)

	_continue_button = Button.new()
	_continue_button.anchor_left = 0.62
	_continue_button.anchor_top = 1.0
	_continue_button.anchor_right = 0.98
	_continue_button.anchor_bottom = 1.0
	_continue_button.offset_top = -30
	_continue_button.offset_bottom = -6
	_continue_button.text = "Press E to continue"
	_continue_button.disabled = true
	_continue_button.focus_mode = Control.FOCUS_NONE
	_continue_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continue_button.add_theme_font_size_override("font_size", 13)
	_continue_button.add_theme_color_override("font_color", Color(0.16, 0.18, 0.25, 1.0))
	_continue_button.visible = false
	_dialogue_panel.add_child(_continue_button)

	_portrait = TextureRect.new()
	_portrait.anchor_left = 0.36
	_portrait.anchor_top = 0.08
	_portrait.anchor_right = 0.64
	_portrait.anchor_bottom = 0.62
	_portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.visible = false
	_portrait.texture = load("res://levels/00_forest/sprites/developer.png")
	root.add_child(_portrait)

	_quest_panel = Panel.new()
	_quest_panel.anchor_left = 0.02
	_quest_panel.anchor_top = 0.02
	_quest_panel.anchor_right = 0.02
	_quest_panel.anchor_bottom = 0.02
	_quest_panel.offset_right = 232
	_quest_panel.offset_bottom = 138
	_quest_panel.clip_contents = true
	_quest_panel.visible = false
	root.add_child(_quest_panel)

	_quest_label = Label.new()
	_quest_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_quest_label.offset_left = 10
	_quest_label.offset_top = 8
	_quest_label.offset_right = -10
	_quest_label.offset_bottom = -8
	_quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_quest_label.add_theme_font_size_override("font_size", 14)
	_quest_label.add_theme_color_override("font_color", Color(0.92, 0.96, 0.98, 1.0))
	_quest_panel.add_child(_quest_label)

	_typing_timer = Timer.new()
	_typing_timer.one_shot = false
	_typing_timer.wait_time = dialogue_char_delay
	_typing_timer.timeout.connect(_on_typing_timer_timeout)
	add_child(_typing_timer)

func _apply_ui_styles() -> void:
	if _dialogue_panel:
		var dialogue_style: StyleBoxFlat = StyleBoxFlat.new()
		dialogue_style.bg_color = Color(0.08, 0.11, 0.17, 0.94)
		dialogue_style.border_width_left = 2
		dialogue_style.border_width_top = 2
		dialogue_style.border_width_right = 2
		dialogue_style.border_width_bottom = 2
		dialogue_style.border_color = Color(0.43, 0.62, 0.91, 1.0)
		dialogue_style.corner_radius_top_left = 10
		dialogue_style.corner_radius_top_right = 10
		dialogue_style.corner_radius_bottom_left = 10
		dialogue_style.corner_radius_bottom_right = 10
		_dialogue_panel.add_theme_stylebox_override("panel", dialogue_style)

	if _continue_button:
		var button_normal: StyleBoxFlat = StyleBoxFlat.new()
		button_normal.bg_color = Color(0.89, 0.93, 0.99, 1.0)
		button_normal.border_width_left = 1
		button_normal.border_width_top = 1
		button_normal.border_width_right = 1
		button_normal.border_width_bottom = 1
		button_normal.border_color = Color(0.37, 0.49, 0.75, 1.0)
		button_normal.corner_radius_top_left = 6
		button_normal.corner_radius_top_right = 6
		button_normal.corner_radius_bottom_left = 6
		button_normal.corner_radius_bottom_right = 6
		_continue_button.add_theme_stylebox_override("normal", button_normal)
		_continue_button.add_theme_stylebox_override("hover", button_normal)
		_continue_button.add_theme_stylebox_override("pressed", button_normal)

	if _quest_panel:
		var quest_style: StyleBoxFlat = StyleBoxFlat.new()
		quest_style.bg_color = Color(0.05, 0.08, 0.12, 0.86)
		quest_style.border_width_left = 2
		quest_style.border_width_top = 2
		quest_style.border_width_right = 2
		quest_style.border_width_bottom = 2
		quest_style.border_color = Color(0.30, 0.54, 0.67, 0.95)
		quest_style.corner_radius_top_left = 8
		quest_style.corner_radius_top_right = 8
		quest_style.corner_radius_bottom_left = 8
		quest_style.corner_radius_bottom_right = 8
		_quest_panel.add_theme_stylebox_override("panel", quest_style)

func _update_player_range() -> void:
	var player: Node = get_tree().get_first_node_in_group("Player")
	if player == null:
		_player_in_range = false
		return
	if not player is Node2D:
		_player_in_range = false
		return

	var player_pos: Vector2 = (player as Node2D).global_position
	_update_facing(player_pos)
	var distance_to_player: float = global_position.distance_to(player_pos)
	_player_in_range = distance_to_player <= interact_distance

func _update_facing(player_pos: Vector2) -> void:
	if _animated_sprite == null:
		return

	# Character art faces right by default, so flip when player is on the left.
	_animated_sprite.flip_h = player_pos.x < global_position.x

func _update_prompt() -> void:
	if _prompt_label == null:
		return
	_prompt_label.visible = _player_in_range and not _dialogue_active

func _update_continue_button() -> void:
	if _continue_button == null:
		return

	_continue_button.visible = _dialogue_active
	if not _dialogue_active:
		return

	if _is_typing:
		_continue_button.text = "Press E to skip"
	else:
		_continue_button.text = "Press E to continue"

func _update_quest_tracker() -> void:
	if _quest_panel:
		_quest_panel.visible = false

func _fit_quest_panel_to_text() -> void:
	if _quest_panel == null or _quest_label == null:
		return

	var line_count: int = _quest_label.text.count("\n") + 1
	var base_height: float = 20.0
	var per_line: float = 18.0
	var desired_height: float = base_height + (line_count * per_line)
	_quest_panel.offset_bottom = clampf(desired_height, 104.0, 188.0)

func _build_tracker_text() -> String:
	var labels: Array[String] = ["FCFS", "Priority", "Round Robin"]
	var lines: Array[String] = ["Quest Tracker"]
	for i in range(labels.size()):
		var done: bool = SceneManager.current_stage_index > i
		var mark: String = "[x]" if done else "[ ]"
		lines.append("%s %s" % [mark, labels[i]])

	if SceneManager.current_stage_index >= SceneManager.STAGE_ORDER.size():
		if SceneManager.wizard_reward_claimed:
			lines.append("[x] Claim reward")
		else:
			lines.append("[ ] Claim reward")

	return "\n".join(lines)

func _start_interaction() -> void:
	var stage_count: int = SceneManager.STAGE_ORDER.size()
	var stage_index: int = SceneManager.current_stage_index

	if not SceneManager.wizard_quest_started:
		SceneManager.wizard_quest_started = true
		SceneManager.save_progress()
		_start_dialogue([
			"Traveler, I have a quest for you.",
			"Defeat the trials of FCFS, Priority, and Round Robin.",
			"Return to me when all three scheduling trials are complete."
		], false)
		return

	if stage_index < stage_count:
		var remaining := _remaining_stages_text(stage_index)
		_start_dialogue([
			"Your quest is still ongoing.",
			"Remaining trial(s): %s." % remaining,
			"Come back after you clear all CPU scheduling stages."
		], false)
		return

	if not SceneManager.wizard_reward_claimed:
		SceneManager.wizard_reward_claimed = true
		SceneManager.save_progress()
		_launch_outro_after_dialogue = true
		_start_dialogue([
			"Since you finish all the CPU scheduling, I will grant you...",
			"...leb's Developer Friendship Badge!"
		], true)
		return

	_start_dialogue([
		"You already carry the Friendship Badge.",
		"Guard it well, hero of scheduling."
	], true)

func _remaining_stages_text(stage_index: int) -> String:
	var stage_labels: Dictionary = {
		"fcfs": "FCFS",
		"priority": "Priority",
		"round_robin": "Round Robin"
	}
	var remaining: Array[String] = []
	for i in range(stage_index, SceneManager.STAGE_ORDER.size()):
		var key: String = SceneManager.STAGE_ORDER[i]
		remaining.append(String(stage_labels.get(key, key)))
	return ", ".join(remaining)

func _start_dialogue(lines: Array[String], show_portrait: bool) -> void:
	_dialogue_lines = lines
	_reward_dialogue = show_portrait
	_line_index = -1
	_dialogue_active = true
	_overlay.visible = true
	_dialogue_panel.visible = true
	_continue_button.visible = true
	_portrait.visible = show_portrait
	_set_player_input_enabled(false)
	_advance_dialogue()

func _advance_dialogue() -> void:
	_line_index += 1
	if _line_index >= _dialogue_lines.size():
		_close_dialogue()
		return

	_current_line = _dialogue_lines[_line_index]
	_dialogue_label.text = ""
	_is_typing = true
	if _typing_timer.is_stopped():
		_typing_timer.start()

func _finish_typing() -> void:
	_is_typing = false
	_dialogue_label.text = _current_line
	if not _typing_timer.is_stopped():
		_typing_timer.stop()

func _on_typing_timer_timeout() -> void:
	if not _is_typing:
		_typing_timer.stop()
		return

	var next_index: int = _dialogue_label.text.length()
	if next_index >= _current_line.length():
		_finish_typing()
		return

	_dialogue_label.text += _current_line[next_index]

func _close_dialogue() -> void:
	var should_launch_outro: bool = _launch_outro_after_dialogue
	_launch_outro_after_dialogue = false
	_dialogue_active = false
	_reward_dialogue = false
	_overlay.visible = false
	_dialogue_panel.visible = false
	_continue_button.visible = false
	_portrait.visible = false
	if not _typing_timer.is_stopped():
		_typing_timer.stop()
	_set_player_input_enabled(true)
	if should_launch_outro:
		await get_tree().process_frame
		get_tree().change_scene_to_file(ENDING_OUTRO_SCENE)

func _set_player_input_enabled(enabled: bool) -> void:
	var player: Node = get_tree().get_first_node_in_group("Player")
	if player == null:
		return

	player.set_process(enabled)
	player.set_physics_process(enabled)
	player.set_process_unhandled_input(enabled)
