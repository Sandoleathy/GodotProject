extends Node2D
class_name Game

const RESULT_TITLE_WIN:= "你赢了"
const RESULT_TITLE_LOSE := "你输了"
const RESULT_MESSAGE_WIN := "你坚持到了倒计时结束"
const RESULT_MESSAGE_LOSE := "生命值归零"
const RESULT_OK_BUTTON_TEXT := "返回主菜单"

@export_group("关卡UI")
@export_range(1.0, 3600.0, 1.0, "or_greater") var stage_duration: float = 60.0

@export_group("刷怪节奏")
@export_range(0.1, 60.0, 0.1, "or_greater") var spawn_interval: float = 1.5
@export_range(0.1, 60.0, 0.1, "or_greater") var min_spawn_interval: float = 0.6

@onready var player: Player = $Player
@onready var enemy_container: Node2D = $EnemyManager/EnemyContainer
@onready var enemy_spawn_points_root: Node2D = $EnemyManager/EnemySpawnPoints
@onready var enemy_spawn_timer: Timer = $EnemyManager/EnemySpawnTimer

@onready var life_count_label :Label = $HUDLayer/LifeCountLabel
@onready var time_bar: Sprite2D = $HUDLayer/TimeBar
@onready var result_dialog: AcceptDialog = $HUDLayer/AcceptDialog

@onready var bgm_player: AudioStreamPlayer = $AudioContainer/BGMPlayer
@onready var result_win_sfx_player: AudioStreamPlayer = $AudioContainer/ResultWinSfxPlayer
@onready var result_lose_sfx_player: AudioStreamPlayer = $AudioContainer/ResultLoseSfxPlayer
@onready var enemy_manager: EnemyManager = $EnemyManager

var random_generator: RandomNumberGenerator = RandomNumberGenerator.new()

var stage_time_left: float = 0.0
var time_bar_full_scale_x: float = 1.0
var time_bar_left_edge_x: float = 1.0
var time_bar_texture_width: float = 0.0
var is_result_displayed: bool = false
var enemy_spawners: Array[EnemySpawner] = []

func _ready() -> void:
	random_generator.randomize()
	
	_configure_result_dialog()
	_setup_hud()
	
func _process(delta: float) -> void:
	if is_result_displayed:
		return
	
	_update_stage_timer(delta)
	_update_spawn_interval()
	_update_hud()
	_check_game_result()

func _configure_result_dialog() -> void:
	result_dialog.dialog_close_on_escape = false
	result_dialog.ok_button_text = RESULT_OK_BUTTON_TEXT
	result_dialog.hide()
	
	if not result_dialog.confirmed.is_connected(_on_result_dialog_exit_requested):
		result_dialog.confirmed.connect(_on_result_dialog_exit_requested)
	if not result_dialog.close_requested.is_connected(_on_result_dialog_exit_requested):
		result_dialog.close_requested.connect(_on_result_dialog_exit_requested)
	if not result_dialog.canceled.is_connected(_on_result_dialog_exit_requested):
		result_dialog.canceled.connect(_on_result_dialog_exit_requested)

func _setup_hud() ->void:
	stage_time_left = maxf(stage_duration, 0.0)
	time_bar_full_scale_x= time_bar.scale.x
	if time_bar.texture != null:
		time_bar_texture_width = time_bar.texture.get_width()
	if time_bar.centered:
		time_bar_left_edge_x = time_bar.position.x - (time_bar_texture_width * time_bar_full_scale_x * 0.5)
	else:
		time_bar_left_edge_x = time_bar.position.x
	
	_update_hud()

func _update_stage_timer(delta: float) ->void:
	if stage_time_left <= 0.0:
		stage_time_left = 0.0
		return
	
	stage_time_left = maxf(stage_time_left - delta, 0.0)	
	
func _update_hud() -> void:
	_update_life_count_label()
	_update_time_bar()
	
func _update_life_count_label() -> void:
	life_count_label.text = "x %d" % _get_player_current_health()
	
func _update_time_bar() -> void:
	var fill_ratio :float = 0.0
	if stage_duration > 0.0:
		fill_ratio = clampf(stage_time_left/stage_duration, 0.0, 1.0)
	time_bar.scale.x = time_bar_full_scale_x * fill_ratio
	
	if not time_bar.centered:
		time_bar.position.x = time_bar_left_edge_x
		return
		
	var current_width := time_bar_texture_width * time_bar.scale.x
	time_bar.position.x = time_bar_left_edge_x + (current_width * 0.5)
	
func _check_game_result() -> void:
	if stage_time_left <= 0.0:
		_show_result_dialog(RESULT_TITLE_WIN, RESULT_MESSAGE_WIN)
		return
	if _get_player_current_health() <= 0.0:
		_show_result_dialog(RESULT_TITLE_LOSE, RESULT_MESSAGE_LOSE)

func _show_result_dialog(title: String, message: String) -> void:
	if is_result_displayed:
		return
	
	is_result_displayed = true
	result_dialog.title = title
	result_dialog.dialog_text = message
	_play_result_audio(title)
	_stop_world()
	result_dialog.popup_centered()
	
	var ok_button := result_dialog.get_ok_button()
	if ok_button != null:
		ok_button.grab_focus()
		
func _stop_world() -> void:
	enemy_spawn_timer.stop()
	player.stop_run_time_audio()
	Engine.time_scale = 0.0
	get_tree().paused = true

func _play_result_audio(title: String) -> void:
	if bgm_player.playing:
		bgm_player.stop()
		
	if title == RESULT_TITLE_WIN:
		_play_sfx(result_win_sfx_player)
	
	if title == RESULT_TITLE_LOSE:
		_play_sfx(result_lose_sfx_player)
	
func _play_sfx(sfx: AudioStreamPlayer) -> void:
	if sfx == null or sfx.stream == null:
		return
	
	sfx.stop()
	sfx.play()

func _on_result_dialog_exit_requested() -> void:
	# 游戏结束后回到主菜单
	get_tree().change_scene_to_file("res://scene/main_menu.tscn")
	
func _get_player_current_health() -> int:
	return player.get_current_health()

func _update_spawn_interval() -> void:
	var current_interval := _get_current_spawn_interval()
	
	# 当有enemy manager时也够行游戏
	if enemy_manager == null:
		return
	
	# 对manager的timer否存在做安全检查
	if enemy_manager.get_current_global_spawn_timer_wait_time() < 0:
		return
		
	if is_equal_approx(enemy_manager.get_current_global_spawn_timer_wait_time(), current_interval):
		return
	
	enemy_manager.set_global_spawn_timer_wait_time(current_interval)
	
	if enemy_manager.is_global_spawn_timer_stopped():
		return
	if enemy_manager.get_global_spawn_timer_time_left() <= enemy_manager.get_current_global_spawn_timer_wait_time():
		return
	
	enemy_manager.start_global_spawn_timer(current_interval)
	
func _get_current_spawn_interval() -> float:
	var start_interval := maxf(spawn_interval, 0.1)
	var end_interval := minf( maxf(min_spawn_interval, 0.1), start_interval )
	
	if stage_duration <= 0.0:
		return end_interval
	
	var diffculty_ratio := 1.0 - clampf(stage_time_left / stage_duration, 0.0, 1.0)
	return lerpf(start_interval, end_interval, diffculty_ratio)
	
