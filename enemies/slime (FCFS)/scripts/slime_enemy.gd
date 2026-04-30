extends Node2D

@onready var encounter_area: Area2D = $EncounterArea
@onready var status_label: Label = $StatusLabel
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

@export var death_fade_duration: float = 0.18

var _awaiting_result := false
var _is_defeated := false
var _player_in_range := false
var _death_playing := false
var _is_fading_out := false

func _ready() -> void:
	if SceneManager.is_stage_cleared("fcfs"):
		queue_free()
		return

	# If placed with negative scale in a level, normalize parent so labels don't appear mirrored.
	scale = Vector2(abs(scale.x), abs(scale.y))

	if not SceneManager.enemy_battle_finished.is_connected(_on_enemy_battle_finished):
		SceneManager.enemy_battle_finished.connect(_on_enemy_battle_finished)
	encounter_area.body_entered.connect(_on_body_entered)
	encounter_area.body_exited.connect(_on_body_exited)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	_style_status_label()
	_update_status_label()

func _process(_delta: float) -> void:
	_update_facing_to_player()

func _unhandled_input(event: InputEvent) -> void:
	if _is_defeated or _awaiting_result:
		return
	if not _player_in_range:
		return
	if event.is_action_pressed("action"):
		_start_battle()

func _on_body_entered(body: Node2D) -> void:
	if _is_defeated:
		return
	if not body.is_in_group("Player"):
		return
	_player_in_range = true
	if not _awaiting_result:
		status_label.text = "Press E to battle"

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("Player"):
		return
	_player_in_range = false
	if not _awaiting_result and not _is_defeated:
		status_label.text = "FCFS Enemy"

func _start_battle() -> void:
	if _is_defeated or _awaiting_result:
		return
	_awaiting_result = true
	encounter_area.monitoring = false
	status_label.text = "Battle started..."
	SceneManager.start_enemy_battle("fcfs")

func _on_enemy_battle_finished(_stage_type: String, player_won: bool) -> void:
	if not _awaiting_result:
		return

	_awaiting_result = false
	if player_won:
		_is_defeated = true
		_death_playing = true
		encounter_area.monitoring = false
		status_label.text = "Defeated"
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("death"):
			animated_sprite.play("death")
		else:
			queue_free()
		return

	if SceneManager.game_over:
		status_label.text = "Game Over"
		encounter_area.monitoring = false
		return

	status_label.text = "Try again"
	encounter_area.monitoring = true
	if _player_in_range:
		status_label.text = "Press E to battle"

func _update_status_label() -> void:
	if _is_defeated:
		status_label.text = "Defeated"
	else:
		status_label.text = "FCFS Enemy"

func _style_status_label() -> void:
	status_label.add_theme_font_size_override("font_size", 13)
	status_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.72, 1.0))
	status_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	status_label.add_theme_constant_override("shadow_offset_x", 1)
	status_label.add_theme_constant_override("shadow_offset_y", 1)

func _on_animation_finished() -> void:
	if _death_playing and animated_sprite.animation == "death":
		if _is_fading_out:
			return
		_is_fading_out = true
		var fade_tween: Tween = create_tween()
		fade_tween.tween_property(self, "modulate:a", 0.0, death_fade_duration)
		await fade_tween.finished
		queue_free()

func _update_facing_to_player() -> void:
	var player: Node = get_tree().get_first_node_in_group("Player")
	if player == null:
		return
	if not player is Node2D:
		return

	var player_pos: Vector2 = (player as Node2D).global_position
	# Sprite art faces right by default.
	animated_sprite.flip_h = player_pos.x > global_position.x
