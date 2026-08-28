extends UIBase
## 局外养成界面：左侧传统技能树 + 右侧技能详情与升级。
## 左侧按 Skill 表 previouId 分层（缺失/0 = 根节点）排布可点击节点（点击选中，金色高亮），连线由 SkillTreeCanvas 绘制；
## 右侧读取 Skill / skillLevel 表文本展示：技能名/描述/等级/前置/下一级效果（skillLevel.desc）/升级费用与按钮。
## 升级消耗来自 skillLevel 表 upCost，等级存存档 skill_levels（落盘）。


## 技能节点尺寸（与 SkillTreeCanvas.NODE_W/H 保持一致）
const NODE_W := 160.0
const NODE_H := 120.0
## 同层节点水平间距
const H_GAP := 40.0
## 层间垂直间距
const V_GAP := 60.0
## 画布内边距
const PAD := 24.0
const BUTTON_SIZE := Vector2(200, 42)

const COLOR_TEXT := Color(1, 1, 1, 1)
const COLOR_DESC := Color(0.7, 0.7, 0.7, 1)
const COLOR_GOLD := Color(1, 0.85, 0.2, 1)
const COLOR_DISABLED := Color(0.5, 0.5, 0.5, 1)
const COLOR_WARN := Color(1, 0.3, 0.3, 1)
## 技能节点背景 / 边框（未解锁更暗；选中用金色边框）
const PANEL_BG := Color(0.12, 0.14, 0.18, 0.95)
const PANEL_BG_LOCKED := Color(0.08, 0.09, 0.12, 0.9)
const PANEL_BORDER := Color(0.3, 0.3, 0.4, 1)
const PANEL_BORDER_LOCKED := Color(0.2, 0.2, 0.25, 1)
const BORDER_SELECTED := Color(1, 0.85, 0.2, 1)


## 技能树画布（左侧 ScrollContainer 内）
var _canvas: SkillTreeCanvas
## 右侧详情容器
var _detail_vbox: VBoxContainer
## skill_id -> 父 skill_id（根为 0）
var _parent_map: Dictionary = {}
## skill_id -> 节点左上角位置（相对画布）
var _node_pos: Dictionary = {}
## 当前选中的技能 id（右侧详情 + 节点高亮）
var _selected_skill: int = 0


func _ready() -> void:
	($TopBar/BackBtn as Button).pressed.connect(_on_back_pressed)
	_canvas = $MainContainer/Panel/HBox/LeftMargin/ScrollContainer/TreeCanvas as SkillTreeCanvas
	if _canvas == null:
		push_error("[局外养成] 缺少 TreeCanvas 画布节点")
	_detail_vbox = $MainContainer/Panel/HBox/RightPanel/Margin/DetailVBox as VBoxContainer
	if _detail_vbox == null:
		push_error("[局外养成] 缺少 DetailVBox 详情容器")
	super()


func refresh() -> void:
	_refresh_gold()
	# 默认选中第一个技能（根节点）展示详情
	if _selected_skill <= 0:
		var rows: Array[Dictionary] = TableDB.rows_of("Skill")
		if not rows.is_empty():
			_selected_skill = int(rows[0].get("Id", 0))
	_build_tree()
	_build_detail()


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


## 构建单个技能节点（可点击 Button，点击选中并在右侧展示详情）。
func _build_node(skill_id: int, pos: Vector2) -> void:
	var row: Dictionary = TableDB.get_first("Skill", "Id", skill_id)
	if row.is_empty():
		return
	var level: int = SaveSystem.get_skill_level(skill_id)
	var max_level: int = int(row.get("maxLevel", 1))
	var pre: int = int(row.get("previouId", 0))
	var is_root: bool = pre <= 0
	var unlocked: bool = is_root or SaveSystem.get_skill_level(pre) >= 1
	var selected: bool = skill_id == _selected_skill

	var btn := Button.new()
	btn.position = pos
	btn.custom_minimum_size = Vector2(NODE_W, NODE_H)
	var bg: Color = PANEL_BG if unlocked else PANEL_BG_LOCKED
	var border: Color = BORDER_SELECTED if selected else (PANEL_BORDER if unlocked else PANEL_BORDER_LOCKED)
	btn.add_theme_stylebox_override("normal", _make_node_style(bg, border))
	btn.add_theme_stylebox_override("hover", _make_node_style(bg.lightened(0.05), border))
	btn.add_theme_stylebox_override("pressed", _make_node_style(bg.darkened(0.05), border))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if not unlocked:
		btn.text = "🔒 %s" % str(row.get("skillName", "未知"))
	else:
		btn.text = "%s\n等级 %d / %d" % [str(row.get("skillName", "未知")), level, max_level]
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", COLOR_TEXT if unlocked else COLOR_DISABLED)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT if unlocked else COLOR_DISABLED)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.pressed.connect(_on_node_pressed.bind(skill_id))
	_canvas.add_child(btn)


## 生成技能节点的 StyleBoxFlat。
func _make_node_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


## 点击技能节点：选中并刷新左侧高亮与右侧详情。
func _on_node_pressed(skill_id: int) -> void:
	if skill_id == _selected_skill:
		return
	_selected_skill = skill_id
	_build_tree()
	_build_detail()


## 读取指定技能指定等级的 skillLevel 效果描述（desc 列）；无配置返回空字符串。
func _get_level_desc(skill_id: int, level: int) -> String:
	for row in TableDB.get_all("skillLevel", "Id", skill_id):
		if int(row.get("skillLevel", 0)) == level:
			return str(row.get("desc", ""))
	return ""


## 构建右侧详情面板：读取 Skill / skillLevel 表文本展示技能信息与升级按钮。
func _build_detail() -> void:
	_clear_container(_detail_vbox)
	var skill_id: int = _selected_skill
	if skill_id <= 0:
		return
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

	# 技能名
	var name_label := Label.new()
	name_label.text = str(row.get("skillName", "未知"))
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", COLOR_GOLD)
	name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	name_label.add_theme_constant_override("outline_size", 3)
	_detail_vbox.add_child(name_label)

	# 技能描述（Skill.desc）
	var desc_label := Label.new()
	desc_label.text = str(row.get("desc", ""))
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", COLOR_DESC)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_vbox.add_child(desc_label)

	var sep := HSeparator.new()
	_detail_vbox.add_child(sep)

	# 当前等级
	var level_label := Label.new()
	level_label.text = "当前等级：%d / %d" % [level, max_level]
	level_label.add_theme_font_size_override("font_size", 17)
	level_label.add_theme_color_override("font_color", COLOR_TEXT)
	_detail_vbox.add_child(level_label)

	# 前置信息
	var pre_label := Label.new()
	if is_root:
		pre_label.text = "类型：基础技能（无前置）"
		pre_label.add_theme_color_override("font_color", COLOR_TEXT)
	else:
		var pre_row: Dictionary = TableDB.get_first("Skill", "Id", pre)
		var pre_ok: bool = SaveSystem.get_skill_level(pre) >= 1
		pre_label.text = "前置：%s（%s）" % [str(pre_row.get("skillName", "前置技能")), "已解锁" if pre_ok else "需至少 1 级"]
		pre_label.add_theme_color_override("font_color", COLOR_TEXT if pre_ok else COLOR_WARN)
	pre_label.add_theme_font_size_override("font_size", 15)
	_detail_vbox.add_child(pre_label)

	# 上一级 / 下一级效果（读取 skillLevel.desc 配置文本；上一级为 0 级显示「无」）
	var prev_desc: String = _get_level_desc(skill_id, level)
	var next_desc: String = _get_level_desc(skill_id, level + 1)
	if not unlocked:
		var lock_label := Label.new()
		lock_label.text = "🔒 未解锁：请先升级前置技能"
		lock_label.add_theme_font_size_override("font_size", 16)
		lock_label.add_theme_color_override("font_color", COLOR_WARN)
		_detail_vbox.add_child(lock_label)
	elif is_maxed or next_cost < 0:
		var max_label := Label.new()
		max_label.text = "已满级，无法继续升级"
		max_label.add_theme_font_size_override("font_size", 16)
		max_label.add_theme_color_override("font_color", COLOR_DISABLED)
		_detail_vbox.add_child(max_label)
	else:
		var prev_label := Label.new()
		prev_label.text = "上一级：%s" % ("无" if prev_desc == "" else prev_desc)
		prev_label.add_theme_font_size_override("font_size", 16)
		prev_label.add_theme_color_override("font_color", COLOR_DESC)
		prev_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_vbox.add_child(prev_label)

		var arrow_label := Label.new()
		arrow_label.text = "↓"
		arrow_label.add_theme_font_size_override("font_size", 20)
		arrow_label.add_theme_color_override("font_color", COLOR_GOLD)
		_detail_vbox.add_child(arrow_label)

		var next_label := Label.new()
		next_label.text = "下一级：%s" % (next_desc if next_desc != "" else "（未配置描述）")
		next_label.add_theme_font_size_override("font_size", 16)
		next_label.add_theme_color_override("font_color", COLOR_TEXT)
		next_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_vbox.add_child(next_label)

		var cost_label := Label.new()
		cost_label.text = "升级费用：%d 金币" % next_cost
		cost_label.add_theme_font_size_override("font_size", 16)
		cost_label.add_theme_color_override("font_color", COLOR_GOLD)
		_detail_vbox.add_child(cost_label)

	# 底部留白 + 升级按钮
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_child(spacer)

	var upg_btn: Button
	if not unlocked:
		upg_btn = _create_text_button("需前置技能", BUTTON_SIZE, COLOR_DISABLED)
		upg_btn.disabled = true
	elif is_maxed or next_cost < 0:
		upg_btn = _create_text_button("已满级", BUTTON_SIZE, COLOR_DISABLED)
		upg_btn.disabled = true
	else:
		var can_afford: bool = SaveSystem.get_gold() >= next_cost
		upg_btn = _create_text_button("升级（%d 金币）" % next_cost, BUTTON_SIZE, COLOR_TEXT if can_afford else COLOR_WARN)
		upg_btn.disabled = not can_afford
		if can_afford:
			upg_btn.pressed.connect(_on_upgrade_pressed.bind(skill_id, next_cost))
	upg_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_vbox.add_child(upg_btn)


## 查询指定技能指定等级的升级花费（无该等级配置返回 -1）。
func _get_level_cost(skill_id: int, level: int) -> int:
	var rows: Array[Dictionary] = TableDB.get_all("skillLevel", "Id", skill_id)
	for row in rows:
		if int(row.get("skillLevel", 0)) == level:
			return int(row.get("upCost", 0))
	return -1


## 升级技能：扣金币、等级 +1 并落盘，然后重建技能树与右侧详情。
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
	_build_detail()


func _on_back_pressed() -> void:
	UIManager.close_ui("out_of_battle_upgrade")
