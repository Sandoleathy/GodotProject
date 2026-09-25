extends Node2D
class_name EnemySpawner

enum SPAWN_TYPE {
	NORMAL,
	SPAWN_WHEN_CLOSE,
}

@export_group("刷怪资源")
@export var spawn_type: SPAWN_TYPE = SPAWN_TYPE.NORMAL
@export var enemy_configs :Array[EnemyConfig] = [
	preload("res://resources/config/enemy_basic.tres"),
	preload("res://resources/config/enemy_bomber.tres"),
	preload("res://resources/config/enemy_fast.tres"),
	preload("res://resources/config/enemy_shelled.tres")
]

@export_group("刷怪参数(仅当非NORMAL模式时有用)")
# 用于接近刷怪，进入范围内开始刷怪
@export_range(1.0, 50.0, 0.5, "or_greater") var player_detect_range: float = 20.0
# 刷怪点怪物数量，仅当有限模式时候生效
@export_range(1, 100, 1, "or_greater") var enemy_number: int = 10
# 刷怪点是否有限刷怪
@export var is_enemy_finite: bool = true
# 初始刷怪数量
@export_range(0, 100, 1, "or_greater") var initial_spawn_count: int = 1
@export_range(1, 20, 1, "or_greater") var spawn_count_per_tick: int = 1
@export_range(0.1, 60.0, 0.1, "or_greater") var spawn_interval: float = 1.5
@export_range(0.1, 60.0, 0.1, "or_greater") var min_spawn_interval: float = 0.6

var random_generator: RandomNumberGenerator = RandomNumberGenerator.new()
# 已经生成的敌人数量
var enemy_spawned_count: int = 0
var availiable_enemy_configs: Array[EnemyConfig] = []

signal enemy_spawned_signal(enemy: EnemyConfig, spawn_position: Vector2)

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var detect_range: Area2D = $DetectRange
@onready var detect_collision_shape: CollisionShape2D = $DetectRange/CollisionShape2D
@onready var enemt_spawn_timer: Timer = $Timer

func spawn_enemy(number: int = 1) -> void:
	for i in range(number):
		_emit_game_to_spawn_enemy()

func _ready() -> void:
	random_generator.randomize()
	_collect_availiable_enemy_config()
	_init_enemy_spawn_timer()

func _process(delta: float) -> void:
	_update_spawn_interval()

# 将非法config排除
func _collect_availiable_enemy_config() -> void:
	for config in enemy_configs:
		if config != null:
			availiable_enemy_configs.append(config)

# 随机选择一个可用的enemy config
func _pick_enemy_config() -> EnemyConfig:
	var index := random_generator.randi_range(0, availiable_enemy_configs.size() - 1)
	return availiable_enemy_configs[index]
	
# 选择好config后给Game脚本发号，生成实例交给Game来做
func _emit_game_to_spawn_enemy() -> void:
	if spawn_point == null:
		return
	var enemy_config := _pick_enemy_config()
	if enemy_config == null:
		push_warning("enemy config 无效")
		return
	
	# 传递生成点
	var enemy_pos = spawn_point.global_position
	# 将信号发送给主场景的container
	enemy_spawned_signal.emit(enemy_config, enemy_pos)

func _update_spawn_interval() -> void:
	var current_interval := _get_current_spawn_interval()
	if is_equal_approx(enemt_spawn_timer.wait_time, current_interval):
		return
	
	enemt_spawn_timer.wait_time = current_interval
	
	if enemt_spawn_timer.is_stopped():
		return
	if enemt_spawn_timer.time_left <= current_interval:
		return
	
	enemt_spawn_timer.start(current_interval)
	
func _get_current_spawn_interval() -> float:
	return spawn_interval
	
func _init_enemy_spawn_timer() -> void:
	enemt_spawn_timer.one_shot = false
	enemt_spawn_timer.wait_time = _get_current_spawn_interval()
