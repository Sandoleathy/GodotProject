extends Control
class_name GameSelectionMenu

@onready var level1_button: Button = $HBoxContainer/TestLevel1Button
@onready var level2_button: Button = $HBoxContainer/TestLevel2Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	level1_button.pressed.connect(_on_level1_click)
	level2_button.pressed.connect(_on_level2_click)

func _on_level1_click() -> void:
	get_tree().change_scene_to_file("res://scene/game.tscn")

func _on_level2_click() -> void:
	get_tree().change_scene_to_file("res://scene/game_test.tscn")
