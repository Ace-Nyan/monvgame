# MagicType.gd
extends RefCounted
class_name MagicType

enum Type {
	WATER,      # 水
	FIRE,       # 火
	WOOD,       # 草
	DIRT,       # 地
	WIND,       # 风
	IRON,       # 钢
	ELECTRON,   # 雷
	MED,        # 药
	BLACK,      # 黑魔法
	ICE,        # 冰
	MOOD,       # 精神
	COMMON      # 无属性
}

# 用于显示的魔法类型名称
static var type_names: Dictionary = {
	Type.WATER: "水",
	Type.FIRE: "火",
	Type.WOOD: "草",
	Type.DIRT: "地",
	Type.WIND: "风",
	Type.IRON: "钢",
	Type.ELECTRON: "雷",
	Type.MED: "药",
	Type.BLACK: "黑魔法",
	Type.ICE: "冰",
	Type.MOOD: "精神",
	Type.COMMON: "无属性"
}
