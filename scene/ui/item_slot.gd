extends Button
class_name ItemSlot

signal selection_requested(location: Dictionary, expected_id: int)
signal operation_completed(message: String)

@onready var _caption: Label = %Caption
@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %ItemName
@onready var _count_label: Label = %Count
@onready var _selection: Panel = %Selection

var location: Dictionary = {}
var _interaction: Node
var _item: ItemInstance
var _empty_text: String = "空格"
var _selected: bool = false
var _caption_text: String = ""


func _ready() -> void:
	pressed.connect(_on_pressed)
	_update_display()


func bind_location(item_location: Dictionary, interaction: Node) -> void:
	location = item_location.duplicate()
	_interaction = interaction


func display_item(item: ItemInstance, empty_text: String = "空格", caption: String = "") -> void:
	_item = item
	_empty_text = empty_text
	_caption_text = caption
	if is_node_ready():
		_update_display()


func get_displayed_id() -> int:
	return _item.instance_id if _item != null else -1


func set_selected(selected: bool) -> void:
	_selected = selected
	if is_node_ready():
		_selection.visible = selected


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_instance_valid(_interaction) or _item == null or location.is_empty():
		return null
	var current: ItemInstance = _interaction.call("get_item", location) as ItemInstance
	if current == null or current.instance_id != get_displayed_id():
		return null
	selection_requested.emit(location.duplicate(), current.instance_id)
	# 原生拖拽只携带位置及实例 ID，松开到合法格子前不改变物品数据。
	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _icon.texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = _icon.size * 1.05
	icon.position = -icon.size * 0.5
	preview.add_child(icon)
	if icon.texture == null:
		var label := Label.new()
		label.text = _item.config.name if _item.config != null else "物品"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.scale = Vector2.ONE * 1.05
		label.position = Vector2(-32, -12)
		preview.add_child(label)
	set_drag_preview(preview)
	return {
		"source": location.duplicate(),
		"expected_id": current.instance_id,
		"interaction_id": _interaction.get_instance_id(),
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not _is_own_drag(data):
		return false
	var reason: String = _interaction.call("validate_move", data["source"], location, data["expected_id"])
	return reason.is_empty()


func _drop_data(at_position: Vector2, data: Variant) -> void:
	# 放下时再次验证，防止拖动期间装备变化或物品已被替换。
	if not _can_drop_data(at_position, data):
		return
	var message: String = _interaction.call("move_item", data["source"], location, data["expected_id"])
	operation_completed.emit(message)


func _is_own_drag(data: Variant) -> bool:
	if not is_instance_valid(_interaction) or not data is Dictionary or location.is_empty():
		return false
	return (
		data.get("source") is Dictionary and data.get("expected_id") is int
		and data.get("interaction_id", -1) == _interaction.get_instance_id()
	)


func _on_pressed() -> void:
	selection_requested.emit(location.duplicate(), get_displayed_id())


func _update_display() -> void:
	_caption.text = _caption_text
	_caption.visible = not _caption_text.is_empty()
	_selection.visible = _selected
	_icon.texture = null
	_count_label.text = ""
	_name_label.text = _empty_text
	tooltip_text = _empty_text
	if _item == null or _item.config == null:
		return
	_icon.texture = _item.config.icon_texture
	_name_label.text = _item.config.name
	_count_label.text = "×%d" % _item.count
	tooltip_text = "%s\n%s\n数量：%d　耐久：%.1f" % [
		_item.config.name, _item.config.description, _item.count, _item.durability
	]
