## Visual effects utility for screen shake and floating damage
extends Node

class_name VisualEffects

static func _game_config() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("GameConfig")

## Screen shake with adjustable intensity and duration
static func shake_screen(camera: Camera2D, intensity: float = 5.0, duration: float = 0.1) -> void:
	var game_config: Node = _game_config()
	if not camera or game_config == null or not game_config.enable_screen_shake:
		return
	
	var original_offset := camera.offset
	var max_shakes := int(duration * 60.0)  # 60 FPS
	var tree := camera.get_tree()
	
	for _i in range(max_shakes):
		if not is_instance_valid(camera):
			return
		await tree.process_frame
		if is_instance_valid(camera):
			var random_offset := Vector2(
				randf_range(-intensity, intensity),
				randf_range(-intensity, intensity)
			)
			camera.offset = original_offset + random_offset
	
	if is_instance_valid(camera):
		camera.offset = original_offset

## Create floating damage number above a node
static func float_damage(parent: Node, damage: int, position: Vector2 = Vector2.ZERO, color: Color = Color.RED) -> void:
	var game_config: Node = _game_config()
	if game_config == null or not game_config.enable_floating_damage:
		return
	
	var label := Label.new()
	label.text = str(damage)
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", color)
	label.position = position
	parent.add_child(label)
	
	var tween := parent.get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_property(label, "position:y", position.y - 50, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	
	await tween.finished
	if is_instance_valid(label):
		label.queue_free()

## Pulse effect - scales up then back
static func pulse_scale(node: Node, scale_amount: float = 1.2, duration: float = 0.3) -> void:
	var game_config: Node = _game_config()
	if game_config == null or not game_config.enable_animations:
		return
	
	var original_scale: Vector2 = node.scale
	var tween := node.get_tree().create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	
	tween.tween_property(node, "scale", original_scale * scale_amount, duration / 2.0)
	tween.tween_property(node, "scale", original_scale, duration / 2.0)

## Flash effect - modulates color briefly
static func flash(node: CanvasItem, color: Color = Color.WHITE, duration: float = 0.2) -> void:
	var game_config: Node = _game_config()
	if game_config == null or not game_config.enable_animations:
		return
	
	var original_modulate := node.modulate
	var tween := node.get_tree().create_tween()
	
	tween.tween_property(node, "modulate", color, duration / 2.0)
	tween.tween_property(node, "modulate", original_modulate, duration / 2.0)

## Fade in effect
static func fade_in(node: CanvasItem, duration: float = 0.5) -> void:
	var game_config: Node = _game_config()
	if game_config == null or not game_config.enable_animations:
		return
	
	node.modulate.a = 0.0
	var tween := node.get_tree().create_tween()
	tween.tween_property(node, "modulate:a", 1.0, duration)

## Slide in from side
static func slide_in(node: Node2D, from_direction: Vector2, duration: float = 0.5) -> void:
	var game_config: Node = _game_config()
	if game_config == null or not game_config.enable_animations:
		return
	
	var target_pos := node.position
	node.position = target_pos + (from_direction * 100)
	
	var tween := node.get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position", target_pos, duration)
