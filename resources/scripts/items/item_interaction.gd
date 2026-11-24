extends Node
class_name ItemInteraction

@onready var player: Player = get_parent() as Player
@onready var inventory: Inventory = player.get_node("Inventory")
@onready var equipment: Equipment = player.get_node("Equipment")
const WORLD_ITEM = preload("res://scene/world_item.tscn")

func get_item(location: Dictionary) -> ItemInstance:
	if location.has("equipment"):
		return equipment.get_item(int(location.equipment))
	if location.has("section") and location.has("index"):
		return inventory.get_item_at(location.section, int(location.index))
	return null

func _allows(location: Dictionary, item: ItemInstance) -> String:
	if location.has("equipment"):
		if not EquipmentConfig.EquipmentSlot.values().has(int(location.equipment)):
			return "无效装备槽"
		if item == null:
			return ""
		if not item.config is EquipmentConfig or item.count != 1:
			return "此物品不能装备"
		if (item.config as EquipmentConfig).equipment_slot != int(location.equipment):
			return "装备槽不匹配"
		return ""
	var section := inventory.get_section(location.get("section", &""))
	var index := int(location.get("index", -1))
	if section == null or index < 0 or index >= section.slots.size():
		return "格子已失效"
	if item != null and not section.allows(item):
		return "该分区的黑白名单不允许放入"
	return ""

func validate_move(source: Dictionary, target: Dictionary, expected_id: int) -> String:
	if player.is_dead:
		return "角色已死亡"
	var item := get_item(source)
	if item == null or item.instance_id != expected_id:
		return "物品已变化，请重新选择"
	var error := _allows(source, null)
	if not error.is_empty():
		return error
	error = _allows(target, item)
	if not error.is_empty():
		return error
	var other := get_item(target)
	# 装备变化会移除旧分区，不能让任何交换端落在将被删除的分区内。
	for endpoint in [source, target]:
		if not endpoint.has("equipment"):
			continue
		var old := get_item(endpoint)
		if old == null:
			continue
		for address in [source, target]:
			if address.has("section"):
				var section := inventory.get_section(address.section)
				if section != null and section.owner_id == old.instance_id:
					return "不能放入正在卸下的装备所提供的格子"
	if other != null and item.can_stack_with(other) and not source.has("equipment") and not target.has("equipment"):
		return "" if other.count < maxi(other.config.max_stack, 1) else "目标堆叠已满"
	return _allows(source, other)

func _set_item(location: Dictionary, item: ItemInstance) -> void:
	if location.has("equipment"):
		if item == null:
			equipment._items.erase(int(location.equipment))
		else:
			equipment._items[int(location.equipment)] = item
	else:
		inventory.get_section(location.section).slots[int(location.index)] = item

func _prepare_drops(items: Array[ItemInstance]) -> Array[Node2D]:
	var nodes: Array[Node2D] = []
	for item in items:
		var node := WORLD_ITEM.instantiate() as WorldItem
		node.item = item
		node.config = item.config
		node.count = item.count
		nodes.append(node)
	return nodes

func _publish_drops(nodes: Array[Node2D]) -> void:
	var root := get_tree().current_scene
	var container := root.get_node_or_null("WorldItems")
	if container == null:
		container = Node2D.new()
		container.name = "WorldItems"
		root.add_child(container)
	for node in nodes:
		container.add_child(node)
		node.global_position = player.global_position

func _removed_contents(source: Dictionary, target: Dictionary = {}) -> Array[ItemInstance]:
	var items: Array[ItemInstance] = []
	for location in [source, target]:
		if not location.has("equipment"):
			continue
		var old := get_item(location)
		if old == null:
			continue
		for section in inventory.get_sections():
			if section.owner_id == old.instance_id:
				for item in section.slots:
					if item != null:
						items.append(item)
	return items

func move_item(source: Dictionary, target: Dictionary, expected_id: int) -> String:
	if source == target:
		return "位置未改变"
	var error := validate_move(source, target, expected_id)
	if not error.is_empty():
		return error
	var item := get_item(source)
	var other := get_item(target)
	var drops := _prepare_drops(_removed_contents(source, target))
	if other != null and item.can_stack_with(other) and not source.has("equipment") and not target.has("equipment"):
		var amount := mini(item.count, maxi(other.config.max_stack, 1) - other.count)
		other.count += amount
		item.count -= amount
		if item.count == 0:
			_set_item(source, null)
	else:
		_set_item(source, other)
		_set_item(target, item)
	inventory.rebuild_equipment_sections(equipment)
	_publish_drops(drops)
	equipment.changed.emit()
	inventory.changed.emit()
	return "物品已移动"

func drop_item(location: Dictionary, expected_id: int) -> String:
	var item := get_item(location)
	if player.is_dead or item == null or item.instance_id != expected_id:
		return "物品已变化或角色已死亡"
	var items := _removed_contents(location)
	items.append(item)
	var drops := _prepare_drops(items)
	_set_item(location, null)
	inventory.rebuild_equipment_sections(equipment)
	_publish_drops(drops)
	equipment.changed.emit()
	inventory.changed.emit()
	return "已丢弃 %s ×%d" % [item.config.name, item.count]

func use_item(location: Dictionary, expected_id: int) -> String:
	var item := get_item(location)
	if player.is_dead or item == null or item.instance_id != expected_id:
		return "物品已变化或角色已死亡"
	if location.has("equipment") or not item.config.useable or item.config.use_effect == null:
		return "该物品不可使用"
	if not player.apply_item_effect(item.config.use_effect):
		return "当前无法使用（生命值已满或效果无效）"
	item.count -= 1
	if item.count == 0:
		_set_item(location, null)
	inventory.changed.emit()
	return "已使用 %s" % item.config.name
