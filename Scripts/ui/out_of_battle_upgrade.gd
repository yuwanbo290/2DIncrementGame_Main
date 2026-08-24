extends UIBase
## 局外养成界面：传统技能树升级模式。
## 布局由 Skill 表 previouId 决定（previouId 缺失/0 = 根节点）：按深度分层，同层水平均分、整层居中；
## 前置技能等级 ≥ 1 才解锁下级节点。每个节点显示名称/描述/等级/升级按钮，连线由 SkillTreeCanvas 绘制。
## 升级消耗来自 skillLevel 表（每技能每级 upCost），等级存存档 skill_levels（落盘）。


## 节点面板尺寸（与 SkillTreeCanvas.NODE_W/H 保持一致）
const NODE_W := 200.0
const NODE_H := 160.0
## 同层节点水平间距
const H_GAP := 48.0
## 层间垂直间距
const V_GAP := 72.0
## 画布内边距
const PAD := 24.0
const BUTTON_SIZE := Vector2(170, 42)

const COLOR_TEXT := Color(1, 1, 1, 1)
const COLOR_DESC := Color(0.7, 0.7, 0.7, 1)
const COLOR_GOLD := Color(1, 0.85, 0.2, 1)
const COLOR_DISABLED := Color(0.5, 0.5, 0.5, 1)
const COLOR_WARN := Color(1, 0.3, 0.3, 1)
## 节点面板背景 / 边框（未解锁时更暗）
const PANEL_BG := Color(0.12, 0.14, 0.18, 0.95)
const PANEL_BG_LOCKED := Color(0.08, 0.09, 0.12, 0.9)
const PANEL_BORDER := Color(0.3, 0.3, 0.4, 1)
const PANEL_BORDER_LOCKED := Color(0.2, 0.2, 0.25, 1)


## 技能节点画布（ScrollContainer 内）
var _canvas: SkillTreeCanvas
## skill_id -> 父 skill_id（根为 0）
var _parent_map: Dictionary = {}
## skill_id -> 节点左上角位置（相对画布）
var _node_pos: Dictionary = {}


func on_create():
	var back_btn: TextureButton = $TopBar/BackBtn as TextureButton
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		_add_hover(back_btn)
	_canvas = $MainContainer/Panel/VBox/Margin/ScrollContainer/TreeCanvas as SkillTreeCanvas
	if _canvas == null:
		push_error("[局外养成] 缺少 TreeCanvas 画布节点")


func on_open():
	super()
	_refresh_gold()
	_build_tree()


func on_close():
	super()


func on_destroy():
	super()
	_clear_tree()


func _refresh_gold() -> void:
	_refresh_gold_label($TopBar/GoldLabel as Label)


# ---- 技能树构建 ----

## 清空画布上的节点面板与连线数据。
func _clear_tree() -> void:
	if _canvas == null:
		return
	for child in _canvas.get_children():
		child.queue_free()
	_parent_map.clear()
	_node_pos.clear()
	_canvas.clear_data()


## 读取 Skill 表构建技能树：分层排布节点面板并刷新连线。
func _build_tree() -> void:
	_clear_tree()
	var rows: Array[Dictionary] = TableDB.rows_of("Skill")
	if rows.is_empty():
		return

	# 1. 建立父子关系与深度（previouId 缺失/0 = 根节点；异常引用兜底为根）
	var children_of: Dictionary = {}
	var all_ids: Array[int] = []
	for row in rows:
		var sid: int = int(row.get("Id", 0))
		children_of[sid] = []
		all_ids.append(sid)
	for row in rows:
		var sid: int = int(row.get("Id", 0))
		var pre: int = int(row.get("previouId", 0))
		_parent_map[sid] = pre
		if pre > 0 and children_of.has(pre):
			children_of[pre].append(sid)

	# BFS 分层：根深度 0，子深度 = 父深度 + 1
	var depth_of: Dictionary = {}
	for row in rows:
		var sid: int = int(row.get("Id", 0))
		var pre: int = int(row.get("previouId", 0))
		if pre <= 0 or not all_ids.has(pre):
			depth_of[sid] = 0
	var queue: Array[int] = []
	for sid in all_ids:
		if depth_of.get(sid, -1) == 0:
			queue.append(sid)
	var head: int = 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		for child in children_of[cur]:
			depth_of[child] = depth_of[cur] + 1
			queue.append(child)

	# 2. 按深度分层，同层水平均分、整层居中
	var layers: Dictionary = {}
	for sid in all_ids:
		var d: int = int(depth_of.get(sid, 0))
		if not layers.has(d):
			layers[d] = []
		layers[d].append(sid)
	var max_layer_count: int = 1
	var depth_max: int = 0
	for d in layers.keys():
		max_layer_count = maxi(max_layer_count, layers[d].size())
		depth_max = maxi(depth_max, d)

	var canvas_w: float = PAD * 2.0 + max_layer_count * NODE_W + (max_layer_count - 1) * H_GAP
	var canvas_h: float = PAD * 2.0 + (depth_max + 1) * NODE_H + depth_max * V_GAP
	_canvas.custom_minimum_size = Vector2(canvas_w, canvas_h)

	for d in layers.keys():
		var ids: Array = layers[d]
		var layer_w: float = ids.size() * NODE_W + (ids.size() - 1) * H_GAP
		var start_x: float = (canvas_w - layer_w) / 2.0
		for i in ids.size():
			var sid: int = ids[i]
			var pos := Vector2(start_x + i * (NODE_W + H_GAP), PAD + d * (NODE_H + V_GAP))
			_node_pos[sid] = pos
			_build_node(sid, pos)

	_canvas.setup(_node_pos, _parent_map)


## 构建单个技能节点面板。
func _build_node(skill_id: int, pos: Vector2) -> void:
	var row: Dictionary = TableDB.get_first("Skill", "Id", skill_id)
	if row.is_empty():
		return
	var level: int = SaveSystem.get_skill_level(skill_id)
	var max_level: int = int(row.get("maxLevel", 1))
	var pre: int = int(row.get("previouId", 0))
	var is_root: bool = pre <= 0
	var unlocked: bool = is_root or SaveSystem.get_skill_level(pre) >= 1
	var is_maxed: bool = level >= max_level
	var next_cost: int = _get_level_cost(skill_id, level + 1)  # -1 = 无下一级配置

	var panel := PanelContainer.new()
	panel.position = pos
	panel.custom_minimum_size = Vector2(NODE_W, NODE_H)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = PANEL_BG if unlocked else PANEL_BG_LOCKED
	style.border_color = PANEL_BORDER if unlocked else PANEL_BORDER_LOCKED
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	if not unlocked:
		panel.modulate = Color(0.75, 0.75, 0.75, 0.85)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var name_label := Label.new()
	name_label.text = str(row.get("skillName", "未知"))
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var desc_label := Label.new()
	desc_label.text = str(row.get("desc", ""))
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.add_theme_color_override("font_color", COLOR_DESC)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var level_label := Label.new()
	if unlocked:
		level_label.text = "等级 %d / %d" % [level, max_level]
	else:
		level_label.text = "🔒 未解锁"
	level_label.add_theme_font_size_override("font_size", 14)
	level_label.add_theme_color_override("font_color", COLOR_GOLD if unlocked else COLOR_DISABLED)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	vbox.add_child(name_label)
	vbox.add_child(desc_label)
	vbox.add_child(level_label)

	# 升级按钮：锁定 / 满级 / 金币不足 均禁用，仅可升级时可点击
	var btn: TextureButton
	if not unlocked:
		btn = _create_text_button("需前置技能", BUTTON_SIZE, COLOR_DISABLED)
		btn.disabled = true
	elif is_maxed or next_cost < 0:
		btn = _create_text_button("已满级", BUTTON_SIZE, COLOR_DISABLED)
		btn.disabled = true
	else:
		var can_afford: bool = SaveSystem.get_gold() >= next_cost
		btn = _create_text_button("升级 %d" % next_cost, BUTTON_SIZE, COLOR_TEXT if can_afford else COLOR_WARN)
		btn.disabled = not can_afford
		if can_afford:
			btn.pressed.connect(_on_upgrade_pressed.bind(skill_id, next_cost))
			_add_hover(btn)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(btn)

	margin.add_child(vbox)
	panel.add_child(margin)
	_canvas.add_child(panel)


## 查询指定技能指定等级的升级花费（无该等级配置返回 -1）。
func _get_level_cost(skill_id: int, level: int) -> int:
	var rows: Array[Dictionary] = TableDB.get_all("skillLevel", "Id", skill_id)
	for row in rows:
		if int(row.get("skillLevel", 0)) == level:
			return int(row.get("upCost", 0))
	return -1


## 升级技能：扣金币、等级 +1 并落盘，然后重建技能树刷新所有节点状态与连线。
func _on_upgrade_pressed(skill_id: int, cost: int) -> void:
	var gold: int = SaveSystem.get_gold()
	if gold < cost:
		return
	var level: int = SaveSystem.get_skill_level(skill_id)
	SaveSystem.set_gold(gold - cost)
	SaveSystem.set_skill_level(skill_id, level + 1)
	SaveSystem.save()
	_refresh_gold()
	_build_tree()


func _on_back_pressed() -> void:
	UIManager.close_ui("out_of_battle_upgrade")
