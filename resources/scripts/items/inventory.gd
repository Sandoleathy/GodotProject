extends Node
class_name Inventory

signal changed

@export_range(1, 100, 1) var capacity: int = 20
var _slots: Array[ItemInstance] = []

func _ready() -> void:
	_slots.resize(capacity)

func get_item(index: int) -> ItemInstance:
	if index < 0 or index >= _slots.size():
		return null
	return _slots[index]

# 返回实际接收数量；调用者负责扣减地面物品，背包不持有地面实例。
func try_add(item: ItemInstance) -> int:
	if item == null or item.config == null or item.count <= 0:
		return 0
	var remaining := item.count
	var stack_limit := maxi(item.config.max_stack, 1)
	for stored in _slots:
		if stored == null or not stored.can_stack_with(item):
			continue
		var amount := mini(maxi(stack_limit - stored.count, 0), remaining)
		stored.count += amount
		remaining -= amount
		if remaining == 0:
			break
	if remaining > 0:
		for index in range(_slots.size()):
			if _slots[index] != null:
				continue
			var amount := mini(stack_limit, remaining)
			var stored := ItemInstance.new(item.config, amount)
			stored.durability = item.durability
			_slots[index] = stored
			remaining -= amount
			if remaining == 0:
				break
	var accepted := item.count - remaining
	if accepted > 0:
		changed.emit()
	return accepted

func consume_one(index: int, expected_id: int) -> bool:
	var item := get_item(index)
	if item == null or item.instance_id != expected_id or item.count <= 0:
		return false
	item.count -= 1
	if item.count == 0:
		_slots[index] = null
	changed.emit()
	return true

func get_used_slots() -> int:
	var used := 0
	for item in _slots:
		if item != null:
			used += 1
	return used

func get_total_weight() -> float:
	var total := 0.0
	for item in _slots:
		if item != null:
			total += item.config.weight * item.count
	return total
