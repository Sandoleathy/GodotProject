extends Node2D
class_name Game

const RESULT_TITLE_WIN:= "你赢了"
const RESULT_TITLE_LOSE := "你输了"
const RESULT_MESSAGE_WIN := "你坚持到了倒计时结束"
const RESULT_MESSAGE_LOSE := "生命值归零"
const RESULT_OK_BUTTON_TEXT := "结束游戏"

@export_group("刷怪资源")
@export var enemy_scene: PackedScene = preload("res://scene/enemy.tscn")

@export_group("刷怪节奏")
@export_range(0, 100, 1, "or_greater") var initial_spawn_count: int = 1
@export_range(1, 20, 1, "or_greater") var spawn_count_per_tick: int = 1
@export_range(0.1, 60.0, 0.1, "or_greater") var spawn_interval: float = 1.5
@export_range(0.1, 60.0, 0.1, "or_greater") var min_spawn_interval: float = 0.6
@export_range(1, 200, 1, "or_greater") var max_alive_enemies: int = 12

@export_group("关卡UI")
@export_range(1.0, 3600.0, 1.0, "or_greater") var stage_duration: float = 60.0


@onready var player: Player = $Player
@onready var enemy_container: Node2D = $EnemyContainer
@onready var enemy_spawn_points_root: Node2D = $EnemySpawnPoints
@onready var enemy_spawn_timer: Timer = $EnemySpawnTimer

@onready var life_count_label :Label = $HUDLayer/LifeCountLabel
@onready var time_bar: Sprite2D = $HUDLayer/TimeBar
@onready var result_dialog: AcceptDialog = $HUDLayer/AcceptDialog

@onready var bgm_player: AudioStreamPlayer = $AudioContainer/BGMPlayer
@onready var result_win_sfx_player: AudioStreamPlayer = $AudioContainer/ResultWinSfxPlayer
@onready var result_lose_sfx_player: AudioStreamPlayer = $AudioContainer/ResultLoseSfxPlayer

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
	
	# 获取全部刷怪点
	_collect_enemy_spwaners()
	_configure_enemy_spwan_timer()
	_spawn_initial_enemies()
	_start_enemy_spawn_timer()
	
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
	get_tree().quit()
	
func _get_player_current_health() -> int:
	return player.get_current_health()

func _collect_enemy_spwaners() -> void:
	enemy_spawners.clear()
	
	for child in enemy_spawn_points_root.get_children():
		var spawner := child as EnemySpawner
		if spawner != null:
			# 挂载信号响应函数
			spawner.enemy_spawned_signal.connect(_on_enemy_spawn)
			# 加入生成器数组中
			enemy_spawners.append(spawner)

func _on_enemy_spawn(enemy_config: EnemyConfig, pos: Vector2) -> void:
	if enemy_config == null:
		return
	if _try_spawn_enemy(enemy_config, pos):
		return
		

func _configure_enemy_spwan_timer() -> void:
	enemy_spawn_timer.one_shot = false
	enemy_spawn_timer.wait_time = _get_current_spawn_interval()
	
	if not enemy_spawn_timer.timeout.is_connected(_on_enemy_spawn_timer_timeout):
		enemy_spawn_timer.timeout.connect(_on_enemy_spawn_timer_timeout)

func _update_spawn_interval() -> void:
	var current_interval := _get_current_spawn_interval()
	if is_equal_approx(enemy_spawn_timer.wait_time, current_interval):
		return
	
	enemy_spawn_timer.wait_time = current_interval
	
	if enemy_spawn_timer.is_stopped():
		return
	if enemy_spawn_timer.time_left <= current_interval:
		return
	
	enemy_spawn_timer.start(current_interval)
	
func _get_current_spawn_interval() -> float:
	var start_interval := maxf(spawn_interval, 0.1)
	var end_interval := minf( maxf(min_spawn_interval, 0.1), start_interval )
	
	if stage_duration <= 0.0:
		return end_interval
	
	var diffculty_ratio := 1.0 - clampf(stage_time_left / stage_duration, 0.0, 1.0)
	return lerpf(start_interval, end_interval, diffculty_ratio)
	
func _spawn_initial_enemies() -> void:
	for _spawn_index in range(initial_spawn_count):
		var spawner := _pick_global_spawner()
		if spawner == null:
			return
		spawner.spawn_enemy(1)
			
func _start_enemy_spawn_timer() -> void:
	if not _is_spawn_system_ready():
		return
	enemy_spawn_timer.start()
	
func _on_enemy_spawn_timer_timeout() -> void:
	for _spawn_index in range(spawn_count_per_tick):
		var spawner := _pick_global_spawner()
		if spawner == null:
			push_warning("没有全局可用敌人生成点")
			return
		spawner.spawn_enemy(1)

func _try_spawn_enemy(enemy_config: EnemyConfig, spawn_position: Vector2) -> bool:
	if not _is_spawn_system_ready():
		return false
	if _get_alive_enemy_count() >= max_alive_enemies:
		return false
		
	if spawn_position == null:
		return false
	
	if enemy_config == null:
		return false
	
	var enemy_instance := enemy_scene.instantiate() as Enemy
	if enemy_instance == null:
		push_warning("敌人实例化失败")
		return false
	
	enemy_container.add_child(enemy_instance)
	enemy_instance.global_position = spawn_position
	# 锁定player
	enemy_instance.setup(enemy_config, player)
	
	return true

# 修改生成系统和敌人系统时注意修改！
func _is_spawn_system_ready() -> bool:
	return (
		player != null
		and enemy_scene != null
		and not enemy_spawners.is_empty()
	)

# 随机选择一个全局生成点
func _pick_global_spawner() -> EnemySpawner:
	if enemy_spawners.is_empty():
		return null
	var enemy_global_spawners :Array[EnemySpawner] = []
	
	# 从所有spawner中找出全局spawner
	for spawner in enemy_spawners:
		if spawner.spawn_type == EnemySpawner.SPAWN_TYPE.NORMAL:
			enemy_global_spawners.append(spawner)
	if enemy_global_spawners.is_empty():
		push_warning("没有全局生成点!")
		return null
	
	var random_index := random_generator.randi_range(0, enemy_global_spawners.size() - 1)
	return enemy_global_spawners[random_index]
	
	
func _get_alive_enemy_count() -> int:
	var alive_enemy_count := 0
	
	for child in enemy_container.get_children():
		if child is Enemy:
			alive_enemy_count += 1
		
	return alive_enemy_count
