extends Control

# Expected scene tree:
# BattleScene (Control)
# └── CenterContainer
#     └── Panel
#         └── InnerMargin
#             └── VBoxContainer
#                 ├── StageLabel (Label)
#                 ├── HeartsLabel (Label)
#                 ├── PromptLabel (Label)
#                 ├── ProcessScroll (ScrollContainer)
#                 │   └── ProcessTable (VBoxContainer)
#                 ├── GanttChart (Control, script: gantt_chart.gd)
#                 ├── FeedbackLabel (Label)
#                 ├── SolutionLabel (RichTextLabel)
#                 ├── SubmitButton (Button)
#                 └── NextQuestionTimer (Timer)

signal battle_finished(stage_type: String, player_won: bool, player_hearts_remaining: int)
signal battle_cancelled(stage_type: String, player_hearts_remaining: int, enemy_hearts_remaining: int)

const FCFSGenerator = preload("res://scenes/scripts/fcfs_generator.gd")
const PriorityGenerator = preload("res://scenes/scripts/priority_generator.gd")
const RoundRobinGenerator = preload("res://scenes/scripts/round_robin_generator.gd")

@onready var stage_label: Label = %StageLabel
@onready var hearts_label: Label = %HeartsLabel
@onready var prompt_label: Label = %PromptLabel
@onready var process_table: VBoxContainer = %ProcessTable
@onready var process_scroll: ScrollContainer = %ProcessScroll
@onready var gantt_chart: Control = %GanttChart
@onready var feedback_label: Label = %FeedbackLabel
@onready var explanation_toggle: CheckButton = %ExplanationToggle
@onready var solution_label: RichTextLabel = %SolutionLabel
@onready var submit_button: Button = %SubmitButton
@onready var back_button: Button = %BackButton
@onready var explanation_button: Button = %ExplanationButton
@onready var explanation_overlay: Panel = %ExplanationOverlay
@onready var explanation_text: RichTextLabel = %ExplanationText
@onready var explanation_back_button: Button = %ExplanationBackButton
@onready var next_question_timer: Timer = %NextQuestionTimer

@export var starting_player_hearts: int = 3
@export var starting_enemy_hearts: int = 3
@export var reveal_duration: float = 2.0
@export var detailed_explanations_enabled: bool = true

var _stage_type: String = "fcfs"
var _player_hearts: int = 3
var _enemy_hearts: int = 3
var _current_problem: Dictionary = {}
var _answer_input: LineEdit
var _cell_font_size: int = 10
var _header_font_size: int = 10
var _row_height: float = 18.0
var _question_metric: String = "waiting"
var _awaiting_next_question: bool = false
var _last_answer_was_correct: bool = false
var _has_answer_result: bool = false
var _last_guess: String = ""
var _last_correct: String = ""
var _latest_explanation_text: String = ""
var _questions_answered: int = 0
var _current_question_type: String = "fill_blank"  # fill_blank, multiple_choice, ordering
var _selected_answer_text: String = ""
var _choice_buttons: Array[Button] = []

func _game_config() -> Node:
	return get_node_or_null("/root/GameConfig")

func _ready() -> void:
	next_question_timer.wait_time = reveal_duration
	next_question_timer.timeout.connect(_on_next_question_timeout)
	submit_button.pressed.connect(_on_submit_pressed)
	explanation_toggle.toggled.connect(_on_explanation_toggle_toggled)
	back_button.pressed.connect(_on_back_pressed)
	explanation_button.pressed.connect(_on_explanation_pressed)
	explanation_back_button.pressed.connect(_on_explanation_back_pressed)
	_style_back_button()
	_style_action_buttons()
	_style_explanation_overlay()
	explanation_toggle.button_pressed = detailed_explanations_enabled
	explanation_overlay.visible = false
	explanation_button.disabled = true
	resized.connect(_on_resized)
	_on_resized()

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	# Handle Enter/Return to submit
	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		if explanation_overlay.visible:
			return
		if _awaiting_next_question:
			_generate_question()
			get_viewport().set_input_as_handled()
		elif _current_question_type == "fill_blank" and _answer_input and _answer_input.text.is_valid_int():
			_submit_answer()
			get_viewport().set_input_as_handled()
	
	# Handle number keys for quick choice selection
	var game_config: Node = _game_config()
	if game_config != null and game_config.enable_keyboard_shortcuts and (_current_question_type == "multiple_choice" or _current_question_type == "ordering"):
		var shortcuts: Array[int] = game_config.keyboard_shortcut_keys
		for i in range(min(shortcuts.size(), _choice_buttons.size())):
			if key_event.keycode == shortcuts[i]:
				_on_choice_button_pressed(str(_choice_buttons[i].text))
				get_viewport().set_input_as_handled()
				break

func _on_resized() -> void:
	# Keep UI readable on the logical 480x270 viewport while staying crisp on 1440x810 window scale.
	var w: float = size.x
	var h: float = size.y
	if w < 520 or h < 300:
		_cell_font_size = 9
		_header_font_size = 8
		_row_height = 14
	else:
		_cell_font_size = 10
		_header_font_size = 9
		_row_height = 18

	prompt_label.add_theme_font_size_override("font_size", _cell_font_size + 1)
	prompt_label.max_lines_visible = 2
	hearts_label.add_theme_font_size_override("font_size", _cell_font_size + 1)
	stage_label.add_theme_font_size_override("font_size", _cell_font_size + 2)
	feedback_label.add_theme_font_size_override("font_size", _cell_font_size + 1)
	explanation_toggle.add_theme_font_size_override("font_size", _cell_font_size)
	explanation_button.add_theme_font_size_override("font_size", _cell_font_size)
	explanation_back_button.add_theme_font_size_override("font_size", _cell_font_size)
	submit_button.add_theme_font_size_override("font_size", _cell_font_size + 1)
	submit_button.custom_minimum_size = Vector2(0, 22)
	back_button.add_theme_font_size_override("font_size", _cell_font_size + 1)
	back_button.custom_minimum_size = Vector2(0, 22)

	if not _current_problem.is_empty():
		_build_process_table(_current_problem)

func setup_battle(stage_type: String, player_hearts: int = -1, enemy_hearts: int = -1) -> void:
	_stage_type = stage_type.to_lower()
	_player_hearts = starting_player_hearts if player_hearts < 0 else player_hearts
	if enemy_hearts >= 0:
		_enemy_hearts = enemy_hearts
	else:
		var game_config: Node = _game_config()
		_enemy_hearts = starting_enemy_hearts if game_config == null else game_config.get_scaled_enemy_hearts()
	_awaiting_next_question = false
	_last_answer_was_correct = false
	_has_answer_result = false
	_latest_explanation_text = ""
	_questions_answered = 0
	_selected_answer_text = ""
	_current_question_type = "fill_blank"
	_clear_choice_buttons()
	submit_button.text = "Submit Answer"
	feedback_label.text = ""
	solution_label.text = ""
	explanation_button.disabled = true
	explanation_overlay.visible = false
	back_button.disabled = false
	_generate_question()

func _generate_question() -> void:
	_awaiting_next_question = false
	_last_answer_was_correct = false
	_has_answer_result = false
	_latest_explanation_text = ""
	_selected_answer_text = ""
	_clear_choice_buttons()
	submit_button.text = "Submit Answer"
	_current_problem = _generate_problem()
	if _current_problem.is_empty():
		feedback_label.text = "Unable to generate question."
		return

	var algorithm: String = _current_problem.get("algorithm", _stage_type)
	stage_label.text = "Battle Stage: %s" % algorithm
	var enemy_name: String = _enemy_name_for_stage(_stage_type)
	hearts_label.text = "Player HP: %d   Enemy (%s) HP: %d" % [_player_hearts, enemy_name, _enemy_hearts]

	_build_process_table(_current_problem)
	gantt_chart.call("set_chart", _current_problem["gantt"], int(_current_problem["gantt_blank_index"]))

	var stage_tip: String = str(_current_problem.get("difficulty_tip", ""))
	if _current_question_type == "ordering":
		prompt_label.text = "Which process executes FIRST in the CPU schedule? (Check the Gantt chart below)"
	elif _current_question_type == "multiple_choice":
		prompt_label.text = str(_current_problem.get("question_prompt", "Choose the correct answer from the options below."))
	else:
		prompt_label.text = "Fill the missing %s value for the blank table cell." % _metric_label(_question_metric).to_lower()
	if not stage_tip.is_empty():
		prompt_label.text += "\n" + stage_tip
	feedback_label.text = ""
	solution_label.text = ""
	explanation_button.disabled = true
	explanation_overlay.visible = false
	if _current_question_type == "fill_blank":
		submit_button.text = "Submit Answer"
	else:
		submit_button.text = "Choose a Button"
	submit_button.disabled = false
	back_button.disabled = false
	_build_question_choices(_current_problem)
	if _current_question_type == "fill_blank" and _answer_input:
		_answer_input.editable = true
		_answer_input.grab_focus()

func _on_back_pressed() -> void:
	battle_cancelled.emit(_stage_type, _player_hearts, _enemy_hearts)

func _on_explanation_toggle_toggled(enabled: bool) -> void:
	detailed_explanations_enabled = enabled
	if _has_answer_result:
		_latest_explanation_text = _build_explanation_text(_last_answer_was_correct, _last_guess, _last_correct)
		explanation_text.text = _latest_explanation_text

func _on_explanation_pressed() -> void:
	if _latest_explanation_text.is_empty():
		return
	explanation_text.text = _latest_explanation_text
	explanation_text.scroll_to_line(0)
	explanation_overlay.visible = true

func _on_explanation_back_pressed() -> void:
	explanation_overlay.visible = false

func _style_back_button() -> void:
	var button_normal: StyleBoxFlat = StyleBoxFlat.new()
	button_normal.bg_color = Color(0.12, 0.15, 0.21, 1.0)
	button_normal.border_width_left = 1
	button_normal.border_width_top = 1
	button_normal.border_width_right = 1
	button_normal.border_width_bottom = 1
	button_normal.border_color = Color(0.30, 0.36, 0.48, 1.0)
	button_normal.corner_radius_top_left = 6
	button_normal.corner_radius_top_right = 6
	button_normal.corner_radius_bottom_left = 6
	button_normal.corner_radius_bottom_right = 6
	back_button.add_theme_stylebox_override("normal", button_normal)
	back_button.add_theme_stylebox_override("hover", button_normal)
	back_button.add_theme_stylebox_override("pressed", button_normal)
	explanation_back_button.add_theme_stylebox_override("normal", button_normal)
	explanation_back_button.add_theme_stylebox_override("hover", button_normal)
	explanation_back_button.add_theme_stylebox_override("pressed", button_normal)

func _style_action_buttons() -> void:
	var button_normal: StyleBoxFlat = StyleBoxFlat.new()
	button_normal.bg_color = Color(0.15, 0.35, 0.70, 1.0)
	button_normal.border_width_left = 1
	button_normal.border_width_top = 1
	button_normal.border_width_right = 1
	button_normal.border_width_bottom = 1
	button_normal.border_color = Color(0.40, 0.60, 0.95, 1.0)
	button_normal.corner_radius_top_left = 6
	button_normal.corner_radius_top_right = 6
	button_normal.corner_radius_bottom_left = 6
	button_normal.corner_radius_bottom_right = 6
	var button_hover: StyleBoxFlat = button_normal.duplicate()
	button_hover.bg_color = Color(0.20, 0.45, 0.80, 1.0)
	var button_disabled: StyleBoxFlat = button_normal.duplicate()
	button_disabled.bg_color = Color(0.08, 0.15, 0.35, 0.6)
	button_disabled.border_color = Color(0.20, 0.30, 0.50, 0.6)
	submit_button.add_theme_stylebox_override("normal", button_normal)
	submit_button.add_theme_stylebox_override("hover", button_hover)
	submit_button.add_theme_stylebox_override("pressed", button_normal)
	submit_button.add_theme_stylebox_override("disabled", button_disabled)
	explanation_button.add_theme_stylebox_override("normal", button_normal)
	explanation_button.add_theme_stylebox_override("hover", button_hover)
	explanation_button.add_theme_stylebox_override("pressed", button_normal)
	explanation_button.add_theme_stylebox_override("disabled", button_disabled)

func _style_explanation_overlay() -> void:
	var overlay_style: StyleBoxFlat = StyleBoxFlat.new()
	overlay_style.bg_color = Color(0.05, 0.08, 0.12, 0.96)
	overlay_style.border_width_left = 1
	overlay_style.border_width_top = 1
	overlay_style.border_width_right = 1
	overlay_style.border_width_bottom = 1
	overlay_style.border_color = Color(0.40, 0.56, 0.86, 0.92)
	overlay_style.corner_radius_top_left = 8
	overlay_style.corner_radius_top_right = 8
	overlay_style.corner_radius_bottom_left = 8
	overlay_style.corner_radius_bottom_right = 8
	explanation_overlay.add_theme_stylebox_override("panel", overlay_style)

func _build_process_table(problem: Dictionary) -> void:
	for child in process_table.get_children():
		if is_instance_valid(child):
			child.queue_free()

	_answer_input = null

	var processes: Array = problem["processes"]
	var process_count: int = processes.size()
	var waiting_times: Dictionary = problem["waiting_times"]
	var turnaround_times: Dictionary = problem["turnaround_times"]
	var completion_times: Dictionary = problem.get("completion_times", {})
	var has_priority: bool = _stage_type == "priority"
	var show_input: bool = _current_question_type == "fill_blank"
	var compact_mode: bool = process_count >= 5
	var table_row_height: float = 10.0 if compact_mode else _row_height
	var table_font_size: int = 7 if compact_mode else _cell_font_size
	var table_header_size: int = 7 if compact_mode else _header_font_size
	var table_separation: int = 1 if compact_mode else 2
	process_scroll.custom_minimum_size = Vector2(0, 42 if compact_mode else 50)

	var headers: Array[String] = ["P", "AT", "BT"]
	if has_priority:
		headers.append("PR")
	headers.append("CT")
	headers.append("TAT")
	headers.append("WT")
	var col_width: int = _get_table_col_width(headers.size())
	process_table.custom_minimum_size = Vector2.ZERO
	_add_table_row(headers, true, false, -1, col_width)

	var blank_index: int = int(problem["blank_index"])
	for i in range(processes.size()):
		var p: Dictionary = processes[i]
		var row_values: Array[String] = [str(p["name"]), str(p["arrival"]), str(p["burst"])]
		if has_priority:
			row_values.append(str(p["priority"]))

		var completion_value: String = str(int(completion_times.get(p["name"], 0)))
		var turnaround_value: String = str(turnaround_times[p["name"]])
		var waiting_value: String = str(waiting_times[p["name"]])

		var completion_col: int = row_values.size()
		row_values.append("?" if i == blank_index and _question_metric == "completion" else completion_value)
		var turnaround_col: int = row_values.size()
		row_values.append("?" if i == blank_index and _question_metric == "turnaround" else turnaround_value)
		var waiting_col: int = row_values.size()
		row_values.append("?" if i == blank_index and _question_metric == "waiting" else waiting_value)

		var input_col: int = -1
		if i == blank_index and show_input:
			match _question_metric:
				"completion":
					input_col = completion_col
				"turnaround":
					input_col = turnaround_col
				_:
					input_col = waiting_col

		_add_table_row(row_values, false, i == blank_index and show_input, input_col, col_width, table_row_height, table_font_size, table_header_size, table_separation)

	process_scroll.scroll_horizontal = 0

func _get_table_col_width(col_count: int) -> int:
	var usable_width: float = process_scroll.size.x
	if usable_width <= 0.0:
		usable_width = process_scroll.get_parent_area_size().x
	if usable_width <= 0.0:
		usable_width = process_scroll.custom_minimum_size.x
	if usable_width <= 0.0:
		usable_width = 420.0
	usable_width = maxf(280.0, usable_width - 8.0)
	return maxi(48, int(usable_width / maxi(1, col_count)))

func _add_table_row(values: Array, is_header: bool, has_input: bool = false, input_col: int = -1, col_width: int = 52, row_height: float = -1.0, cell_font_size: int = -1, header_font_size: int = -1, separation: int = -1) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 2 if separation < 0 else separation)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	process_table.add_child(row)

	for i in range(values.size()):
		if has_input and i == input_col:
			var line_edit: LineEdit = LineEdit.new()
			line_edit.placeholder_text = "?"
			line_edit.text = ""
			line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
			line_edit.custom_minimum_size = Vector2(maxi(36, col_width - 6), _row_height if row_height < 0.0 else row_height)
			line_edit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			line_edit.max_length = 3
			line_edit.add_theme_font_size_override("font_size", _cell_font_size if cell_font_size < 0 else cell_font_size)
			line_edit.text_submitted.connect(_on_answer_submitted)
			row.add_child(line_edit)
			_answer_input = line_edit
			continue

		var label: Label = Label.new()
		label.text = str(values[i])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.custom_minimum_size = Vector2(col_width, _row_height if row_height < 0.0 else row_height)
		label.clip_text = true
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", (_header_font_size if header_font_size < 0 else header_font_size) if is_header else (_cell_font_size if cell_font_size < 0 else cell_font_size))
		if is_header:
			label.add_theme_color_override("font_color", Color(0.30, 0.50, 0.95))
		row.add_child(label)

func _on_submit_pressed() -> void:
	_submit_answer()

func _on_answer_submitted(_text: String) -> void:
	_submit_answer()

func _submit_answer() -> void:
	if _awaiting_next_question:
		_generate_question()
		return

	if submit_button.disabled:
		return

	var answer_text: String = ""
	if _current_question_type == "fill_blank":
		if _answer_input == null:
			return
		answer_text = _answer_input.text.strip_edges()
		if not answer_text.is_valid_int():
			feedback_label.text = "❌ Error: Please enter a whole number."
			VisualEffects.flash(feedback_label, Color.RED, 0.3)
			return
	else:
		answer_text = _selected_answer_text.strip_edges()
		if answer_text.is_empty():
			# Just use the button text guidance; don't overlay message
			return

	var guess_text: String = answer_text
	var correct_text: String = str(_current_problem["correct_answer"])
	var guess: int = int(answer_text) if answer_text.is_valid_int() else 0
	var correct: int = int(_current_problem["correct_answer"]) if correct_text.is_valid_int() else 0
	_last_guess = guess_text
	_last_correct = correct_text
	_last_answer_was_correct = guess_text == correct_text
	_has_answer_result = true
	_questions_answered += 1

	submit_button.disabled = true
	if _answer_input:
		_answer_input.editable = false
	gantt_chart.call("reveal_blank")

	# Visual feedback
	if _last_answer_was_correct:
		_enemy_hearts -= 1
		var game_config: Node = _game_config()
		if game_config != null:
			game_config.scale_up_difficulty()
		feedback_label.text = "✓ Correct! Enemy loses 1 HP."
		feedback_label.add_theme_color_override("font_color", Color.GREEN)
		VisualEffects.pulse_scale(submit_button, 1.1, 0.3)
		VisualEffects.float_damage(process_table, -1, Vector2(100, -20), Color.GREEN)
	else:
		_player_hearts -= 1
		var game_config: Node = _game_config()
		if game_config != null:
			game_config.scale_down_difficulty()
		if _current_question_type == "ordering":
			feedback_label.text = "✗ Wrong. Correct process: %s\n💡 Hint: Look at which process reaches the CPU first." % correct_text
		else:
			var metric_name := _metric_label(_question_metric).to_lower()
			var hint := _get_error_hint(guess, correct, metric_name)
			feedback_label.text = "✗ Wrong. Correct %s: %d\n💡 Hint: %s" % [metric_name, correct, hint]
		feedback_label.add_theme_color_override("font_color", Color.RED)
		VisualEffects.pulse_scale(submit_button, 0.9, 0.3)
		VisualEffects.flash(process_table, Color.RED, 0.2)
		VisualEffects.float_damage(process_table, 1, Vector2(-100, -20), Color.RED)

	if _current_question_type == "fill_blank" and _answer_input:
		_answer_input.text = correct_text
	_latest_explanation_text = _build_explanation_text(_last_answer_was_correct, guess_text, correct_text)
	explanation_button.disabled = false
	
	await get_tree().process_frame

	if _enemy_hearts <= 0:
		battle_finished.emit(_stage_type, true, _player_hearts)
		return

	if _player_hearts <= 0:
		battle_finished.emit(_stage_type, false, 0)
		return

	_awaiting_next_question = true
	submit_button.text = "Next Problem"
	submit_button.disabled = false
	submit_button.grab_focus()
	_selected_answer_text = ""

func _on_choice_button_pressed(choice_text: String) -> void:
	_selected_answer_text = choice_text
	_submit_answer()

func _clear_choice_buttons() -> void:
	for button in _choice_buttons:
		if is_instance_valid(button):
			button.queue_free()
	_choice_buttons.clear()

func _build_question_choices(problem: Dictionary) -> void:
	if _current_question_type == "fill_blank":
		return

	var choices: Array[String] = []
	var correct_text: String = str(problem["correct_answer"])
	if _current_question_type == "ordering":
		choices = _build_process_name_choices(problem)
	else:
		choices = _build_numeric_choices(correct_text)

	if choices.is_empty():
		return

	var separator: Label = Label.new()
	separator.text = "Choices:"
	separator.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
	separator.add_theme_font_size_override("font_size", 14)
	process_table.add_child(separator)

	var grid: GridContainer = GridContainer.new()
	grid.columns = maxi(1, choices.size())
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	process_table.add_child(grid)

	for choice_text in choices:
		var button: Button = Button.new()
		button.text = choice_text
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 22)
		button.add_theme_font_size_override("font_size", 12)
		button.pressed.connect(_on_choice_button_pressed.bind(choice_text))
		button.add_theme_stylebox_override("normal", _choice_button_style(Color(0.15, 0.35, 0.70, 1.0), Color(0.40, 0.60, 0.95, 1.0)))
		button.add_theme_stylebox_override("hover", _choice_button_style(Color(0.20, 0.45, 0.80, 1.0), Color(0.55, 0.72, 1.0, 1.0)))
		button.add_theme_stylebox_override("pressed", _choice_button_style(Color(0.15, 0.35, 0.70, 1.0), Color(0.40, 0.60, 0.95, 1.0)))
		button.add_theme_stylebox_override("disabled", _choice_button_style(Color(0.08, 0.15, 0.35, 0.6), Color(0.20, 0.30, 0.50, 0.6)))
		grid.add_child(button)
		_choice_buttons.append(button)

func _choice_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = border_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

func _build_numeric_choices(correct_text: String) -> Array[String]:
	if not correct_text.is_valid_int():
		return []

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var correct_value: int = int(correct_text)
	var candidates: Array[int] = [correct_value]
	while candidates.size() < 4:
		var delta: int = rng.randi_range(-4, 4)
		if delta == 0:
			continue
		var candidate: int = maxi(0, correct_value + delta)
		if not candidates.has(candidate):
			candidates.append(candidate)

	candidates.shuffle()
	var result: Array[String] = []
	for value in candidates:
		result.append(str(value))
	return result

func _build_process_name_choices(problem: Dictionary) -> Array[String]:
	var processes: Array = problem.get("processes", [])
	var names: Array[String] = []
	for process in processes:
		var name: String = str(process.get("name", ""))
		if not name.is_empty():
			names.append(name)
	if names.is_empty():
		return []
	names.shuffle()
	if names.size() > 4:
		names = names.slice(0, 4)
	var correct_text: String = str(problem["correct_answer"])
	if not names.has(correct_text):
		names[0] = correct_text
	names.shuffle()
	return names

## Provides helpful hints for incorrect answers
func _get_error_hint(guess: int, correct: int, metric: String) -> String:
	if guess < correct:
		return "%s is too low (you got %d, need %d)" % [metric, guess, correct]
	else:
		return "%s is too high (you got %d, need %d)" % [metric, guess, correct]

func _build_explanation_text(is_correct: bool, guess: String, correct: String) -> String:
	var lines: Array[String] = []
	var show_detailed: bool = detailed_explanations_enabled or is_correct
	lines.append("Solution walkthrough:" if show_detailed else "Solution summary:")
	if _stage_type == "round_robin":
		lines.append("Quantum = %d" % int(_current_problem.get("quantum", 0)))
	if _current_question_type == "ordering":
		lines.append("Answer type: process selection")
	lines.append("Your answer: %s" % guess)
	lines.append("Correct answer: %s" % correct)
	if not is_correct:
		if _current_question_type == "ordering":
			lines.append("Why wrong: the first CPU slice goes to the process that appears first in the schedule.")
		else:
			lines.append("Why wrong: the value in the blank cell must satisfy the scheduling formula and Gantt timing below.")

	var gantt: Array = _current_problem.get("gantt", [])
	if show_detailed and not gantt.is_empty():
		lines.append("Gantt timeline:")
		for slot in gantt:
			var label: String = str(slot.get("label", "?"))
			var start: int = int(slot.get("start", 0))
			var finish: int = int(slot.get("end", 0))
			lines.append("- %s: %d -> %d" % [label, start, finish])

	var processes: Array = _current_problem["processes"]
	var waiting_times: Dictionary = _current_problem["waiting_times"]
	var turnaround_times: Dictionary = _current_problem["turnaround_times"]
	var completion_times: Dictionary = _current_problem.get("completion_times", {})
	var blank_index: int = int(_current_problem.get("blank_index", 0))
	if blank_index >= 0 and blank_index < processes.size():
		var blank_process: Dictionary = processes[blank_index]
		var blank_name: String = str(blank_process.get("name", "P?"))
		var at: int = int(blank_process.get("arrival", 0))
		var bt: int = int(blank_process.get("burst", 0))
		var ct: int = int(completion_times.get(blank_name, 0))
		var tat: int = int(turnaround_times.get(blank_name, 0))
		var wt: int = int(waiting_times.get(blank_name, 0))
		var windows: Array[String] = []
		for slot in gantt:
			if str(slot.get("label", "")) == blank_name:
				windows.append("%d-%d" % [int(slot.get("start", 0)), int(slot.get("end", 0))])

		lines.append("")
		lines.append("Target blank: %s %s" % [blank_name, _metric_label(_question_metric)])
		if show_detailed and not windows.is_empty():
			lines.append("%s execution slices: %s" % [blank_name, ", ".join(windows)])
		lines.append("Given for %s: AT=%d, BT=%d, CT=%d, TAT=%d, WT=%d" % [blank_name, at, bt, ct, tat, wt])
		if show_detailed:
			match _question_metric:
				"completion":
					lines.append("Compute CT: finish time of %s on Gantt = %d" % [blank_name, ct])
				"turnaround":
					lines.append("Compute TAT: CT - AT = %d - %d = %d" % [ct, at, tat])
				_:
					lines.append("Compute WT: TAT - BT = %d - %d = %d" % [tat, bt, wt])
					lines.append("(equivalently WT = CT - AT - BT = %d - %d - %d = %d)" % [ct, at, bt, wt])

	lines.append("")
	lines.append("All process results:")
	for p in processes:
		var n: String = p["name"]
		lines.append("%s -> Completion: %d, Turnaround: %d, Waiting: %d" % [
			n,
			int(completion_times.get(n, 0)),
			int(turnaround_times[n]),
			int(waiting_times[n])
		])

	return "\n".join(lines)

func _show_full_solution(force_detailed: bool = false) -> void:
	# Backward-compatible wrapper; main flow uses _build_explanation_text.
	var text: String = _build_explanation_text(force_detailed, _last_guess, _last_correct)
	solution_label.text = text
	solution_label.scroll_to_line(0)
	hearts_label.text = "Player HP: %d   Enemy (%s) HP: %d" % [_player_hearts, _enemy_name_for_stage(_stage_type), _enemy_hearts]

func _on_next_question_timeout() -> void:
	_generate_question()

func _generate_problem() -> Dictionary:
	var problem: Dictionary = {}
	match _stage_type:
		"fcfs":
			problem = FCFSGenerator.generate()
		"priority":
			problem = PriorityGenerator.generate()
		"round_robin":
			problem = RoundRobinGenerator.generate()
		_:
			problem = FCFSGenerator.generate()

	if problem.is_empty():
		return problem

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	_current_question_type = _pick_question_mode(rng)

	var metrics: Array[String] = []
	match _stage_type:
		"fcfs":
			# Keep Stage 1 focused on a single core concept.
			metrics = ["waiting"]
		"priority":
			# Stage 2 asks for ordering-aware results.
			metrics = ["completion", "turnaround"]
		"round_robin":
			# Stage 3 focuses on multi-slice execution reasoning.
			metrics = ["waiting", "turnaround"]
		_:
			metrics = ["completion", "turnaround", "waiting"]

	var processes: Array = problem["processes"]
	var blank_index: int = int(problem["blank_index"])
	var blank_name: String = str(processes[blank_index]["name"])

	if _current_question_type == "ordering":
		_question_metric = "ordering"
		var first_process_name: String = _get_first_scheduled_process_name(problem)
		problem["correct_answer"] = first_process_name
		problem["question_prompt"] = "Which process executes first in this schedule?"
		problem["answer_choices"] = _build_process_name_choices(problem)
	else:
		_question_metric = metrics[rng.randi_range(0, metrics.size() - 1)]
		match _question_metric:
			"completion":
				problem["correct_answer"] = int(problem["completion_times"].get(blank_name, 0))
			"turnaround":
				problem["correct_answer"] = int(problem["turnaround_times"].get(blank_name, 0))
			_:
				problem["correct_answer"] = int(problem["waiting_times"].get(blank_name, 0))

		if _current_question_type == "multiple_choice":
			problem["question_prompt"] = "Choose the correct %s from the choices below." % _metric_label(_question_metric).to_lower()
			problem["answer_choices"] = _build_numeric_choices(str(problem["correct_answer"]))
		else:
			problem["question_prompt"] = "Fill the missing %s value for the blank table cell." % _metric_label(_question_metric).to_lower()

	problem["question_metric"] = _question_metric
	return problem

func _pick_question_mode(rng: RandomNumberGenerator) -> String:
	match _stage_type:
		"fcfs":
			return ["fill_blank", "multiple_choice"][rng.randi_range(0, 1)]
		"priority":
			return ["fill_blank", "multiple_choice", "ordering"][rng.randi_range(0, 2)]
		"round_robin":
			return ["fill_blank", "multiple_choice", "ordering"][rng.randi_range(0, 2)]
		_:
			return "fill_blank"

func _get_first_scheduled_process_name(problem: Dictionary) -> String:
	var gantt: Array = problem.get("gantt", [])
	for slot in gantt:
		var label: String = str(slot.get("label", ""))
		if label != "" and label != "IDLE":
			return label
	var processes: Array = problem.get("processes", [])
	if not processes.is_empty():
		return str(processes[0].get("name", "P1"))
	return "P1"

func _metric_label(metric: String) -> String:
	match metric:
		"completion":
			return "Completion"
		"turnaround":
			return "Turnaround"
		_:
			return "Waiting"

func _enemy_name_for_stage(stage_key: String) -> String:
	match stage_key:
		"fcfs":
			return "Slime FCFS"
		"priority":
			return "Priority Wisp"
		"round_robin":
			return "Clockwork Hydra"
		_:
			return "Unknown"
