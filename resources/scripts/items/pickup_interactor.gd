extends Node
class_name PickupInteractor

@export_range(1.0, 100.0, 1.0) var pickup_radius: float = 30.0
@onready var player: Player = get_parent() as Player
var target: WorldItem

func _physics_process(_delta: float) -> void:
	_refresh_target()

func _refresh_target() -> void:
	target = null
	if player.is_dead:
		return
	var best := pickup_radius * pickup_radius
	for node in get_tree().get_nodes_in_group(&"world_items"):
		var world := node as WorldItem
		if world == null or world.is_queued_for_deletion() or world.item == null:
			continue
		var distance := player.global_position.distance_squared_to(world.global_position)
		if distance < best:
			best = distance
			target = world

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pickup_item") and not event.is_echo() and not player.is_dead:
		_refresh_target()
		if is_instance_valid(target):
			target.pickup(player)
		get_viewport().set_input_as_handled()

func get_prompt() -> String:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or target.item == null:
		return ""
	return "F 拾取 %s ×%d" % [target.item.config.name, target.item.count]
