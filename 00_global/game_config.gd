## Central configuration autoload for Scheduler's Labyrinth
## Access globally via: GameConfig.starting_player_hearts
extends Node

# Game balance constants
var starting_player_hearts: int = 3
var starting_enemy_hearts: int = 3

# Difficulty scaling
var base_enemy_hearts: int = 3
var enemy_hearts_per_stage: float = 0.5  # Scales up by this amount per correct answer
var max_enemy_hearts: int = 8

# Timing
var reveal_duration: float = 2.0
var question_timeout: float = 30.0  # seconds before auto-submit wrong answer

# Question generation
var enable_detailed_explanations: bool = true
var question_difficulty_scale: float = 1.0  # Adjusts based on player performance

# Visual effects
var enable_screen_shake: bool = true
var enable_floating_damage: bool = true
var enable_animations: bool = true

# Input
var enable_keyboard_shortcuts: bool = true
var keyboard_shortcut_keys: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4]

# Difficulty progression
var difficulty_multiplier_per_win: float = 1.1
var difficulty_multiplier_per_loss: float = 0.9
var min_difficulty: float = 0.5
var max_difficulty: float = 2.0

func _ready() -> void:
	add_to_group("autoload")

## Resets config to default values
func reset() -> void:
	starting_player_hearts = 3
	starting_enemy_hearts = 3
	base_enemy_hearts = 3
	reveal_duration = 2.0
	question_difficulty_scale = 1.0
	difficulty_multiplier_per_win = 1.1
	difficulty_multiplier_per_loss = 0.9

## Increases difficulty after a win
func scale_up_difficulty() -> void:
	question_difficulty_scale = min(max_difficulty, question_difficulty_scale * difficulty_multiplier_per_win)

## Decreases difficulty after a loss
func scale_down_difficulty() -> void:
	question_difficulty_scale = max(min_difficulty, question_difficulty_scale * difficulty_multiplier_per_loss)

## Returns scaled enemy hearts for current difficulty
func get_scaled_enemy_hearts() -> int:
	return starting_enemy_hearts

## Returns difficulty percentage for display (0-200%)
func get_difficulty_percentage() -> int:
	return int(question_difficulty_scale * 100)

## Get keyboard key for answer index (0-based)
func get_keyboard_shortcut_for_answer(index: int) -> int:
	if index < keyboard_shortcut_keys.size():
		return keyboard_shortcut_keys[index]
	return -1
