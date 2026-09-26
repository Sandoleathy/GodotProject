extends Node
class_name ContinueHealingUnit

var player: Player
var total_heal_amount: int = 0
var duration: float = 0.0
var elapsed: float = 0.0
var applied: int = 0  		# 已经实际回复的整数血量
var is_healing: bool = false
# Called when the node enters the scene tree for the first time.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if !_is_system_ready():
		return
	elapsed = minf(elapsed + delta, duration)
	var expected_total_healing := total_heal_amount * ( elapsed / duration )
	
	# 取整
	var should_applied = int(expected_total_healing)
	# 将要回复的血量
	var to_apply = should_applied - applied
	
	if to_apply > 0:
		player.apply_healing(to_apply)
		applied += to_apply	
	
	# 计时器结束，加上剩余没有加上去的血量，并且销毁
	if elapsed >= duration:
		var remaining = total_heal_amount - applied
		# 补上后因为浮点数转整数可能遗失掉的血量
		player.apply_healing(remaining)
		is_healing = false

func setup(_player: Player) -> void:
	self.player = _player

func _is_system_ready() -> bool:
	return (
		player != null and 
		total_heal_amount > 0 and
		duration > 0.0 and
		is_healing
	)

# 设定新的回复量和时间
func set_healing_data(amount: int, _duration: float) -> void:
	if amount <= 0 or _duration <= 0.0:
		return
	# 新传入的amount如果小于当前剩余回复量，那么就保持当前的
	var remaining_healing = total_heal_amount - applied
	# 如果amount大于剩余回复量则重置计时器和回复量
	if remaining_healing < amount:
		applied = 0
		total_heal_amount = amount
		duration = _duration
		elapsed = 0.0
	is_healing = true
