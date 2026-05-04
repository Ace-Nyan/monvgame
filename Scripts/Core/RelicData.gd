## RelicData — 收藏品资源
##
## 一个收藏品 = 若干个 ModifierBus 修饰条目 + 元数据。
## 拾取时 RelicRegistry 把它们注册到 ModifierBus，扔掉/失效时反注册。
##
## modifiers 数组里每一项是 Dictionary：
##   {
##     "key": &"enemy_max_hp",     # 修饰键名
##     "op": "add" | "mul" | "override",
##     "value": 1.2,
##     "filter_enemy_id": &"fire_imp"  # 可选：只对此 id 的敌人生效
##   }
class_name RelicData
extends Resource

@export var id: StringName = &""
@export var display_name: String = "未命名收藏品"
@export_multiline var description: String = ""
@export var icon_color: Color = Color(1, 0.85, 0.4, 1)

@export var modifiers: Array[Dictionary] = []
