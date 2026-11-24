extends Control
class_name InventoryPanel

signal close_requested

const EQUIPMENT_LABELS: Dictionary = {
	EquipmentConfig.EquipmentSlot.HEAD: "头部",
	EquipmentConfig.EquipmentSlot.CHEST: "胸甲",
	EquipmentConfig.EquipmentSlot.CHEST_HARNESS: "胸挂",
	EquipmentConfig.EquipmentSlot.BAG: "背包",
	EquipmentConfig.EquipmentSlot.HEAD_SET: "耳机",
	EquipmentConfig.EquipmentSlot.FACE: "面部",
	EquipmentConfig.EquipmentSlot.WAIST: "腰部",
	EquipmentConfig.EquipmentSlot.SAFE_BOX: "保险箱",
}

@onready var _equipment_grid: GridContainer = %EquipmentGrid
@onready var _inventory_grid: GridContainer = %InventoryGrid
@onready var _capacity_label: Label = %CapacityLabel
@onready var _detail_name: Label = %DetailName
@onready var _detail_text: Label = %DetailText
@onready var _use_button: Button = %UseButton
@onready var _message_label: Label = %MessageLabel

var _player: Player
var _inventory: Inventory
var _equipment: Equipment
var _selected_index: int = -1
var _selected_id: int = -1
var _selected_equipment: int = -1
var _message: String = "请选择物品查看详情。"


func _ready() -> void:
	for index: int in range(_inventory_grid.get_child_count()):
		var slot: ItemSlot = _inventory_grid.get_child(index) as ItemSlot
		slot.pressed.connect(_on_inventory_slot_pressed.bind(index))
	var equipment_slots: Array = EquipmentConfig.EquipmentSlot.values()
	for index: int in range(_equipment_grid.get_child_count()):
		var slot: ItemSlot = _equipment_grid.get_child(index) as ItemSlot
		var equipment_slot: int = int(equipment_slots[index])
		slot.pressed.connect(_on_equipment_slot_pressed.bind(equipment_slot))
	refresh()


func bind_player(player: Player) -> void:
	_disconnect_data_signals()
	_player = player
	_inventory = null
	_equipment = null
	_selected_index = -1
	_selected_id = -1
	_selected_equipment = -1
	if is_instance_valid(_player):
		_inventory = _player.inventory
		_equipment = _player.equipment
		if _inventory != null:
			_inventory.changed.connect(refresh)
		if _equipment != null:
			_equipment.changed.connect(refresh)
	show_message("请选择物品查看详情。")
	refresh()


func refresh() -> void:
	if not is_node_ready():
		return
	if not is_instance_valid(_player):
		_disconnect_data_signals()
		_inventory = null
		_equipment = null
	var capacity: int = _inventory.capacity if _inventory != null else 0
	if _selected_index >= 0 and _get_selected_item() == null:
		_selected_index = -1
		_selected_id = -1
	while _inventory_grid.get_child_count() < capacity:
		var slot := preload("res://scene/ui/item_slot.tscn").instantiate() as ItemSlot
		var index := _inventory_grid.get_child_count()
		_inventory_grid.add_child(slot)
		slot.pressed.connect(_on_inventory_slot_pressed.bind(index))
	for index: int in range(_inventory_grid.get_child_count()):
		var slot: ItemSlot = _inventory_grid.get_child(index) as ItemSlot
		var item: ItemInstance = null
		if _inventory != null and index < capacity:
			item = _inventory.get_item(index)
		slot.display_item(item, "空格" if index < capacity else "未开放")
		slot.disabled = index >= capacity
		slot.set_selected(index == _selected_index)
	var equipment_slots: Array = EquipmentConfig.EquipmentSlot.values()
	for index: int in range(equipment_slots.size()):
		var equipment_slot: int = int(equipment_slots[index])
		var slot: ItemSlot = _equipment_grid.get_child(index) as ItemSlot
		var item: ItemInstance = null
		if _equipment != null:
			item = _equipment.get_item(equipment_slot)
		slot.display_item(item, "空槽", String(EQUIPMENT_LABELS[equipment_slot]))
		slot.tooltip_text = "%s\n%s" % [EQUIPMENT_LABELS[equipment_slot], slot.tooltip_text]
		slot.set_selected(equipment_slot == _selected_equipment)
	if _inventory == null:
		_capacity_label.text = "背包未绑定"
	else:
		_capacity_label.text = "格数 %d / %d　总重量 %.2f" % [
			_inventory.get_used_slots(), capacity, _inventory.get_total_weight()
		]
	_update_details()
	_message_label.text = _message


func show_message(message: String) -> void:
	_message = message
	if is_node_ready():
		_message_label.text = message


func _disconnect_data_signals() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(refresh):
		_inventory.changed.disconnect(refresh)
	if is_instance_valid(_equipment) and _equipment.changed.is_connected(refresh):
		_equipment.changed.disconnect(refresh)


func _get_selected_item() -> ItemInstance:
	if not is_instance_valid(_inventory) or _selected_index < 0 or _selected_index >= _inventory.capacity:
		return null
	var item: ItemInstance = _inventory.get_item(_selected_index)
	if item == null or item.instance_id != _selected_id:
		return null
	return item


func _update_details() -> void:
	_use_button.disabled = true
	var item: ItemInstance = _get_selected_item()
	var location: String = "背包物品"
	if _selected_equipment >= 0:
		location = "装备 · %s（仅展示）" % EQUIPMENT_LABELS[_selected_equipment]
		item = _equipment.get_item(_selected_equipment) if _equipment != null else null
	if item == null or item.config == null:
		_detail_name.text = location if _selected_equipment >= 0 else "物品详情"
		_detail_text.text = "此装备槽为空。" if _selected_equipment >= 0 else "选择背包或装备槽，查看物品信息。"
		return
	_detail_name.text = item.config.name
	_detail_text.text = "%s\n\n%s\n\n数量：%d　耐久：%.1f\n单件重量：%.2f　合计：%.2f\n%s" % [
		location, item.config.description, item.count, item.durability,
		item.config.weight, item.config.weight * item.count,
		"可使用" if item.config.useable else "不可使用"
	]
	_use_button.disabled = (
		_selected_equipment >= 0 or not is_instance_valid(_player)
		or not item.config.useable or item.config.use_effect == null or item.count <= 0
	)


func _on_inventory_slot_pressed(index: int) -> void:
	_selected_equipment = -1
	_selected_index = -1
	_selected_id = -1
	if _inventory != null and index >= 0 and index < _inventory.capacity:
		var item: ItemInstance = _inventory.get_item(index)
		if item != null:
			_selected_index = index
			_selected_id = item.instance_id
	refresh()


func _on_equipment_slot_pressed(slot: int) -> void:
	_selected_index = -1
	_selected_id = -1
	_selected_equipment = slot
	refresh()


func _on_use_button_pressed() -> void:
	var item: ItemInstance = _get_selected_item()
	if not is_instance_valid(_player) or item == null or item.config == null:
		show_message("物品已变化，请重新选择。")
		refresh()
		return
	if _selected_equipment >= 0 or not item.config.useable or item.config.use_effect == null or item.count <= 0:
		show_message("该物品无法使用。")
		refresh()
		return
	var result: String = _player.use_inventory_item(_selected_index, _selected_id)
	show_message(result)
	refresh()


func _on_close_button_pressed() -> void:
	close_requested.emit()
