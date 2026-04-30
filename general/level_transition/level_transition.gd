@tool
@icon("res://general/icons/level_transition.svg")
class_name LevelTransition extends Node2D

enum SIDE {LEFT, RIGHT, TOP, BOTTOM}

@export_range(2, 16, 1, "or_greater") var size : int = 2 :
	set(value):
		size = value
		apply_area_settings()

@export var location : SIDE = SIDE.LEFT :
	set(value):
		location = value
		apply_area_settings()

@export_file("*.tscn") var target_level : String = ""
@export var target_area_name : String = "LevelTransition"
@export_range(0.0, 2.0, 0.05, "suffix:s") var arm_delay_seconds: float = 0.25
@onready var area_2d: Area2D = $Area2D
var _arrival_locked: bool = false
var _arrival_player: Node2D = null
var _is_armed: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	SceneManager.new_scene_ready.connect(_on_new_scene_ready)
	area_2d.body_entered.connect(_on_player_entered)
	area_2d.body_exited.connect(_on_body_exited)
	_arm_after_delay.call_deferred()
	pass

func _on_player_entered(body: Node2D) -> void:
	if not _is_armed:
		return
	if body == null or not body.is_in_group("Player"):
		return
	if _arrival_locked and body == _arrival_player:
		return
	if target_level.strip_edges() == "":
		return

	var offset: Vector2 = get_offset(body)
	print("Player entered transition: ", name, " at position: ", body.global_position)
	print("Transition at: ", global_position, " with location: ", location)
	print("Calculated offset: ", offset)
	print("Target level: ", target_level, " Target area: ", target_area_name)
	SceneManager.transition_scene.call_deferred(target_level, target_area_name, offset, "left")
	pass

func _on_new_scene_ready(target_name : String, offset : Vector2) -> void:
	print("New scene ready. Looking for transition area: ", target_name)
	print("This transition is named: ", name)
	if target_name == name:
		var player : Node = get_tree().get_first_node_in_group("Player")
		if player:
			print("Found player, positioning at: ", global_position, " + ", offset, " = ", global_position + offset)
			player.global_position = global_position + offset
			if player is Node2D and area_2d.overlaps_body(player):
				_arrival_locked = true
				_arrival_player = player as Node2D
			else:
				_arrival_locked = false
				_arrival_player = null
		else:
			print("ERROR: Could not find player!")
	else:
		print("Name mismatch, not positioning player")
	pass

func _on_body_exited(body: Node2D) -> void:
	if body == null:
		return
	if _arrival_locked and body == _arrival_player:
		_arrival_locked = false
		_arrival_player = null

func _arm_after_delay() -> void:
	_is_armed = false
	if arm_delay_seconds <= 0.0:
		_is_armed = true
		return
	await get_tree().create_timer(arm_delay_seconds).timeout
	_is_armed = true

func _on_load_scene_finished() -> void:
	pass

func apply_area_settings() -> void:
	area_2d = get_node_or_null("Area2D")
	if not area_2d:
		return
	if location == SIDE.LEFT or location == SIDE.RIGHT:
		area_2d.scale.y = size
		if location == SIDE.LEFT:
			area_2d.scale.x = -1
		else:
			area_2d.scale.x = 1
	else:
		if location == SIDE.TOP:
			area_2d.scale.y = 1
		else:
			area_2d.scale.y = -1
	pass

func get_offset(player : Node2D) -> Vector2:
	var offset : Vector2 = Vector2.ZERO
	var player_pos : Vector2 = player.global_position
	if location == SIDE.LEFT or location == SIDE.RIGHT:
		# Keep horizontal transitions stable even if the player enters while jumping.
		offset.y = 0.0
		if location == SIDE.LEFT:
			offset.x = -12
		else:
			offset.x = 12
	else:
		offset.x = player_pos.x - self.global_position.x
		if location == SIDE.TOP:
			offset.y = -2
		else:
			offset.y = 48
	return offset
