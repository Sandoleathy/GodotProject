extends SceneTree

var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)

func _loc(index: int) -> Dictionary:
	return {"section": &"base", "index": index}

func _run() -> void:
	var medicine := load("res://resources/config/item_configs/medicine.tres") as ItemConfig
	var weapon := load("res://resources/config/item_configs/weapon_test.tres") as ItemConfig
	var bag := Inventory.new()
	bag.base_capacity = 2
	root.add_child(bag)
	_check(bag.try_add(ItemInstance.new(medicine, 13)) == 13, "药品应拆为两堆")
	_check(bag.get_item(0).count == 10 and bag.get_item(1).count == 3, "堆叠数量错误")
	_check(bag.try_add(ItemInstance.new(medicine, 10)) == 7, "满包应部分接收")
	_check(bag.try_add(ItemInstance.new(weapon)) == 0, "满包不应接收武器")
	_check(not bag.consume_one(0, -1), "错误实例ID不应扣物品")
	bag.queue_free()

	var game := load("res://scene/game_test.tscn").instantiate() as Game
	root.add_child(game)
	current_scene = game
	var player := game.get_node("Player") as Player
	var layer := game.get_node("InventoryLayer")
	var interaction := player.item_interaction
	var inventory := player.inventory
	var world := game.get_node("WorldItems")
	await physics_frame
	_check(inventory.capacity == 4 and inventory.get_used_slots() == 0, "基础4格，靠近不会自动拾取")
	var original_world_count := world.get_child_count()
	for node in world.get_children():
		if node.config is EquipmentConfig:
			continue
		player.global_position = node.global_position
		player.pickup_interactor._refresh_target()
		_check(player.pickup_interactor.target == node, "应选最近物品")
		var pickup := InputEventAction.new()
		pickup.action = &"pickup_item"
		pickup.pressed = true
		player.pickup_interactor._unhandled_input(pickup)
		await process_frame
	_check(inventory.get_used_slots() == 3, "三种物品应通过F进入基础栏")
	_check(world.get_child_count() == original_world_count - 3, "拾取应移除地面物品")
	var med := inventory.get_item(0)
	var before := med.count
	player.current_health = player.max_health
	interaction.use_item(_loc(0), med.instance_id)
	_check(med.count == before, "满血不能消耗药品")
	player.current_health = 50
	interaction.use_item(_loc(0), med.instance_id)
	_check(med.count == before - 1 and player.continue_healing_unit.is_healing, "药品应消耗并回血")
	interaction.use_item(_loc(0), med.instance_id)
	_check(med.count == before - 1, "未推进相同回血不应重复消耗")

	var bag_config := load("res://resources/config/item_configs/equipment_configs/bagpack_test.tres") as EquipmentConfig
	var equipped := ItemInstance.new(bag_config)
	_check(inventory.try_add(equipped) == 1, "空格应接收背包")
	_check(interaction.validate_move(_loc(3), {"equipment": bag_config.equipment_slot}, equipped.instance_id).is_empty(), "背包应允许装备")
	interaction.move_item(_loc(3), {"equipment": bag_config.equipment_slot}, equipped.instance_id)
	_check(player.equipment.get_item(bag_config.equipment_slot) == equipped, "装备保留实例身份")
	_check(inventory.capacity == 4 + bag_config.slot_capacity, "装备提供额外分区")
	var section := inventory.get_sections()[1]
	var destination := {"section": section.id, "index": 0}
	_check(not interaction.validate_move({"equipment": bag_config.equipment_slot}, destination, equipped.instance_id).is_empty(), "不能卸入自身分区")
	# 使用临时无限制配置测试通用移动，恢复用户配置后再测试名单。
	var saved_config := section.config
	section.config = null
	interaction.move_item(_loc(0), destination, med.instance_id)
	_check(inventory.get_item_at(section.id, 0) == med, "跨分区移动保持实例")
	_check(not interaction.validate_move(destination, _loc(0), -1).is_empty(), "过期ID不能移动")
	var split := ItemInstance.new(med.config, 9)
	inventory.get_section(&"base").slots[0] = split
	interaction.move_item(destination, _loc(0), med.instance_id)
	_check(split.count == 10 and med.count == before - 2, "合并溢出保留原格")
	section.config = saved_config
	var count_before_drop := world.get_child_count()
	interaction.drop_item({"equipment": bag_config.equipment_slot}, equipped.instance_id)
	_check(inventory.capacity == 4 and player.equipment.get_item(bag_config.equipment_slot) == null, "丢弃装备移除分区")
	_check(world.get_child_count() == count_before_drop + 2, "装备和分区内物品全部掉落")
	var found_med := false
	for node in world.get_children():
		if node.item == med:
			found_med = true
	_check(found_med, "掉落保留物品实例与数量")

	var filter_config := ItemConfig.new()
	filter_config.slot_white_list = [medicine]
	filter_config.slot_black_list = [medicine]
	var filter_section := InventorySection.new(&"filter", "测试", 1, ItemInstance.new(filter_config))
	_check(not filter_section.allows(ItemInstance.new(medicine)), "黑名单优先")
	filter_config.slot_black_list.clear()
	_check(filter_section.allows(ItemInstance.new(medicine)) and not filter_section.allows(ItemInstance.new(weapon)), "白名单非空限制物品")
	filter_config.slot_white_list.clear()
	_check(filter_section.allows(ItemInstance.new(weapon)), "空名单允许所有物品")

	var toggle := InputEventAction.new()
	toggle.action = &"toggle_inventory"
	toggle.pressed = true
	layer._input(toggle)
	_check(paused and layer.panel.visible, "TAB应显示物品栏并暂停")
	layer.panel.refresh()
	var section_views: VBoxContainer = layer.panel.get_node("%InventorySections")
	_check(section_views.get_child_count() == 1, "卸下装备后UI仅保留基础分区")
	var first_slot := section_views.get_child(0).get_node("%SectionGrid").get_child(0) as ItemSlot
	var last_slot := section_views.get_child(0).get_node("%SectionGrid").get_child(3) as ItemSlot
	var payload := {"source": _loc(0), "expected_id": split.instance_id, "interaction_id": interaction.get_instance_id()}
	_check(last_slot._can_drop_data(Vector2.ZERO, payload), "空格应接收原生拖放数据")
	last_slot._drop_data(Vector2.ZERO, payload)
	await process_frame
	_check(inventory.get_item(3) == split and inventory.get_item(0) == null, "UI落点应提交移动")
	_check(not first_slot._can_drop_data(Vector2.ZERO, payload), "原位置已变化，旧拖拽数据应失效")
	layer.panel._on_slot_selection_requested(_loc(3), split.instance_id)
	layer.panel.refresh()
	Input.warp_mouse(Vector2(1, 1))
	await process_frame
	var count_before_ui_drop := world.get_child_count()
	var drop_event := InputEventAction.new()
	drop_event.action = &"drop_item"
	drop_event.pressed = true
	layer.panel._input(drop_event)
	_check(world.get_child_count() == count_before_ui_drop + 1 and inventory.get_item(3) == null, "面板丢弃键应丢弃选中整堆")
	var drag_preview := Control.new()
	first_slot.force_drag({"source": _loc(1), "expected_id": inventory.get_item(1).instance_id, "interaction_id": interaction.get_instance_id()}, drag_preview)
	_check(root.gui_is_dragging(), "原生拖拽应启动")
	var unchanged := inventory.get_item(1)
	layer.close_inventory()
	_check(not root.gui_is_dragging() and inventory.get_item(1) == unchanged, "关闭面板应取消拖拽且物品不移动")
	_check(not paused and not layer.panel.visible, "关闭物品栏应恢复")
	game.queue_free()
	await process_frame
	var normal_game := load("res://scene/game.tscn").instantiate() as Game
	normal_game.get_node("EnemyManager").initial_spawn_count = 0
	root.add_child(normal_game)
	current_scene = normal_game
	normal_game._show_result_dialog("测试结算", "验证背包锁定")
	var normal_layer := normal_game.get_node("InventoryLayer")
	normal_layer._input(toggle)
	_check(paused and not normal_layer.panel.visible, "结算期间TAB不应打开背包或恢复游戏")
	paused = false
	normal_game.queue_free()
	await process_frame
	print("物品系统回归检查完成，失败数：", _failures)
	quit(_failures)
