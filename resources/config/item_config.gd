extends Resource
class_name ItemConfig
# 通用战利品配置文件

enum ItemType {
	LOOT,
	MED,
	WEAPON,
	EQUIPMENT,
}

@export_group("名称类型外观")
@export var name: String
@export var item_type: ItemType
@export var label: String
@export var description: String
@export var icon_texture: Texture2D # 图标

@export_group("数值")
@export_range(1, 10, 1, "or_greater") var max_stack: int # 物品最大堆叠数量
@export var useable: bool
@export var use_effect: EffectConfig # 指向 effect_config
@export_range(0.001, 100.0, 0.1, "or_greater") var weight: float # 物品重量
@export_range(0.0, 10.0, 0.1, "or_greater") var rarity: float # 稀有度
@export_range(1.0, 200.0, 1.0, "or_greater") var max_duration # 最大耐久值

@export_group("物品栏")
@export_range(0, 50, 1, "or_greater") var slot_capacity: int # 容器大小
@export var slot_black_list: Array[ItemConfig] # 黑名单
@export var slot_white_list: Array[ItemConfig] # 白名单
