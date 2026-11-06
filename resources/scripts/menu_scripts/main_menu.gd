extends Control
class_name MainMenu

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var setting_button: Button = $VBoxContainer/SettingButton

func _ready() -> void:
	# 停止暂停
	get_tree().paused = false
	start_button.pressed.connect(_on_start_button_click)
	quit_button.pressed.connect(_on_quit_button_click)
	start_button.grab_focus()
	
func _on_start_button_click() -> void:
	# 前往择关卡菜单
	get_tree().change_scene_to_file("res://scene/game_selection_menu.tscn")
	
func _on_quit_button_click() -> void:
	get_tree().quit()
