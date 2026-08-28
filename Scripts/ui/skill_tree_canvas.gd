class_name SkillTreeCanvas
extends Control
## 技能树连线画布：在六边形节点之间绘制「前置 → 当前」的连线（out_of_battle_upgrade 专用）。
## 已升级分支为旧金、可升级分支为苔绿、未解锁分支为深灰绿。
## 数据由 out_of_battle_upgrade.setup() 注入：node_pos（skill_id -> 节点左上角位置）与 parent_map（skill_id -> 父 id）。


## 与 out_of_battle_upgrade.gd 的节点尺寸保持一致
const NODE_W := 112.0
const NODE_H := 120.0
const HEX_TOP := 2.0
const NODE_LINK_BOTTOM := NODE_H - 8.0
## 技能状态连线颜色
const LINE_UPGRADED := Color(0.901961, 0.721569, 0.290196, 0.95)
const LINE_AVAILABLE := Color(0.658824, 0.827451, 0.356863, 0.9)
const LINE_LOCKED := Color(0.38, 0.42, 0.39, 0.72)
const LINE_SHADOW := Color(0.0196078, 0.027451, 0.0235294, 0.7)


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
		var from: Vector2 = node_pos[parent_id] + Vector2(NODE_W / 2.0, NODE_LINK_BOTTOM)
		var to: Vector2 = node_pos[child_id] + Vector2(NODE_W / 2.0, HEX_TOP)
		var parent_upgraded: bool = SaveSystem.get_skill_level(parent_id) >= 1
		var child_upgraded: bool = SaveSystem.get_skill_level(child_id) >= 1
		var color: Color = LINE_UPGRADED if child_upgraded else (LINE_AVAILABLE if parent_upgraded else LINE_LOCKED)
		draw_line(from, to, LINE_SHADOW, 5.0)
		draw_line(from, to, color, 2.5)
		draw_circle(from, 3.5, color)
		draw_circle(to, 3.5, color)
