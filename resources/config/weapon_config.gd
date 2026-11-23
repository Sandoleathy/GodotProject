extends ItemConfig
class_name WeaponConfig

enum WeaponType {
	CLOSE,
	LONG_RANGE,
}

@export_group("武器")
@export var weapon_type: WeaponType
@export_range(0.1, 100.0, 0.1, "or_greater") var damage: float # 武器伤害
@export_range(0.1, 10.0, 0.1, "or_greater") var attack_distance # 攻击距离/射程
@export_range(0.1, 5.0, 0.1, "or_greater") var attack_cooldown_time: float # 冷却时间
@export_range(0.01, 1.0, 0.01, "or_greater") var critical_chance: float # 暴击率
@export_range(1.0, 3.0, 0.1, "or_greater") var critical_damage_rate: float # 暴击倍率
@export_range(1.0, 6.0, 0.1, "or_greater") var armor_penetration_level: float # 破甲等级
