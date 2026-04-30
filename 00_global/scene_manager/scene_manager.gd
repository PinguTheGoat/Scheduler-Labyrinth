extends CanvasLayer

signal load_scene_started
signal new_scene_ready(target_name : String, offset : Vector2)
signal load_scene_finished
signal battle_stage_started(stage_type: String)
signal battle_stage_cleared(stage_type: String)
signal battle_stage_failed(stage_type: String)
signal enemy_battle_finished(stage_type: String, player_won: bool)
signal game_over_changed(is_game_over: bool)

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle_scene.tscn")
const HEART_FULL_TEXTURE: Texture2D = preload("res://UI/heart_full.svg")
const HEART_EMPTY_TEXTURE: Texture2D = preload("res://UI/heart_empty.svg")
const MAIN_MENU_SCENE: String = "res://scenes/main_menu.tscn"
const START_SCENE: String = "res://levels/00_forest/01.tscn"
const STAGE_ORDER: Array[String] = ["fcfs", "priority", "round_robin"]
const SAVE_FILE_PATH: String = "user://progress.cfg"

var current_stage_index: int = 0
var player_hearts: int = 3
var max_player_hearts: int = 3
var wizard_quest_started: bool = false
var wizard_reward_claimed: bool = false
var quest_menu_visible: bool = true
var game_over: bool = false
var _battle_instance: Control
var _battle_request_type: String = ""
var _stage_enemy_hearts: Dictionary = {}
var _pending_transition: Dictionary = {
	"new_scene": "",
	"target_area": "",
	"player_offset": Vector2.ZERO,
	"dir": "left"
}
var _hud_root: Control
var _hp_panel: Panel
var _hp_hearts: HBoxContainer
var _quest_toggle_button: Button
var _quest_panel: Panel
var _quest_label: Label
var _game_over_panel: Panel
var _game_over_label: Label
var _restart_button: Button
var _pause_panel: Panel
var _pause_backdrop: ColorRect
var _pause_resume_button: Button
var _pause_restart_button: Button
var _pause_menu_button: Button
var _last_player_hearts: int = 3

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_global_hud()
	_load_progress()
	# Prewarm the heaviest level scene to reduce transition hitch.
	ResourceLoader.load_threaded_request("res://levels/00_forest/04.tscn", "PackedScene", false)
	_prewarm_dragon_textures()
	_last_player_hearts = player_hearts
	_refresh_hud()
	await get_tree().process_frame
	load_scene_finished.emit()
	pass

func _prewarm_dragon_textures() -> void:
	for directory_path in [
		"res://enemies/dragon (Round Robin)/sprite/Attack 2",
		"res://enemies/dragon (Round Robin)/sprite/Death"
	]:
		var dir_access: DirAccess = DirAccess.open(directory_path)
		if dir_access == null:
			continue

		dir_access.list_dir_begin()
		var file_name: String = dir_access.get_next()
		while file_name != "":
			if not dir_access.current_is_dir() and file_name.to_lower().ends_with(".png"):
				ResourceLoader.load_threaded_request("%s/%s" % [directory_path, file_name], "Texture2D", false)
			file_name = dir_access.get_next()
		dir_access.list_dir_end()

func _process(_delta: float) -> void:
	_refresh_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and _hud_root and _hud_root.visible and not game_over:
			_toggle_pause()
			return
		if event.keycode == KEY_Q and wizard_quest_started and not game_over:
			quest_menu_visible = not quest_menu_visible
			_refresh_hud()

func show_main_menu() -> void:
	get_tree().paused = false
	_set_pause_panel_visible(false)
	_set_gameplay_ui_visible(false)
	_refresh_hud()

func start_new_game() -> void:
	get_tree().paused = false
	_set_pause_panel_visible(false)
	_set_gameplay_ui_visible(true)
	get_tree().change_scene_to_file(START_SCENE)

func return_to_main_menu() -> void:
	# Stop active gameplay before switching scenes to avoid lingering physics (player falling)
	get_tree().paused = false
	_set_pause_panel_visible(false)
	_set_gameplay_ui_visible(false)
	# Ensure any active battle is freed and player processing paused
	if _battle_instance:
		_battle_instance.queue_free()
		_battle_instance = null
	var player: Node = get_tree().get_first_node_in_group("Player")
	if player:
		player.set_process(false)
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		if player is CanvasItem:
			(player as CanvasItem).visible = false
		player.queue_free()

	# Change to main menu and persist progress
	await get_tree().process_frame
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	save_progress()

func toggle_pause() -> void:
	_toggle_pause()

func resume_game() -> void:
	_on_pause_resume_pressed()

func save_progress() -> void:
	_save_progress()

func _save_progress() -> void:
	var save_cfg: ConfigFile = ConfigFile.new()
	save_cfg.set_value("run", "current_stage_index", current_stage_index)
	save_cfg.set_value("run", "player_hearts", player_hearts)
	save_cfg.set_value("run", "max_player_hearts", max_player_hearts)
	save_cfg.set_value("run", "wizard_quest_started", wizard_quest_started)
	save_cfg.set_value("run", "wizard_reward_claimed", wizard_reward_claimed)
	save_cfg.set_value("run", "quest_menu_visible", quest_menu_visible)
	for stage_type in STAGE_ORDER:
		save_cfg.set_value("enemy_hp", stage_type, int(_stage_enemy_hearts.get(stage_type, -1)))
	var err: Error = save_cfg.save(SAVE_FILE_PATH)
	if err != OK:
		push_warning("Failed to save progress: %s" % err)

func _load_progress() -> void:
	var save_cfg: ConfigFile = ConfigFile.new()
	var err: Error = save_cfg.load(SAVE_FILE_PATH)
	if err != OK:
		return

	current_stage_index = clampi(int(save_cfg.get_value("run", "current_stage_index", 0)), 0, STAGE_ORDER.size())
	max_player_hearts = maxi(1, int(save_cfg.get_value("run", "max_player_hearts", 3)))
	player_hearts = clampi(int(save_cfg.get_value("run", "player_hearts", max_player_hearts)), 0, max_player_hearts)
	wizard_quest_started = bool(save_cfg.get_value("run", "wizard_quest_started", false))
	wizard_reward_claimed = bool(save_cfg.get_value("run", "wizard_reward_claimed", false))
	quest_menu_visible = bool(save_cfg.get_value("run", "quest_menu_visible", true))
	_stage_enemy_hearts.clear()
	for stage_type in STAGE_ORDER:
		var saved_enemy_hp: int = int(save_cfg.get_value("enemy_hp", stage_type, -1))
		if saved_enemy_hp >= 0:
			_stage_enemy_hearts[stage_type] = saved_enemy_hp

func _setup_global_hud() -> void:
	_hud_root = Control.new()
	_hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_hud_root.visible = false
	add_child(_hud_root)

	_hp_panel = Panel.new()
	_hp_panel.anchor_left = 0.0
	_hp_panel.anchor_top = 0.0
	_hp_panel.anchor_right = 0.0
	_hp_panel.anchor_bottom = 0.0
	_hp_panel.offset_left = 10
	_hp_panel.offset_top = 10
	_hp_panel.offset_right = 180
	_hp_panel.offset_bottom = 46
	_hud_root.add_child(_hp_panel)

	var hp_style: StyleBoxFlat = StyleBoxFlat.new()
	hp_style.bg_color = Color(0.05, 0.08, 0.12, 0.78)
	hp_style.border_width_left = 2
	hp_style.border_width_top = 2
	hp_style.border_width_right = 2
	hp_style.border_width_bottom = 2
	hp_style.border_color = Color(0.42, 0.62, 0.88, 0.95)
	hp_style.corner_radius_top_left = 8
	hp_style.corner_radius_top_right = 8
	hp_style.corner_radius_bottom_left = 8
	hp_style.corner_radius_bottom_right = 8
	_hp_panel.add_theme_stylebox_override("panel", hp_style)

	_hp_hearts = HBoxContainer.new()
	_hp_hearts.anchor_left = 0.0
	_hp_hearts.anchor_top = 0.0
	_hp_hearts.anchor_right = 1.0
	_hp_hearts.anchor_bottom = 1.0
	_hp_hearts.offset_left = 10
	_hp_hearts.offset_top = 6
	_hp_hearts.offset_right = -10
	_hp_hearts.offset_bottom = -6
	_hp_hearts.alignment = BoxContainer.ALIGNMENT_CENTER
	_hp_hearts.add_theme_constant_override("separation", 6)
	_hp_panel.add_child(_hp_hearts)

	for i in range(max_player_hearts):
		var icon: TextureRect = TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(20, 20)
		icon.name = "Heart%d" % i
		_hp_hearts.add_child(icon)

	_quest_toggle_button = Button.new()
	_quest_toggle_button.anchor_left = 1.0
	_quest_toggle_button.anchor_top = 0.0
	_quest_toggle_button.anchor_right = 1.0
	_quest_toggle_button.anchor_bottom = 0.0
	_quest_toggle_button.offset_left = -148
	_quest_toggle_button.offset_top = 10
	_quest_toggle_button.offset_right = -12
	_quest_toggle_button.offset_bottom = 34
	_quest_toggle_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_quest_toggle_button.focus_mode = Control.FOCUS_NONE
	_quest_toggle_button.pressed.connect(_on_quest_toggle_pressed)
	_hud_root.add_child(_quest_toggle_button)

	_quest_panel = Panel.new()
	_quest_panel.anchor_left = 1.0
	_quest_panel.anchor_top = 0.0
	_quest_panel.anchor_right = 1.0
	_quest_panel.anchor_bottom = 0.0
	_quest_panel.offset_left = -264
	_quest_panel.offset_top = 40
	_quest_panel.offset_right = -12
	_quest_panel.offset_bottom = 150
	_quest_panel.visible = false
	_quest_panel.clip_contents = true
	_hud_root.add_child(_quest_panel)

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

	_game_over_panel = Panel.new()
	_game_over_panel.anchor_left = 0.30
	_game_over_panel.anchor_top = 0.34
	_game_over_panel.anchor_right = 0.70
	_game_over_panel.anchor_bottom = 0.66
	_game_over_panel.visible = false
	_game_over_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_game_over_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_hud_root.add_child(_game_over_panel)

	_game_over_label = Label.new()
	_game_over_label.anchor_left = 0.08
	_game_over_label.anchor_top = 0.12
	_game_over_label.anchor_right = 0.92
	_game_over_label.anchor_bottom = 0.55
	_game_over_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_game_over_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_game_over_label.add_theme_font_size_override("font_size", 24)
	_game_over_label.text = "Game Over"
	_game_over_panel.add_child(_game_over_label)

	_restart_button = Button.new()
	_restart_button.anchor_left = 0.25
	_restart_button.anchor_top = 0.66
	_restart_button.anchor_right = 0.75
	_restart_button.anchor_bottom = 0.86
	_restart_button.text = "Back to Start"
	_restart_button.pressed.connect(_on_restart_pressed)
	_game_over_panel.add_child(_restart_button)

	_pause_panel = Panel.new()
	_pause_backdrop = ColorRect.new()
	_pause_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_backdrop.color = Color(0.02, 0.03, 0.06, 0.58)
	_pause_backdrop.visible = false
	_pause_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_backdrop.process_mode = Node.PROCESS_MODE_ALWAYS
	_hud_root.add_child(_pause_backdrop)

	_pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	_pause_panel.offset_left = -190
	_pause_panel.offset_top = -125
	_pause_panel.offset_right = 190
	_pause_panel.offset_bottom = 125
	_pause_panel.visible = false
	_pause_panel.clip_contents = true
	_pause_panel.custom_minimum_size = Vector2(380, 250)
	_pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_hud_root.add_child(_pause_panel)

	var pause_style: StyleBoxFlat = StyleBoxFlat.new()
	pause_style.bg_color = Color(0.05, 0.08, 0.12, 0.92)
	pause_style.border_width_left = 2
	pause_style.border_width_top = 2
	pause_style.border_width_right = 2
	pause_style.border_width_bottom = 2
	pause_style.border_color = Color(0.35, 0.58, 0.82, 0.95)
	pause_style.corner_radius_top_left = 12
	pause_style.corner_radius_top_right = 12
	pause_style.corner_radius_bottom_left = 12
	pause_style.corner_radius_bottom_right = 12
	_pause_panel.add_theme_stylebox_override("panel", pause_style)

	var pause_layout: VBoxContainer = VBoxContainer.new()
	pause_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_layout.offset_left = 16
	pause_layout.offset_top = 14
	pause_layout.offset_right = -16
	pause_layout.offset_bottom = -14
	pause_layout.alignment = BoxContainer.ALIGNMENT_CENTER
	pause_layout.add_theme_constant_override("separation", 8)
	_pause_panel.add_child(pause_layout)

	var pause_title: Label = Label.new()
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_title.add_theme_font_size_override("font_size", 20)
	pause_title.text = "Paused"
	pause_layout.add_child(pause_title)

	var pause_hint: Label = Label.new()
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pause_hint.add_theme_font_size_override("font_size", 12)
	pause_hint.custom_minimum_size = Vector2(0, 64)
	pause_hint.text = "The game is paused. Resume, restart from the start, or return to the main menu."
	pause_layout.add_child(pause_hint)

	_pause_resume_button = Button.new()
	_pause_resume_button.text = "Resume"
	_pause_resume_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_resume_button.custom_minimum_size = Vector2(0, 26)
	_pause_resume_button.pressed.connect(_on_pause_resume_pressed)
	_style_pause_button(_pause_resume_button, Color(0.17, 0.44, 0.78, 1.0), Color(0.08, 0.20, 0.38, 1.0))
	pause_layout.add_child(_pause_resume_button)

	_pause_restart_button = Button.new()
	_pause_restart_button.text = "Back to Start"
	_pause_restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_restart_button.custom_minimum_size = Vector2(0, 26)
	_pause_restart_button.pressed.connect(_on_restart_pressed)
	_style_pause_button(_pause_restart_button, Color(0.62, 0.28, 0.20, 1.0), Color(0.34, 0.14, 0.10, 1.0))
	pause_layout.add_child(_pause_restart_button)

	_pause_menu_button = Button.new()
	_pause_menu_button.text = "Main Menu"
	_pause_menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pause_menu_button.custom_minimum_size = Vector2(0, 26)
	_pause_menu_button.pressed.connect(return_to_main_menu)
	_style_pause_button(_pause_menu_button, Color(0.26, 0.30, 0.38, 1.0), Color(0.12, 0.14, 0.18, 1.0))
	pause_layout.add_child(_pause_menu_button)

	_set_pause_panel_visible(false)
	_set_gameplay_ui_visible(false)

func _refresh_hud() -> void:
	var in_battle: bool = _battle_instance != null

	if player_hearts < _last_player_hearts:
		_animate_heart_loss(_last_player_hearts, player_hearts)
	elif player_hearts > _last_player_hearts:
		_animate_heart_gain(_last_player_hearts, player_hearts)
	_last_player_hearts = player_hearts

	_update_hp_icons()
	if _hp_panel:
		_hp_panel.visible = not in_battle
	if _quest_toggle_button:
		_quest_toggle_button.visible = wizard_quest_started and not in_battle
		_quest_toggle_button.text = "Hide Quest" if quest_menu_visible else "Show Quest"
	if _quest_panel and _quest_label:
		if wizard_quest_started and quest_menu_visible and not in_battle:
			_quest_panel.visible = true
			_quest_label.text = _build_tracker_text()
			_fit_quest_panel_to_text()
		else:
			_quest_panel.visible = false
	if _game_over_panel:
		_game_over_panel.visible = game_over

func _set_gameplay_ui_visible(should_show: bool) -> void:
	if _hud_root == null:
		return
	_hud_root.visible = should_show

func _set_pause_panel_visible(should_show: bool) -> void:
	if _pause_backdrop:
		_pause_backdrop.visible = should_show
	if _pause_panel:
		_pause_panel.visible = should_show

func _toggle_pause() -> void:
	if game_over or _hud_root == null or not _hud_root.visible:
		return
	if get_tree().paused:
		_on_pause_resume_pressed()
		return
	get_tree().paused = true
	_set_pause_panel_visible(true)

func _on_pause_resume_pressed() -> void:
	get_tree().paused = false
	_set_pause_panel_visible(false)

func _style_pause_button(button: Button, normal_color: Color, pressed_color: Color) -> void:
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = normal_color
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.border_color = Color(0.82, 0.88, 0.98, 0.72)
	normal.corner_radius_top_left = 6
	normal.corner_radius_top_right = 6
	normal.corner_radius_bottom_left = 6
	normal.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("focus", normal)

	var pressed: StyleBoxFlat = StyleBoxFlat.new()
	pressed.bg_color = pressed_color
	pressed.border_width_left = 1
	pressed.border_width_top = 1
	pressed.border_width_right = 1
	pressed.border_width_bottom = 1
	pressed.border_color = Color(1.0, 0.95, 0.78, 0.85)
	pressed.corner_radius_top_left = 6
	pressed.corner_radius_top_right = 6
	pressed.corner_radius_bottom_left = 6
	pressed.corner_radius_bottom_right = 6
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.78, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 0.93, 0.72, 1.0))

func _update_hp_icons() -> void:
	if _hp_hearts == null:
		return

	for i in range(_hp_hearts.get_child_count()):
		var icon := _hp_hearts.get_child(i) as TextureRect
		if icon == null:
			continue
		icon.texture = HEART_FULL_TEXTURE if i < player_hearts else HEART_EMPTY_TEXTURE

func _animate_heart_loss(previous_hp: int, current_hp: int) -> void:
	if _hp_hearts == null:
		return

	for i in range(current_hp, previous_hp):
		var icon := _hp_hearts.get_child(i) as TextureRect
		if icon == null:
			continue
		icon.scale = Vector2.ONE
		icon.rotation_degrees = 0.0
		icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(icon, "scale", Vector2(1.25, 1.25), 0.07)
		tw.tween_property(icon, "rotation_degrees", -10.0, 0.07)
		tw.tween_property(icon, "modulate", Color(1.0, 0.45, 0.45, 1.0), 0.07)
		tw.chain().set_parallel(true)
		tw.tween_property(icon, "scale", Vector2(0.90, 0.90), 0.09)
		tw.tween_property(icon, "rotation_degrees", 8.0, 0.09)
		tw.tween_property(icon, "modulate", Color(0.95, 0.95, 0.95, 1.0), 0.09)
		tw.chain().set_parallel(true)
		tw.tween_property(icon, "scale", Vector2.ONE, 0.08)
		tw.tween_property(icon, "rotation_degrees", 0.0, 0.08)
		tw.tween_property(icon, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.08)

func _animate_heart_gain(previous_hp: int, current_hp: int) -> void:
	if _hp_hearts == null:
		return

	for i in range(previous_hp, current_hp):
		var icon := _hp_hearts.get_child(i) as TextureRect
		if icon == null:
			continue
		icon.scale = Vector2(0.75, 0.75)
		icon.modulate = Color(0.75, 1.0, 0.78, 1.0)
		var tw: Tween = create_tween()
		tw.set_parallel(true)
		tw.tween_property(icon, "scale", Vector2(1.12, 1.12), 0.10)
		tw.tween_property(icon, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.10)
		tw.chain().tween_property(icon, "scale", Vector2.ONE, 0.08)

func _build_tracker_text() -> String:
	var labels: Array[String] = ["FCFS", "Priority", "Round Robin"]
	var lines: Array[String] = ["Quest Tracker"]
	for i in range(labels.size()):
		var done: bool = current_stage_index > i
		var mark: String = "[x]" if done else "[ ]"
		lines.append("%s %s" % [mark, labels[i]])

	if current_stage_index >= STAGE_ORDER.size():
		if wizard_reward_claimed:
			lines.append("[x] Claim reward")
		else:
			lines.append("[ ] Claim reward")

	return "\n".join(lines)

func _fit_quest_panel_to_text() -> void:
	if _quest_panel == null or _quest_label == null:
		return

	var line_count: int = _quest_label.text.count("\n") + 1
	var base_height: float = 26.0
	var per_line: float = 20.0
	var desired_height: float = base_height + (line_count * per_line)
	var clamped_height: float = clampf(desired_height, 98.0, 166.0)
	_quest_panel.offset_bottom = _quest_panel.offset_top + clamped_height

func get_stage_index(stage_type: String) -> int:
	return STAGE_ORDER.find(stage_type.to_lower())

func is_stage_cleared(stage_type: String) -> bool:
	var idx: int = get_stage_index(stage_type)
	if idx < 0:
		return false
	return current_stage_index > idx

func _on_quest_toggle_pressed() -> void:
	quest_menu_visible = not quest_menu_visible
	_refresh_hud()

func _on_restart_pressed() -> void:
	restart_to_start_scene()

func restart_to_start_scene() -> void:
	get_tree().paused = false
	_set_pause_panel_visible(false)
	_set_gameplay_ui_visible(true)
	transition_scene(START_SCENE, "BackToForest", Vector2.ZERO, "left")

func restart_run() -> void:
	_reset_run_state()
	restart_to_start_scene()

func _reset_run_state() -> void:
	current_stage_index = 0
	player_hearts = max_player_hearts
	wizard_quest_started = false
	wizard_reward_claimed = false
	quest_menu_visible = true
	_stage_enemy_hearts.clear()
	_set_game_over(false)
	_set_pause_panel_visible(false)
	_save_progress()

func _set_game_over(value: bool) -> void:
	game_over = value
	game_over_changed.emit(game_over)
	_refresh_hud()
	if game_over:
		get_tree().paused = true
		_set_pause_panel_visible(false)
		_save_progress()
	var player: Node = get_tree().get_first_node_in_group("Player")
	if player:
		player.set_process(not game_over)
		player.set_physics_process(not game_over)
		player.set_process_unhandled_input(not game_over)

func transition_with_battle(new_scene: String, target_area: String, player_offset: Vector2, dir: String) -> void:
	if _battle_instance != null:
		return
	if game_over:
		return
	_battle_request_type = "transition"

	_pending_transition = {
		"new_scene": new_scene,
		"target_area": target_area,
		"player_offset": player_offset,
		"dir": dir
	}

	if current_stage_index >= STAGE_ORDER.size():
		transition_scene.call_deferred(new_scene, target_area, player_offset, dir)
		return

	var stage_type: String = STAGE_ORDER[current_stage_index]
	var enemy_hearts_for_stage: int = int(_stage_enemy_hearts.get(stage_type, -1))
	battle_stage_started.emit(stage_type)

	_battle_instance = BATTLE_SCENE.instantiate()
	add_child(_battle_instance)
	_battle_instance.battle_finished.connect(_on_battle_finished)
	_battle_instance.battle_cancelled.connect(_on_battle_cancelled)
	_battle_instance.setup_battle(stage_type, player_hearts, enemy_hearts_for_stage)

func start_enemy_battle(requested_stage: String = "") -> void:
	if _battle_instance != null:
		return
	if game_over:
		enemy_battle_finished.emit("none", false)
		return
	_set_gameplay_ui_visible(true)

	if requested_stage.strip_edges() == "" and current_stage_index >= STAGE_ORDER.size():
		enemy_battle_finished.emit("none", true)
		return

	_battle_request_type = "encounter"
	var stage_type: String = requested_stage.to_lower().strip_edges()
	if stage_type == "":
		stage_type = STAGE_ORDER[current_stage_index]
	elif get_stage_index(stage_type) < 0:
		stage_type = STAGE_ORDER[current_stage_index]
	var enemy_hearts_for_stage: int = int(_stage_enemy_hearts.get(stage_type, -1))
	battle_stage_started.emit(stage_type)

	_battle_instance = BATTLE_SCENE.instantiate()
	add_child(_battle_instance)
	_battle_instance.battle_finished.connect(_on_battle_finished)
	_battle_instance.battle_cancelled.connect(_on_battle_cancelled)
	_battle_instance.setup_battle(stage_type, player_hearts, enemy_hearts_for_stage)

func transition_scene(new_scene : String, target_area : String, player_offset : Vector2, _dir : String) -> void:

	load_scene_started.emit()
	_set_gameplay_ui_visible(true)
	_set_pause_panel_visible(false)
	get_tree().paused = false

	await get_tree().process_frame

	var requested: Error = ResourceLoader.load_threaded_request(new_scene, "PackedScene", false)
	if requested == OK or requested == ERR_BUSY:
		var progress: Array = []
		while true:
			var status: int = ResourceLoader.load_threaded_get_status(new_scene, progress)
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				break
			if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				break
			await get_tree().process_frame

		var loaded_resource: Resource = ResourceLoader.load_threaded_get(new_scene)
		if loaded_resource is PackedScene:
			get_tree().change_scene_to_packed(loaded_resource as PackedScene)
		else:
			get_tree().change_scene_to_file(new_scene)
	else:
		get_tree().change_scene_to_file(new_scene)

	await get_tree().tree_changed
	await get_tree().process_frame
	_position_player_at_target_area(target_area, player_offset)

	new_scene_ready.emit(target_area, player_offset)

	await get_tree().process_frame
	_position_player_at_target_area(target_area, player_offset)

	load_scene_finished.emit()

	pass

func _position_player_at_target_area(target_area: String, player_offset: Vector2) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var effective_target_name: String = target_area.strip_edges()
	if effective_target_name == "":
		effective_target_name = "BackToForest"

	var target_node: Node = scene_root.find_child(effective_target_name, true, false)
	if target_node == null and effective_target_name != "BackToForest":
		target_node = scene_root.find_child("BackToForest", true, false)
	if target_node == null:
		target_node = scene_root.find_child("LevelTransition", true, false)
	if target_node == null:
		return
	if not target_node is Node2D:
		return

	var player: Node = get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	if not player is Node2D:
		return

	(player as Node2D).global_position = (target_node as Node2D).global_position + player_offset

func _on_battle_finished(stage_type: String, player_won: bool, player_hearts_remaining: int) -> void:
	if _battle_instance:
		_battle_instance.queue_free()
		_battle_instance = null

	if player_won:
		_stage_enemy_hearts.erase(stage_type)
		player_hearts = clampi(player_hearts_remaining, 1, max_player_hearts)
		var won_stage_idx: int = get_stage_index(stage_type)
		if won_stage_idx >= 0:
			current_stage_index = max(current_stage_index, won_stage_idx + 1)
		else:
			current_stage_index += 1
		battle_stage_cleared.emit(stage_type)
		if _battle_request_type == "transition":
			transition_scene.call_deferred(
				_pending_transition["new_scene"],
				_pending_transition["target_area"],
				_pending_transition["player_offset"],
				_pending_transition["dir"]
			)
		elif _battle_request_type == "encounter":
			enemy_battle_finished.emit(stage_type, true)
		_battle_request_type = ""
		_save_progress()
		return

	player_hearts = max(0, player_hearts_remaining)
	_set_game_over(player_hearts <= 0)
	battle_stage_failed.emit(stage_type)
	if _battle_request_type == "encounter":
		enemy_battle_finished.emit(stage_type, false)
	_battle_request_type = ""
	_save_progress()

func _on_battle_cancelled(stage_type: String, player_hearts_remaining: int, enemy_hearts_remaining: int) -> void:
	if _battle_instance:
		_battle_instance.queue_free()
		_battle_instance = null

	player_hearts = clampi(player_hearts_remaining, 0, max_player_hearts)
	_stage_enemy_hearts[stage_type.to_lower()] = maxi(0, enemy_hearts_remaining)
	if _battle_request_type == "encounter":
		enemy_battle_finished.emit(stage_type, false)
	_battle_request_type = ""
	_save_progress()
