extends Node
class_name EnemyManager

@onready var enemy_spawn_points_root = $EnemySpawnPoints
@onready var enemy_container = $EnemyContainer
@onready var enemy_global_spawn_timer = $EnemySpawnTimer

@export_group("刷怪资源")
@export var enemy_scene: PackedScene = preload("res://scene/enemy.tscn")

@export_group("刷怪节奏")
@export_range(0, 100, 1, "or_greater") var initial_spawn_count: int = 1
@export_range(1, 20, 1, "or_greater") var spawn_count_per_tick: int = 1
@export_range(0.1, 60.0, 0.1, "or_greater") var spawn_interval: float = 1.5
@export_range(0.1, 60.0, 0.1, "or_greater") var min_spawn_interval: float = 0.6
@export_range(1, 200, 1, "or_greater") var max_alive_enemies: int = 12
# 0-1 的难度系数，暂时用于刷新人生成间隔
@export_range(0, 1.0, 0.1, "prefer_slider") var diffculty_ratio: float = 1.0

# 所有生成器的列表
var enemy_spawners: Array[EnemySpawner] = []
# 随机数生成器
var random_generator: RandomNumberGenerator = RandomNumberGenerator.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 获取所有生成点
	# 生成初始敌人，启动生成间隔计时器
	_collect_enemy_spwaners()
	_configure_enemy_spwan_timer()
	_spawn_initial_enemies()
	_start_enemy_spawn_timer()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_update_spawn_interval()

func _collect_enemy_spwaners() -> void:
	enemy_spawners.clear()
	
	for child in enemy_spawn_points_root.get_children():
		var spawner := child as EnemySpawner
		if spawner != null:
			# 挂载信号响应函数
			# 判断是否挂载，防止重复挂载函数
			if !spawner.enemy_spawned_signal.is_connected(_on_enemy_spawn):
				spawner.enemy_spawned_signal.connect(_on_enemy_spawn)
			# 加入生成器数组中
			enemy_spawners.append(spawner)

func _on_enemy_spawn(enemy_config: EnemyConfig, pos: Vector2) -> void:
	if enemy_config == null:
		return
	if _try_spawn_enemy(enemy_config, pos):
		return
		
# 尝试生成敌人，成失败则报错
func _try_spawn_enemy(enemy_config: EnemyConfig, spawn_position: Vector2) -> bool:
	if not _is_spawn_system_ready():
		push_warning("[EnemyManager]: 生成系统未就绪")
		return false
	if _get_alive_enemy_count() >= max_alive_enemies:
		return false
		
	if spawn_position == null:
		push_warning("[EnemyManager]: 生成点无效")
		return false
	
	if enemy_config == null:
		push_warning("[EnemyManager]: enemy config无效")
		return false
	
	var enemy_instance := enemy_scene.instantiate() as Enemy
	if enemy_instance == null:
		push_warning("[EnemyManager]: 敌人实例化失败")
		return false
	
	enemy_container.add_child(enemy_instance)
	enemy_instance.global_position = spawn_position
	# 锁定player
	enemy_instance.setup(enemy_config)
	return true
	
# 检测生成系统是否就绪
func _is_spawn_system_ready() -> bool:
	return (
		enemy_scene != null
		and not enemy_spawners.is_empty()
	)
	
func _get_alive_enemy_count() -> int:
	var alive_enemy_count := 0
	
	for child in enemy_container.get_children():
		if child is Enemy:
			alive_enemy_count += 1
		
	return alive_enemy_count

# 刷新全局生成敌人的间隔
func _update_spawn_interval() -> void:
	var current_interval := _get_current_spawn_interval()
	if is_equal_approx(enemy_global_spawn_timer.wait_time, current_interval):
		return
	
	enemy_global_spawn_timer.wait_time = current_interval
	
	if enemy_global_spawn_timer.is_stopped():
		return
	if enemy_global_spawn_timer.time_left <= enemy_global_spawn_timer.wait_time:
		return
	
	enemy_global_spawn_timer.start(current_interval)

func _get_current_spawn_interval() -> float:
	var start_interval := maxf(spawn_interval, 0.1)
	var end_interval := minf( maxf(min_spawn_interval, 0.1), start_interval )
	
	# 用线性插值计算生成间隔
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
	enemy_global_spawn_timer.start()
	
func _on_enemy_spawn_timer_timeout() -> void:
	for _spawn_index in range(spawn_count_per_tick):
		var spawner := _pick_global_spawner()
		if spawner == null:
			push_warning("没有全局可用敌人生成点")
			return
		spawner.spawn_enemy(1)
		
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
	
func _configure_enemy_spwan_timer() -> void:
	enemy_global_spawn_timer.one_shot = false
	enemy_global_spawn_timer.wait_time = _get_current_spawn_interval()
	
	if not enemy_global_spawn_timer.timeout.is_connected(_on_enemy_spawn_timer_timeout):
		enemy_global_spawn_timer.timeout.connect(_on_enemy_spawn_timer_timeout)

# 提供修改全局生成间隔的接口
func set_spawn_interval(interval: int) -> void:
	spawn_interval = interval

# 为game提供要的接口
func get_global_spawn_timer_time_left() -> float:
	if enemy_global_spawn_timer == null:
		return -1.0
	return enemy_global_spawn_timer.time_left
	
func get_current_global_spawn_timer_wait_time() -> float:
	if enemy_global_spawn_timer == null:
		return -1.0
	return enemy_global_spawn_timer.wait_time

func set_global_spawn_timer_wait_time(time: float) -> void:
	enemy_global_spawn_timer.wait_time = time

func is_global_spawn_timer_stopped() -> bool:
	return enemy_global_spawn_timer.is_stopped()
	
func start_global_spawn_timer(time: float) -> void:
	enemy_global_spawn_timer.start(time)
