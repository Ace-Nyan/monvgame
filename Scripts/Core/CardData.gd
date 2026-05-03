## CardData — 卡牌数据资源
##
## 这是一个 Godot Resource，可在编辑器里可视化编辑、保存为 .tres、被玩家修改。
## 模组化的核心载体。
class_name CardData
extends Resource

enum Intent {
	ATTACK,   # ⚔️
	DEFENSE,  # 🛡️
	BUFF,     # ✨
	DEBUFF,   # ☠️
	UTILITY,  # 🔧
}

enum Target {
	ENEMY,    # 单体敌人
	SELF,     # 自身
	ALL_ENEMIES,
	NONE,     # 不需要选择
}

@export var id: StringName = &""
@export var display_name: String = "新卡牌"
@export_multiline var description: String = ""

@export_group("成本")
@export_range(0, 10) var cost: int = 1                        ## AP 消耗

@export_group("帧数据（决定时间轴占位）")
@export_range(0, 50) var windup_frames: int = 5               ## 前摇：可被打断
@export_range(0, 50) var active_frames: int = 3               ## 生效：触发效果
@export_range(0, 50) var recovery_frames: int = 5             ## 后摇：受击放大

@export_group("分类")
@export var intent: Intent = Intent.ATTACK
@export var element: Element.Type = Element.Type.NONE
@export var target_kind: Target = Target.ENEMY

@export_group("效果")
@export var effects: Array[CardEffect] = []

@export_group("共鸣（持有此卡时调整玩家抗性）")
## 例：火牌 -> { FIRE: 0.05, WATER: -0.05 }
@export var resonance: Dictionary = {}

func total_frames() -> int:
	return windup_frames + active_frames + recovery_frames

func intent_icon() -> String:
	match intent:
		Intent.ATTACK: return "⚔"
		Intent.DEFENSE: return "🛡"
		Intent.BUFF: return "✨"
		Intent.DEBUFF: return "☠"
		Intent.UTILITY: return "🔧"
	return "?"
