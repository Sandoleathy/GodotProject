extends Area2D
class_name WorldItem

@export var config: ItemConfig
@export_range(1, 999, 1) var count: int = 1
@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel
var item: ItemInstance

func _ready() -> void:
	if config == null:
		push_warning("地面物品缺少配置")
		return
	if item == null:
		item = ItemInstance.new(config, count)
	add_to_group(&"world_items")
	sprite.texture = config.icon_texture
	if sprite.texture != null:
		var largest := maxf(sprite.texture.get_width(), sprite.texture.get_height())
		sprite.scale = Vector2.ONE * minf(24.0 / maxf(largest, 1.0), 1.0)
	_refresh_label()

func pickup(player: Player) -> void:
	if item == null or is_queued_for_deletion():
		return
	var original_count := item.count
	var accepted := player.try_pickup_item(item)
	if accepted == original_count:
		remove_from_group(&"world_items")
		queue_free()
	elif accepted > 0:
		item.count -= accepted
		count = item.count
		_refresh_label()

func _refresh_label() -> void:
	name_label.text = "%s ×%d" % [config.name, item.count]
