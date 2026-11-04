extends Node2D
class_name EnemySpawner

enum SPAWN_TYPE {
	NORMAL,
	SPAWN_WHEN_CLOSE,
}

@export_group("刷怪资源")
@export var spawn_type: SPAWN_TYPE = SPAWN_TYPE.NORMAL
@export var enemy_configs :Array[EnemyConfig] = [
	preload("res://resources/config/enemy_configs/enemy_basic.tres"),
	preload("res://resources/config/enemy_configs/enemy_bomber.tres"),
	preload("res://resources/config/enemy_configs/enemy_fast.tres"),
	preload("res://resources/config/enemy_configs/enemy_shelled.tres")
]

@export_group("刷怪参数(仅当非NORMAL模式时有用)")
# 用于接近刷怪，进入范围内开始刷怪
@export_range(1.0, 50.0, 0.5, "or_greater") var player_detect_range: float = 20.0
# 刷怪点怪物数量，仅当有限模式时候生效
@export_range(1, 100, 1, "or_greater") var enemy_number: int = 10
# 单次刷怪限
@export_range(1, 5, 1, "or_greater") var max_enemy_per_spawn: int = 2
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
var is_spawning_enemy: bool = false

signal enemy_spawned_signal(enemy: EnemyConfig, spawn_position: Vector2)

@onready var spawn_point: Marker2D = $SpawnPoint
@onready var detect_range: Area2D = $DetectRange
@onready var detect_collision_shape: CollisionShape2D = $DetectRange/CollisionShape2D
@onready var enemy_spawn_timer: Timer = $Timer

func spawn_enemy(number: int = 1) -> void:
	if enemy_spawned_count + number > enemy_number:
		number = enemy_number - enemy_spawned_count
	for i in range(number):
		if _emit_game_to_spawn_enemy():
			enemy_spawned_count += number

func _ready() -> void:
	random_generator.randomize()
	_collect_availiable_enemy_config()
	_init_enemy_spawn_timer()
	_init_spawner_detect_range()

func _process(delta: float) -> void:
	_update_spawn_interval()
	# _process_enemy_spawn()

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
func _emit_game_to_spawn_enemy() -> bool:
	if not is_instance_valid(spawn_point):
		push_warning("spawn point 无效")
		return false
	var enemy_config := _pick_enemy_config()
	if enemy_config == null:
		push_warning("enemy config 无效")
		return false
	
	# 传递生成点
	var enemy_pos = spawn_point.global_position
	# 将信号发送给主场景的container
	enemy_spawned_signal.emit(enemy_config, enemy_pos)
	return true

func _update_spawn_interval() -> void:
	if !is_spawning_enemy:
		enemy_spawn_timer.paused = true
		return
	if enemy_number <= enemy_spawned_count:
		enemy_spawn_timer.stop()
		return
	
	if enemy_spawn_timer.paused == true:
		enemy_spawn_timer.paused = false
	
	# 如果计时器停止，则开启新一轮计时
	if enemy_spawn_timer.is_stopped():
		enemy_spawn_timer.start(_get_current_spawn_interval())
		
func _get_current_spawn_interval() -> float:
	return spawn_interval
	
func _init_enemy_spawn_timer() -> void:
	enemy_spawn_timer.one_shot = true
	enemy_spawn_timer.wait_time = _get_current_spawn_interval()
	if !enemy_spawn_timer.timeout.is_connected(_on_enemy_spawn_timer_timeout):
		enemy_spawn_timer.timeout.connect(_on_enemy_spawn_timer_timeout)

# 生成计时器到时间后生成敌人逻辑（仅适用于非NORMAL情况，否则生成敌人与否由game.gd控制）
func _on_enemy_spawn_timer_timeout() -> void:
	var rng_enemy_number = random_generator.randi_range(1, max_enemy_per_spawn)
	spawn_enemy(rng_enemy_number)
	
func _init_spawner_detect_range() -> void:
	if detect_range == null:
		return
		
	var circle := detect_collision_shape.shape as CircleShape2D
	if circle == null:
		return
	# 如果资源不是本场景独占的，就复制一份
	if not circle.resource_local_to_scene:
		circle = circle.duplicate() as CircleShape2D
		detect_collision_shape.shape = circle
	circle.radius = player_detect_range
	
	detect_range.body_entered.connect(_on_detect_area_enter)
	detect_range.body_exited.connect(_on_detect_area_exit)
	
func _on_detect_area_enter(body: Node2D) -> void:
	var player = body as Player
	if player != null:
		is_spawning_enemy = true
		# enemy_spawn_timer.paused = false

func _on_detect_area_exit(body: Node2D) -> void:
	var player = body as Player
	if player != null:
		# 停止生成敌人
		is_spawning_enemy = false	
		# enemy_spawn_timer.paused = true

	
