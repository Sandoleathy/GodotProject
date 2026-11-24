extends Area2D
class_name WorldItem

@export var config: ItemConfig
@export_range(1, 999, 1) var count: int = 1
@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel
var item: ItemInstance
var _retry_time: float = 0.0

func _ready() -> void:
	if config == null:
		push_warning("地面物品缺少配置")
		set_physics_process(false)
		return
	item = ItemInstance.new(config, count)
	sprite.texture = config.icon_texture
	if sprite.texture != null:
		var largest := maxf(sprite.texture.get_width(), sprite.texture.get_height())
		sprite.scale = Vector2.ONE * minf(24.0 / maxf(largest, 1.0), 1.0)
	_refresh_label()

# 周期检查重叠玩家，清出背包空间后不用离开拾取区即可重试。
func _physics_process(delta: float) -> void:
	_retry_time -= delta
	if _retry_time > 0.0 or item == null or item.count <= 0:
		return
	_retry_time = 0.25
	for body in get_overlapping_bodies():
		var player := body as Player
		if player == null or player.is_dead:
			continue
		var accepted := player.try_pickup_item(item)
		item.count -= accepted
		count = item.count
		if item.count <= 0:
			queue_free()
			return
		_refresh_label()

func _refresh_label() -> void:
	name_label.text = "%s ×%d" % [config.name, item.count]
