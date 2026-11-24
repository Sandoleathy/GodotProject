extends RefCounted
class_name InventorySection

var id: StringName
var title: String
var owner_id: int = 0
var config: ItemConfig
var slots: Array[ItemInstance] = []

func _init(section_id: StringName, section_title: String, size: int, owner: ItemInstance = null) -> void:
	id = section_id
	title = section_title
	slots.resize(size)
	if owner != null:
		owner_id = owner.instance_id
		config = owner.config

static func matches(a: ItemConfig, b: ItemConfig) -> bool:
	return a == b or (not a.id.is_empty() and a.id == b.id) or (not a.resource_path.is_empty() and a.resource_path == b.resource_path)

func allows(item: ItemInstance) -> bool:
	if item == null or item.config == null:
		return false
	if config == null:
		return true
	for blocked in config.slot_black_list:
		if blocked != null and matches(blocked, item.config):
			return false
	if config.slot_white_list.is_empty():
		return true
	for allowed in config.slot_white_list:
		if allowed != null and matches(allowed, item.config):
			return true
	return false
