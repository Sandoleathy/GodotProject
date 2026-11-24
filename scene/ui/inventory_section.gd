extends VBoxContainer

signal selection_requested(location: Dictionary, expected_id: int)
signal operation_completed(message: String)

const SLOT_SCENE: PackedScene = preload("res://scene/ui/item_slot.tscn")

@onready var _title: Label = %SectionTitle
@onready var _grid: GridContainer = %SectionGrid

var section_id: StringName
var owner_id: int = -1


func display_section(section: RefCounted, interaction: Node, selected_location: Dictionary, selected_id: int) -> void:
	section_id = section.get("id")
	owner_id = int(section.get("owner_id"))
	var items: Array = section.get("slots")
	_title.text = "%s · %d 格" % [section.get("title"), items.size()]
	while _grid.get_child_count() > items.size():
		var removed: Node = _grid.get_child(_grid.get_child_count() - 1)
		_grid.remove_child(removed)
		removed.queue_free()
	while _grid.get_child_count() < items.size():
		var slot := SLOT_SCENE.instantiate() as ItemSlot
		_grid.add_child(slot)
		slot.selection_requested.connect(_on_slot_selection_requested)
		slot.operation_completed.connect(_on_slot_operation_completed)
	for index: int in range(items.size()):
		var slot := _grid.get_child(index) as ItemSlot
		var item_location: Dictionary = {"section": section_id, "index": index}
		slot.bind_location(item_location, interaction)
		slot.display_item(items[index] as ItemInstance)
		slot.set_selected(item_location == selected_location and slot.get_displayed_id() == selected_id)


func _on_slot_selection_requested(item_location: Dictionary, expected_id: int) -> void:
	selection_requested.emit(item_location, expected_id)


func _on_slot_operation_completed(message: String) -> void:
	operation_completed.emit(message)
