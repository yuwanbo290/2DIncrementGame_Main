class_name SkillTreeCanvas
extends Control
## 技能树连线画布：在技能节点之间绘制「前置 → 当前」的连线（out_of_battle_upgrade 专用）。
## 连线颜色按前置技能是否已解锁（等级 ≥ 1）区分：已解锁亮绿色、未解锁暗灰色。
## 数据由 out_of_battle_upgrade.setup() 注入：node_pos（skill_id -> 节点左上角位置）与 parent_map（skill_id -> 父 id）。


## 与 out_of_battle_upgrade.gd 的节点尺寸保持一致
const NODE_W := 200.0
const NODE_H := 160.0
## 已解锁连线的颜色
const LINE_ACTIVE := Color(0.7, 0.85, 0.4, 0.9)
## 未解锁连线的颜色
const LINE_LOCKED := Color(0.35, 0.35, 0.4, 0.6)


## skill_id -> 节点左上角位置（相对本画布）
var node_pos: Dictionary = {}
## skill_id -> 父 skill_id（根节点为 0）
var parent_map: Dictionary = {}


## 注入布局数据并重绘。
func setup(positions: Dictionary, parents: Dictionary) -> void:
	node_pos = positions
	parent_map = parents
	queue_redraw()


func clear_data() -> void:
	node_pos.clear()
	parent_map.clear()
	queue_redraw()


func _draw() -> void:
	for child_id in parent_map.keys():
		var parent_id: int = parent_map[child_id]
		if parent_id <= 0 or not node_pos.has(parent_id) or not node_pos.has(child_id):
			continue
		var from: Vector2 = node_pos[parent_id] + Vector2(NODE_W / 2.0, NODE_H)
		var to: Vector2 = node_pos[child_id] + Vector2(NODE_W / 2.0, 0.0)
		var unlocked: bool = SaveSystem.get_skill_level(parent_id) >= 1
		draw_line(from, to, LINE_ACTIVE if unlocked else LINE_LOCKED, 3.0)
