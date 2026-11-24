extends Node
class_name Equipment

signal changed

var _items: Dictionary[int, ItemInstance] = {}

func get_item(slot: int) -> ItemInstance:
	return _items.get(slot) as ItemInstance
