## CollectiblePickup — 可拾取的收藏品节点
##
## 用法：场景里挂一个 Area3D（脚本=本文件），设置 relic_id 字段。
## 玩家进入时调用 RelicRegistry.collect(relic_id) 并消失。
extends Area3D

@export var relic_id: StringName = &""
@export var float_amplitude: float = 0.2
@export var spin_speed: float = 1.5

var _t: float = 0.0
var _base_y: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# 自动找一个 MeshInstance3D 作为视觉，并染上 RelicData.icon_color
	var mesh: MeshInstance3D = null
	for c in get_children():
		if c is MeshInstance3D:
			mesh = c
			break
	if mesh and RelicRegistry:
		var def: RelicData = RelicRegistry.get_def(relic_id)
		if def and mesh.get_active_material(0) is StandardMaterial3D:
			var mat: StandardMaterial3D = mesh.get_active_material(0).duplicate()
			mat.albedo_color = def.icon_color
			mat.emission_enabled = true
			mat.emission = def.icon_color
			mat.emission_energy_multiplier = 0.6
			mesh.material_override = mat
	_base_y = position.y

func _process(delta: float) -> void:
	_t += delta
	position.y = _base_y + sin(_t * 2.0) * float_amplitude
	rotate_y(spin_speed * delta)

func _on_body_entered(body: Node) -> void:
	# 只让玩家拾取（玩家身上的 Combatant.faction == PLAYER）
	var combatant := body.get_node_or_null("Combatant") as Combatant
	if combatant == null or combatant.data == null:
		return
	if combatant.data.faction != Combatant.Faction.PLAYER:
		return
	if RelicRegistry.collect(relic_id):
		queue_free()
