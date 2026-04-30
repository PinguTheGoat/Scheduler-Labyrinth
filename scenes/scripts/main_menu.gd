extends Control

@onready var start_button: Button = %StartButton
@onready var new_run_button: Button = %NewRunButton
@onready var about_button: Button = %AboutButton
@onready var exit_button: Button = %ExitButton
@onready var about_panel: PanelContainer = %AboutPanel
@onready var about_text: RichTextLabel = %AboutText
@onready var close_about_button: Button = %CloseAboutButton

func _ready() -> void:
	SceneManager.show_main_menu()
	$MarginContainer/Shell/LeftPanel.visible = false
	$MarginContainer/Shell/RightPanel.visible = false
	$MarginContainer/Shell/CenterColumn/TitlePanel.visible = false
	$MarginContainer/Shell/CenterColumn/FooterLabel.visible = false
	about_panel.visible = false
	_sync_start_button_label()
	about_button.grab_focus()
	_style_scene()
	_connect_buttons()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and about_panel.visible:
			_hide_about()

func _connect_buttons() -> void:
	start_button.pressed.connect(_on_start_pressed)
	new_run_button.pressed.connect(_on_new_run_pressed)
	about_button.pressed.connect(_on_about_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	close_about_button.pressed.connect(_hide_about)

func _on_start_pressed() -> void:
	SceneManager.start_new_game()

func _on_new_run_pressed() -> void:
	SceneManager.restart_run()

func _on_about_pressed() -> void:
	about_panel.visible = true
	close_about_button.grab_focus()

func _hide_about() -> void:
	about_panel.visible = false
	about_button.grab_focus()

func _on_exit_pressed() -> void:
	get_tree().quit()

func _style_scene() -> void:
	_style_panel($MarginContainer/Shell/LeftPanel, Color(0.05, 0.08, 0.12, 0.88), Color(0.40, 0.50, 0.72, 0.85))
	_style_panel($MarginContainer/Shell/CenterColumn/TitlePanel, Color(0.08, 0.11, 0.18, 0.90), Color(0.55, 0.43, 0.85, 0.92))
	_style_panel($MarginContainer/Shell/RightPanel, Color(0.05, 0.08, 0.12, 0.88), Color(0.40, 0.50, 0.72, 0.85))
	_style_panel(about_panel, Color(0.05, 0.08, 0.12, 0.96), Color(0.58, 0.46, 0.88, 0.95))

	_style_title($MarginContainer/Shell/CenterColumn/TitlePanel/TitleMargin/TitleColumn/TitleLabel, 28, Color(1.0, 0.84, 0.25, 1.0))
	_style_title($MarginContainer/Shell/CenterColumn/TitlePanel/TitleMargin/TitleColumn/SubtitleLabel, 12, Color(0.90, 0.92, 0.98, 1.0))
	_style_title($MarginContainer/Shell/CenterColumn/FooterLabel, 11, Color(0.77, 0.81, 0.90, 1.0))
	_style_title(about_panel.get_node("AboutMargin/AboutColumn/AboutLabel") as Label, 22, Color(1.0, 0.86, 0.36, 1.0))
	_style_title(about_text, 13, Color(0.92, 0.95, 0.99, 1.0))

	_style_button(start_button, Color(0.16, 0.43, 0.75, 1.0), Color(0.08, 0.18, 0.34, 1.0))
	_style_button(new_run_button, Color(0.66, 0.36, 0.12, 1.0), Color(0.36, 0.16, 0.05, 1.0))
	_style_button(about_button, Color(0.24, 0.29, 0.40, 1.0), Color(0.10, 0.12, 0.16, 1.0))
	_style_button(exit_button, Color(0.24, 0.29, 0.40, 1.0), Color(0.10, 0.12, 0.16, 1.0))
	_style_button(close_about_button, Color(0.24, 0.29, 0.40, 1.0), Color(0.10, 0.12, 0.16, 1.0))

	for node_path in [
		"MarginContainer/Shell/CenterColumn/ButtonStack/StartButton",
		"MarginContainer/Shell/CenterColumn/ButtonStack/NewRunButton",
		"MarginContainer/Shell/CenterColumn/ButtonStack/AboutButton",
		"MarginContainer/Shell/CenterColumn/ButtonStack/ExitButton",
		"AboutPanel/AboutMargin/AboutColumn/CloseAboutButton"
	]:
		var button: Button = get_node(node_path) as Button
		button.custom_minimum_size = Vector2(0, 30)
		button.add_theme_font_size_override("font_size", 15)

func _style_panel(panel: Control, background: Color, border: Color) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)

func _style_button(button: Button, normal_color: Color, pressed_color: Color) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = normal_color
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.80, 0.85, 1.0, 0.7)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("focus", normal)

	var pressed: StyleBoxFlat = StyleBoxFlat.new()
	pressed.bg_color = pressed_color
	pressed.border_width_left = 2
	pressed.border_width_top = 2
	pressed.border_width_right = 2
	pressed.border_width_bottom = 2
	pressed.border_color = Color(1.0, 0.92, 0.60, 0.85)
	pressed.corner_radius_top_left = 8
	pressed.corner_radius_top_right = 8
	pressed.corner_radius_bottom_left = 8
	pressed.corner_radius_bottom_right = 8
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.78, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.92, 0.70, 1.0))

func _style_title(label: Control, font_size: int, color: Color) -> void:
	if label is Label:
		var typed_label: Label = label as Label
		typed_label.add_theme_font_size_override("font_size", font_size)
		typed_label.add_theme_color_override("font_color", color)
	elif label is RichTextLabel:
		var typed_rich: RichTextLabel = label as RichTextLabel
		typed_rich.add_theme_font_size_override("normal_font_size", font_size)
		typed_rich.add_theme_color_override("default_color", color)

func _sync_start_button_label() -> void:
	var has_progress: bool = (
		SceneManager.current_stage_index > 0
		or SceneManager.wizard_quest_started
		or SceneManager.wizard_reward_claimed
		or SceneManager.player_hearts < SceneManager.max_player_hearts
	)
	# If the player has saved progress, show 'LOAD GAME' and reveal the New Run button.
	start_button.text = "LOAD GAME" if has_progress else "START"
	new_run_button.visible = has_progress
