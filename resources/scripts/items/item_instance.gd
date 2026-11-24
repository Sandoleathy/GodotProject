extends RefCounted
class_name ItemInstance

var instance_id: int
var config: ItemConfig
var count: int
var durability: float

func _init(item_config: ItemConfig, amount: int = 1) -> void:
	instance_id = get_instance_id()
	config = item_config
	count = maxi(amount, 0)
	durability = float(config.max_duration) if config != null and config.max_duration != null else 0.0

func can_stack_with(other: ItemInstance) -> bool:
	if other == null or config == null or other.config == null:
		return false
	var same_config := InventorySection.matches(config, other.config)
	return same_config and is_equal_approx(durability, other.durability) and config.max_stack > 1
