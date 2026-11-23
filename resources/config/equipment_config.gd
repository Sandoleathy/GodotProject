extends ItemConfig
class_name EquipmentConfig

enum EquipmentSlot{
	HEAD,
	CHEST,
	BAG,
	HEAD_SET,
	FACE,
	WAIST,
	SAFE_BOX,
}

@export_group("装备配置")
@export var equipment_slot: EquipmentSlot
@export_range(1, 6, 1, "or_greater") var armor_level: int # 防护等级
@export var equip_effect: PickupConfig
