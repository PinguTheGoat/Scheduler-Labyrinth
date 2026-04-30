extends Node2D

@onready var shortcut_transition: Node2D = $ShortcutToWizard
@onready var shortcut_area: Area2D = $ShortcutToWizard/Area2D

func _ready() -> void:
	_set_shortcut_enabled(SceneManager.is_stage_cleared("round_robin"))
	if not SceneManager.enemy_battle_finished.is_connected(_on_enemy_battle_finished):
		SceneManager.enemy_battle_finished.connect(_on_enemy_battle_finished)

func _exit_tree() -> void:
	if SceneManager.enemy_battle_finished.is_connected(_on_enemy_battle_finished):
		SceneManager.enemy_battle_finished.disconnect(_on_enemy_battle_finished)

func _on_enemy_battle_finished(stage_type: String, player_won: bool) -> void:
	if stage_type == "round_robin" and player_won:
		_set_shortcut_enabled(true)

func _set_shortcut_enabled(enabled: bool) -> void:
	shortcut_transition.visible = enabled
	shortcut_area.monitoring = enabled
	shortcut_area.monitorable = enabled
