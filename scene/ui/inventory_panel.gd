extends Control
class_name InventoryPanel

signal close_requested

const SECTION_SCENE: PackedScene = preload("res://scene/ui/inventory_section.tscn")
const EQUIPMENT_LABELS: Dictionary = {
	EquipmentConfig.EquipmentSlot.HEAD: "头部",
	EquipmentConfig.EquipmentSlot.CHEST: "胸甲",
	EquipmentConfig.EquipmentSlot.CHEST_HARNESS: "胸挂",
	EquipmentConfig.EquipmentSlot.BAG: "背包",
	EquipmentConfig.EquipmentSlot.HEAD_SET: "耳机",
	EquipmentConfig.EquipmentSlot.FACE: "面部",
	EquipmentConfig.EquipmentSlot.WAIST: "腰带",
	EquipmentConfig.EquipmentSlot.SAFE_BOX: "保险箱",
}

@onready var _equipment_grid: GridContainer = %EquipmentGrid
@onready var _sections: VBoxContainer = %InventorySections
@onready var _capacity_label: Label = %CapacityLabel
@onready var _detail_name: Label = %DetailName
@onready var _detail_text: Label = %DetailText
@onready var _use_button: Button = %UseButton
@onready var _message_label: Label = %MessageLabel

var _player: Player
var _inventory: Inventory
var _equipment: Equipment
var _interaction: Node
var _selected_location: Dictionary = {}
var _selected_id: int = -1
var _message: String = "选择物品查看详情，拖动可移动或穿戴。"
var _refresh_queued: bool = false


func _ready() -> void:
	for child: Node in _equipment_grid.get_children():
		var slot := child as ItemSlot
		slot.selection_requested.connect(_on_slot_selection_requested)
		slot.operation_completed.connect(_on_operation_completed)
	refresh()


func bind_player(player: Player) -> void:
	_disconnect_data_signals()
	_player = player
	_inventory = null
	_equipment = null
	_interaction = null
	_selected_location = {}
	_selected_id = -1
	if is_instance_valid(_player):
		_inventory = _player.inventory
		_equipment = _player.equipment
		_interaction = _player.get("item_interaction") as Node
		if _inventory != null:
			_inventory.changed.connect(_queue_refresh)
		if _equipment != null:
			_equipment.changed.connect(_queue_refresh)
	show_message("选择物品查看详情，拖动可移动或穿戴。")
	refresh()


func refresh() -> void:
	_refresh_queued = false
	if not is_node_ready():
		return
	if not is_instance_valid(_player):
		_disconnect_data_signals()
		_inventory = null
		_equipment = null
		_interaction = null
	if _get_selected_item() == null:
		_selected_location = {}
		_selected_id = -1
	var sections: Array = _inventory.get_sections() if is_instance_valid(_inventory) else []
	# 保留已有分区控件以保持滚动位置，只在分区消失时移除。
	var active_ids: Array[StringName] = []
	for section: RefCounted in sections:
		var section_id: StringName = section.get("id")
		active_ids.append(section_id)
		var view: VBoxContainer = null
		for child: Node in _sections.get_children():
			if child.get("section_id") == section_id:
				view = child as VBoxContainer
				break
		if view == null:
			view = SECTION_SCENE.instantiate() as VBoxContainer
			_sections.add_child(view)
			view.connect("selection_requested", _on_slot_selection_requested)
			view.connect("operation_completed", _on_operation_completed)
		view.call("display_section", section, _interaction, _selected_location, _selected_id)
		_sections.move_child(view, active_ids.size() - 1)
	for child: Node in _sections.get_children():
		if not active_ids.has(child.get("section_id")):
			_sections.remove_child(child)
			child.queue_free()
	var equipment_slots: Array = EquipmentConfig.EquipmentSlot.values()
	for index: int in range(equipment_slots.size()):
		var equipment_slot: int = int(equipment_slots[index])
		var slot := _equipment_grid.get_child(index) as ItemSlot
		var item: ItemInstance = _equipment.get_item(equipment_slot) if is_instance_valid(_equipment) else null
		var item_location: Dictionary = {"equipment": equipment_slot}
		slot.bind_location(item_location, _interaction)
		slot.display_item(item, "空槽", String(EQUIPMENT_LABELS[equipment_slot]))
		slot.tooltip_text = "%s\n%s" % [EQUIPMENT_LABELS[equipment_slot], slot.tooltip_text]
		slot.set_selected(item_location == _selected_location and slot.get_displayed_id() == _selected_id)
	if not is_instance_valid(_inventory):
		_capacity_label.text = "背包未绑定"
	else:
		_capacity_label.text = "格数 %d / %d　总重量 %.2f" % [
			_inventory.get_used_slots(), _inventory.capacity, _inventory.get_total_weight()
		]
	_update_details()
	_message_label.text = _message


func show_message(message: String) -> void:
	_message = message
	if is_node_ready():
		_message_label.text = message


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_action_pressed(&"drop_item") or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if get_viewport().gui_is_dragging():
		return
	var item_location: Dictionary = _selected_location.duplicate()
	var expected_id: int = _selected_id
	# 悬停空槽也优先于已选物品，避免鼠标指向空槽时误丢选中物品。
	var hovered: Control = get_viewport().gui_get_hovered_control()
	while hovered != null and not hovered is ItemSlot:
		hovered = hovered.get_parent() as Control
	if hovered is ItemSlot and is_ancestor_of(hovered):
		var slot := hovered as ItemSlot
		item_location = slot.location.duplicate()
		expected_id = slot.get_displayed_id()
	if not is_instance_valid(_interaction) or item_location.is_empty() or expected_id == -1:
		show_message("请悬停或选择要丢弃的物品。")
		return
	var result: String = _interaction.call("drop_item", item_location, expected_id)
	_on_operation_completed(result)


func _queue_refresh() -> void:
	# 数据可能在 _drop_data 内改变；退出拖放回调后再删除已消失的分区。
	if not _refresh_queued:
		_refresh_queued = true
		refresh.call_deferred()


func _disconnect_data_signals() -> void:
	if is_instance_valid(_inventory) and _inventory.changed.is_connected(_queue_refresh):
		_inventory.changed.disconnect(_queue_refresh)
	if is_instance_valid(_equipment) and _equipment.changed.is_connected(_queue_refresh):
		_equipment.changed.disconnect(_queue_refresh)


func _get_selected_item() -> ItemInstance:
	if not is_instance_valid(_interaction) or _selected_location.is_empty():
		return null
	var item: ItemInstance = _interaction.call("get_item", _selected_location) as ItemInstance
	return item if item != null and item.instance_id == _selected_id else null


func _update_details() -> void:
	_use_button.disabled = true
	var item: ItemInstance = _get_selected_item()
	if item == null or item.config == null:
		_detail_name.text = "物品详情"
		_detail_text.text = "选择背包或装备槽查看物品。\n拖动移动或穿戴，丢弃键优先操作鼠标悬停的物品。"
		return
	var place: String = "库存物品"
	if _selected_location.has("equipment"):
		place = "装备 · %s" % EQUIPMENT_LABELS[_selected_location["equipment"]]
	else:
		for section: RefCounted in _inventory.get_sections():
			if section.get("id") == _selected_location.get("section"):
				place = String(section.get("title"))
				break
	_detail_name.text = item.config.name
	_detail_text.text = "%s\n\n%s\n\n数量：%d　耐久：%.1f\n单件重量：%.2f　合计：%.2f\n%s" % [
		place, item.config.description, item.count, item.durability,
		item.config.weight, item.config.weight * item.count,
		"可使用" if item.config.useable else "不可使用"
	]
	_use_button.disabled = (
		_selected_location.has("equipment") or not item.config.useable
		or item.config.use_effect == null or item.count <= 0
	)


func _on_slot_selection_requested(item_location: Dictionary, expected_id: int) -> void:
	_selected_location = item_location.duplicate()
	_selected_id = expected_id
	_queue_refresh()


func _on_operation_completed(message: String) -> void:
	show_message(message)
	_queue_refresh()


func _on_use_button_pressed() -> void:
	if get_viewport().gui_is_dragging():
		return
	if not is_instance_valid(_interaction) or _get_selected_item() == null:
		show_message("物品已变化，请重新选择。")
		_queue_refresh()
		return
	var result: String = _interaction.call("use_item", _selected_location, _selected_id)
	_on_operation_completed(result)


func _on_close_button_pressed() -> void:
	close_requested.emit()
