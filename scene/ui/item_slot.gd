extends Button
class_name ItemSlot

@onready var _caption: Label = %Caption
@onready var _icon: TextureRect = %Icon
@onready var _name_label: Label = %ItemName
@onready var _count_label: Label = %Count
@onready var _selection: Panel = %Selection

var _item: ItemInstance
var _empty_text: String = "空格"
var _selected: bool = false
var _caption_text: String = ""


func _ready() -> void:
	_update_display()


func display_item(item: ItemInstance, empty_text: String = "空格", caption: String = "") -> void:
	_item = item
	_empty_text = empty_text
	_caption_text = caption
	if is_node_ready():
		_update_display()


func set_selected(selected: bool) -> void:
	_selected = selected
	if is_node_ready():
		_selection.visible = selected


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
