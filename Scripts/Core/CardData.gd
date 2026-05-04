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

enum Rarity {
	WHITE,
	BLUE,
	GOLD,
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
@export var rarity: Rarity = Rarity.WHITE

@export_group("标签")
## retain: 回合结束时保留在手牌中
@export var retain: bool = false
## exhaust: 使用后移除（不进入弃牌堆）
@export var exhaust: bool = false

@export_group("射程与表演")
## 射程（米）。melee ≈ 2.0；ranged ≈ 12.0；self ≈ 0
@export_range(0.0, 30.0, 0.5) var range_m: float = 2.0
## 视场角（度）：自动锁定时只考虑前方此角度内的目标
@export_range(15.0, 360.0, 5.0) var aim_cone_deg: float = 90.0
## 动画类别 ID。LimbAnimator 用它决定肢体怎么动：
##   "swing_r" 右手挥砍 / "swing_l" 左手挥砍 / "thrust" 直刺
##   "cast" 双手举起施法 / "guard" 双手抬起防御 / "stomp" 踏步
@export var anim_id: StringName = &"swing_r"
## 投射物（远程攻击时使用）。留空 = 近战
@export var projectile_scene: PackedScene

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
