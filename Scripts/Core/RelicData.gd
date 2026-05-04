## RelicData — 遗物数据资源
class_name RelicData
extends Resource

enum Category {
	LOW,
	MID,
	HIGH,
	SHOP,
	EVENT,
	STARTER,
	UNIQUE,
}

@export var id: StringName = &""
@export var display_name: String = "新遗物"
@export_multiline var description: String = ""
@export_multiline var effect_text: String = ""
@export var category: Category = Category.LOW
@export var icon_color: Color = Color(0.8, 0.8, 0.8, 1)
