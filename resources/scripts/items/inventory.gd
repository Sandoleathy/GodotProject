extends Node
class_name Inventory

signal changed

@export_range(1, 100, 1) var base_capacity: int = 4
var capacity: int:
	get:
		var total := 0
		for section in _sections:
			total += section.slots.size()
		return total
var _sections: Array[InventorySection] = []

func _ready() -> void:
	_sections.append(InventorySection.new(&"base", "基础物品栏", base_capacity))

func get_sections() -> Array[InventorySection]:
	return _sections.duplicate()

func get_section(id: StringName) -> InventorySection:
	for section in _sections:
		if section.id == id:
			return section
	return null

func get_item_at(id: StringName, index: int) -> ItemInstance:
	var section := get_section(id)
	if section == null or index < 0 or index >= section.slots.size():
		return null
	return section.slots[index]

# 兼容旧版按顺序读取，交互命令使用稳定分区地址。
func location_at(index: int) -> Dictionary:
	for section in _sections:
		if index >= 0 and index < section.slots.size():
			return {"section": section.id, "index": index}
		index -= section.slots.size()
	return {}

func get_item(index: int) -> ItemInstance:
	var location := location_at(index)
	return get_item_at(location.section, location.index) if not location.is_empty() else null

func try_add(item: ItemInstance) -> int:
	if item == null or item.config == null or item.count <= 0:
		return 0
	var remaining := item.count
	var limit := maxi(item.config.max_stack, 1)
	for section in _sections:
		if not section.allows(item):
			continue
		for stored in section.slots:
			if stored != null and stored.can_stack_with(item):
				var amount := mini(maxi(limit - stored.count, 0), remaining)
				stored.count += amount
				remaining -= amount
	for section in _sections:
		if not section.allows(item):
			continue
		for index in range(section.slots.size()):
			if remaining <= 0:
				break
			if section.slots[index] != null:
				continue
			var amount := mini(limit, remaining)
			var stored := item if amount == item.count and remaining == item.count else ItemInstance.new(item.config, amount)
			stored.durability = item.durability
			section.slots[index] = stored
			remaining -= amount
	var accepted := item.count - remaining
	if accepted > 0:
		changed.emit()
	return accepted

func rejection_reason(item: ItemInstance) -> String:
	for section in _sections:
		if section.allows(item):
			return "没有可用空间"
	return "所有分区均禁止放入该物品"

func consume_one(index: int, expected_id: int) -> bool:
	var location := location_at(index)
	if location.is_empty():
		return false
	var item := get_item(index)
	if item == null or item.instance_id != expected_id or item.count <= 0:
		return false
	item.count -= 1
	if item.count == 0:
		get_section(location.section).slots[location.index] = null
	changed.emit()
	return true

func get_used_slots() -> int:
	var used := 0
	for section in _sections:
		for item in section.slots:
			if item != null:
				used += 1
	return used

func get_total_weight() -> float:
	var total := 0.0
	for section in _sections:
		for item in section.slots:
			if item != null:
				total += item.config.weight * item.count
	var equipment := get_parent().get_node_or_null("Equipment") as Equipment
	if equipment != null:
		for item in equipment._items.values():
			total += item.config.weight * item.count
	return total

# 由交互层在完整校验后调用，移出的内容物交由地面系统接管。
func rebuild_equipment_sections(equipment: Equipment) -> Array[ItemInstance]:
	var removed: Array[ItemInstance] = []
	var next: Array[InventorySection] = [get_section(&"base")]
	for slot in EquipmentConfig.EquipmentSlot.values():
		var item := equipment.get_item(slot)
		if item == null or item.config.slot_capacity <= 0:
			continue
		var id := StringName("equipment_%d" % item.instance_id)
		var section := get_section(id)
		if section == null:
			section = InventorySection.new(id, item.config.name, item.config.slot_capacity, item)
		next.append(section)
	for section in _sections:
		if not next.has(section):
			for item in section.slots:
				if item != null:
					removed.append(item)
	_sections = next
	return removed
