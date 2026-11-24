extends CanvasLayer

@export var player_path: NodePath = ^"../Player"
@onready var panel: InventoryPanel = $InventoryPanel
@onready var notice: Label = $Notice
var _player: Player
var _owns_pause: bool = false
var _notice_time: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_node(player_path) as Player
	panel.bind_player(_player)
	panel.close_requested.connect(close_inventory)
	_player.inventory_message.connect(_on_inventory_message)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_inventory") and not event.is_echo():
		if panel.visible:
			close_inventory()
		elif not get_tree().paused and not _player.is_dead:
			_owns_pause = true
			_player.stop_run_time_audio()
			get_tree().paused = true
			panel.refresh()
			panel.show()
		get_viewport().set_input_as_handled()
	elif panel.visible and event.is_action_pressed(&"pause") and not event.is_echo():
		close_inventory()
		get_viewport().set_input_as_handled()

func close_inventory() -> void:
	panel.hide()
	_player.block_shooting_until_release()
	if _owns_pause:
		_owns_pause = false
		var game := get_parent() as Game
		if game == null or not game.is_result_displayed:
			get_tree().paused = false

func _process(delta: float) -> void:
	_notice_time = maxf(_notice_time - delta, 0.0)
	notice.visible = _notice_time > 0.0 and not panel.visible

func _on_inventory_message(message: String) -> void:
	# 同一条满包提示不逐帧重置时间，UI 不改变背包数据。
	if notice.text != message or _notice_time <= 0.0:
		notice.text = message
		_notice_time = 2.0
