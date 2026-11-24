extends SceneTree

var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _run() -> void:
	var medicine := load("res://resources/config/item_configs/medicine.tres") as ItemConfig
	var weapon := load("res://resources/config/item_configs/weapon_test.tres") as ItemConfig
	var bag := Inventory.new()
	bag.capacity = 2
	root.add_child(bag)
	_check(bag.try_add(ItemInstance.new(medicine, 13)) == 13, "药品应拆为两堆")
	_check(bag.get_item(0).count == 10 and bag.get_item(1).count == 3, "堆叠数量错误")
	_check(bag.try_add(ItemInstance.new(medicine, 10)) == 7, "满包应部分接收")
	_check(bag.try_add(ItemInstance.new(weapon)) == 0, "满包不应接收武器")
	_check(not bag.consume_one(0, -1), "错误实例ID不应扣物品")
	_check(bag.get_item(0).config == medicine, "配置引用应保留")
	bag.queue_free()

	var game := load("res://scene/game_test.tscn").instantiate() as Game
	root.add_child(game)
	current_scene = game
	var player := game.get_node("Player") as Player
	var layer := game.get_node("InventoryLayer")
	for node in game.get_node("WorldItems").get_children():
		player.global_position = node.global_position
		for frame in range(24):
			await physics_frame
	_check(player.inventory.get_used_slots() == 3, "三种地面物品应全部进入背包")
	_check(game.get_node("WorldItems").get_child_count() == 0, "拾取成功应移除地面物品")
	var med := player.inventory.get_item(0)
	_check(med != null and med.config.name == medicine.name, "第一个物品应为药品")
	player.current_health = player.max_health
	var before := med.count
	player.use_inventory_item(0, med.instance_id)
	_check(med.count == before, "满血使用药品不应扣数量")
	player.current_health = 50
	var event := InputEventAction.new()
	event.action = &"toggle_inventory"
	event.pressed = true
	layer._input(event)
	_check(paused and layer.panel.visible, "TAB应显示背包并暂停")
	layer.panel._on_inventory_slot_pressed(0)
	var use_button := layer.panel.get_node("%UseButton") as Button
	_check(not use_button.disabled, "药品使用按钮应可用")
	use_button.pressed.emit()
	_check(med.count == before - 1, "通过UI使用应消耗一个药品")
	if not DisplayServer.get_name() == "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://inventory_preview.png")
		print("界面截图：", ProjectSettings.globalize_path("user://inventory_preview.png"))
	_check(player.continue_healing_unit.is_healing, "持续回血应启动")
	player.use_inventory_item(0, med.instance_id)
	_check(med.count == before - 1, "相同持续回血尚未推进时不应重复消耗")
	layer.close_inventory()
	_check(not paused and not layer.panel.visible, "关闭背包应恢复")
	player.continue_healing_unit._process(100.0)
	_check(player.current_health > 50, "持续回血应实际回复生命值")
	var material := player.inventory.get_item(2)
	before = material.count
	player.use_inventory_item(2, material.instance_id)
	_check(material.count == before, "普通战利品不可消耗")
	game.queue_free()
	await process_frame
	var normal_game := load("res://scene/game.tscn").instantiate() as Game
	# 本段仅验证结算/UI，初始刷怪依赖 current_scene，添加到树前先关闭初始生成。
	normal_game.get_node("EnemyManager").initial_spawn_count = 0
	root.add_child(normal_game)
	current_scene = normal_game
	normal_game._process(normal_game.stage_duration + 1.0)
	_check(normal_game.is_result_displayed and paused, "正常关卡倒计时结束应显示结算并暂停")
	var normal_layer := normal_game.get_node("InventoryLayer")
	normal_layer._input(event)
	_check(not normal_layer.panel.visible and paused, "结算后TAB不应打开背包或恢复战局")
	paused = false
	Engine.time_scale = 1.0
	normal_game.queue_free()
	await process_frame
	print("物品系统检查完成，失败数：", _failures)
	quit(0 if _failures == 0 else 1)
