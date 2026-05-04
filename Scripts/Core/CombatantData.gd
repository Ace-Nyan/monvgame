## CombatantData — 战斗者数据资源
##
## 把以前 @export 在 Combatant 节点上的字段抽离到独立 .tres，
## 便于：
##   - 模组覆盖（user://Enemies/、user://Players/）
##   - 在场景中通过 `data` 引用复用同一份配置
##   - 与 ModifierBus 配合做收藏品/事件全局加成
class_name CombatantData
extends Resource

## 唯一 ID。同时作为 ModifierBus ctx_filter 里 `enemy_id` 字段的依据
@export var id: StringName = &""
@export var display_name: String = "战士"
@export_enum("PLAYER", "ENEMY") var faction: int = 1

@export_group("基础数值")
@export var max_hp: int = 24
@export var max_ap: int = 2
@export var ap_regen_per_sec: float = 0.5
@export var hand_size: int = 3

@export_group("起始牌组（CardData id 列表）")
@export var starting_card_ids: Array[StringName] = []

@export_group("基础抗性")
@export var base_resistance: ResistanceProfile

@export_group("AI / 警戒（仅 ENEMY 阵营生效）")
@export var aggro_radius: float = 7.0
@export var leash_radius: float = 14.0
@export var ai_move_speed: float = 2.5
@export var ai_check_interval: float = 0.4

@export_group("外观")
## 用于身体节点 Visual 的缩放（石卫兵 1.2、小鬼 0.8 等）
@export var body_scale: Vector3 = Vector3.ONE
## 可选染色（叠在 Humanoid 上）
@export var visual_tint: Color = Color(1, 1, 1, 1)
