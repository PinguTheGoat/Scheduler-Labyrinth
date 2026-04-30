extends Control

signal stage_started(stage_name: String)
signal stage_cleared(stage_name: String)
signal game_over(stage_name: String)
signal campaign_completed

const BATTLE_SCENE: PackedScene = preload("res://scenes/battle_scene.tscn")

const STAGES: Array[Dictionary] = [
	{"display": "Easy", "type": "fcfs"},
	{"display": "Medium", "type": "priority"},
	{"display": "Hard", "type": "round_robin"}
]

@onready var status_label: Label = %StatusLabel
@onready var battle_container: Control = %BattleContainer
@onready var action_button: Button = %ActionButton

var _current_stage_index: int = 0
var _player_hearts: int = 3

func _game_config() -> Node:
	return get_node_or_null("/root/GameConfig")

func _ready() -> void:
	action_button.pressed.connect(_on_action_button_pressed)
	var game_config: Node = _game_config()
	if game_config != null:
		game_config.reset()  # Reset difficulty for fresh campaign
	_start_current_stage()

func _start_current_stage() -> void:
	_clear_battle_container()
	if _current_stage_index >= STAGES.size():
		var game_config: Node = _game_config()
		var difficulty_value: int = 100 if game_config == null else game_config.get_difficulty_percentage()
		status_label.text = "You defeated all enemies. Campaign complete. [Difficulty: %d%%]" % difficulty_value
		action_button.text = "Restart Campaign"
		action_button.visible = true
		campaign_completed.emit()
		return

	var stage: Dictionary = STAGES[_current_stage_index]
	var game_config: Node = _game_config()
	var difficulty_indicator := "Difficulty: %d%%" % (100 if game_config == null else game_config.get_difficulty_percentage())
	status_label.text = "Stage %d/%d: %s (%s) - %s" % [
		_current_stage_index + 1,
		STAGES.size(),
		stage["display"],
		String(stage["type"]).to_upper(),
		difficulty_indicator
	]
	action_button.visible = false

	var battle: Control = BATTLE_SCENE.instantiate()
	battle_container.add_child(battle)
	battle.battle_finished.connect(_on_battle_finished)
	battle.setup_battle(stage["type"], _player_hearts)
	stage_started.emit(stage["display"])

func _on_battle_finished(stage_type: String, player_won: bool, player_hearts_remaining: int) -> void:
	if player_won:
		_player_hearts = max(1, player_hearts_remaining)
		stage_cleared.emit(stage_type)
		_current_stage_index += 1
		if _current_stage_index < STAGES.size():
			var next_stage: Dictionary = STAGES[_current_stage_index]
			var game_config: Node = _game_config()
			var difficulty_indicator := "Difficulty: %d%%" % (100 if game_config == null else game_config.get_difficulty_percentage())
			status_label.text = "Stage cleared. Next unlocked: %s (%s) - %s" % [
				next_stage["display"],
				String(next_stage["type"]).to_upper(),
				difficulty_indicator
			]
			action_button.text = "Start Next Stage"
			action_button.visible = true
		else:
			_start_current_stage()
	else:
		game_over.emit(stage_type)
		status_label.text = "Game Over on %s. Retry this stage." % String(stage_type).to_upper()
		action_button.text = "Retry Stage"
		action_button.visible = true
		_player_hearts = 3

func _on_action_button_pressed() -> void:
	if _current_stage_index >= STAGES.size():
		_current_stage_index = 0
		_player_hearts = 3
		var game_config: Node = _game_config()
		if game_config != null:
			game_config.reset()  # Reset difficulty when restarting campaign
	_start_current_stage()

func _clear_battle_container() -> void:
	for child in battle_container.get_children():
		child.queue_free()
