## Enhanced scene management utilities
extends Node

class_name SceneController

## Scene paths
const MAIN_MENU: String = "res://scenes/main_menu.tscn"
const BATTLE: String = "res://scenes/battle_scene.tscn"
const FIRST_LEVEL: String = "res://levels/00_forest/01.tscn"

## Signal emitted before scene transition
signal transitioning_to(scene: String)

## Signal emitted after scene is loaded
signal transitioned_to(scene: String)

## Quick navigation to main menu
func goto_main_menu() -> void:
	transitioning_to.emit(MAIN_MENU)
	get_tree().change_scene_to_file(MAIN_MENU)
	await get_tree().process_frame
	transitioned_to.emit(MAIN_MENU)

## Quick navigation to first level
func goto_first_level() -> void:
	transitioning_to.emit(FIRST_LEVEL)
	get_tree().change_scene_to_file(FIRST_LEVEL)
	await get_tree().process_frame
	transitioned_to.emit(FIRST_LEVEL)

## Load scene asynchronously with loading indicator
func load_scene_async(scene_path: String) -> bool:
	transitioning_to.emit(scene_path)
	ResourceLoader.load_threaded_request(scene_path)
	
	while ResourceLoader.is_threaded_loading():
		await get_tree().process_frame
	
	var scene = ResourceLoader.take_threaded_load(scene_path)
	if scene and scene is PackedScene:
		get_tree().root.add_child(scene.instantiate())
		transitioned_to.emit(scene_path)
		return true
	
	return false

## Check if a scene exists
func scene_exists(scene_path: String) -> bool:
	return ResourceLoader.exists(scene_path, "PackedScene")

## Get current scene name
func get_current_scene_name() -> String:
	return get_tree().current_scene.name

## Reload current scene
func reload_current_scene() -> void:
	var current = get_tree().current_scene.scene_file_path
	transitioning_to.emit(current)
	get_tree().reload_current_scene()
	await get_tree().process_frame
	transitioned_to.emit(current)
