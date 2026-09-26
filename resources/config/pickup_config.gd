extends Resource
class_name PickupConfig

enum PickupType {
	SPEED,
	SPIRAL,
	RAPID,
	CONTINUE_HEALING,
	IMMEDIATE_HEALING,
}

enum PlayerFormMode {
	NORMAL,
	ARMED,
}

enum ShotPattern {
	NORMAL,
	SPIRAL,
}

@export_group("基础信息")
# 标记道具类型
@export var pickup_type: PickupType = PickupType.SPEED
@export var pickup_name: String = "移速道具"
# 掉落权重
@export_range(0.0, 1000.0, 0.1, "or_greater") var drop_weight: float = 1.0

@export_group("显示&音频资源")
@export var icon_texture: Texture2D
@export var audio_stream: AudioStream

@export_group("Buff 效果")
@export_range(0.0, 120.0, 0.1, "or_greater") var duration: float = 5.0
@export_range(0.0, 5.0, 0.05, "or_greater") var move_speed_multiplier: float = 1.0
@export_range(0.1, 5.0, 0.05, "or_greater") var fire_rate_multiplier: float = 1.0
# 血量回复量
# 如果是即时恢复道具，则捡起时立即回复血量
# 如果是持续回复，则会在持续时间内持续回复，总回复量为该数值
@export_range(0, 50, 1, "or_greater") var healing_amount: int = 10

@export_group("形态与弹幕")
@export var player_form_mode: PlayerFormMode = PlayerFormMode.NORMAL
@export var shot_pattern: ShotPattern = ShotPattern.NORMAL
