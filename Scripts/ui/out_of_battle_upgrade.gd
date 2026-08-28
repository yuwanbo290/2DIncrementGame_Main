extends UIBase
## 局外养成界面：左侧六边形技能树 + 右侧技能详情与升级。
## 左侧按 Skill 表 previouId 分层（缺失/0 = 根节点）排布图标节点，连线由 SkillTreeCanvas 绘制；
## 右侧读取 Skill / skillLevel 表文本展示：技能名/描述/等级/前置/下一级效果（skillLevel.desc）/升级费用与按钮。
## 升级消耗来自 skillLevel 表 upCost，等级存存档 skill_levels（落盘）。


## 技能节点尺寸（与 SkillTreeCanvas.NODE_W/H 保持一致）
const NODE_W := 112.0
const NODE_H := 120.0
## 同层节点水平间距
const H_GAP := 20.0
## 层间垂直间距
const V_GAP := 42.0
## 画布内边距
const PAD := 72.0
const BUTTON_SIZE := Vector2(200, 42)
const UI_ICONS := preload("res://Textures/ui/moss_ember_icons.png")

## 复用现有 32 像素图集；技能 ID 只负责选择对应图标区域。
const SKILL_ICON_REGIONS := {
	1: Rect2(0, 32, 32, 32),
	2: Rect2(32, 0, 32, 32),
	3: Rect2(64, 0, 32, 32),
	4: Rect2(96, 0, 32, 32),
	5: Rect2(64, 32, 32, 32),
	6: Rect2(64, 0, 32, 32),
	7: Rect2(0, 32, 32, 32),
	8: Rect2(32, 32, 32, 32),
	9: Rect2(32, 64, 32, 32),
	10: Rect2(32, 32, 32, 32),
	11: Rect2(32, 0, 32, 32),
}

static var HEX_OUTER: PackedVector2Array = PackedVector2Array([
	Vector2(56, 2), Vector2(104, 23), Vector2(104, 65),
	Vector2(56, 86), Vector2(8, 65), Vector2(8, 23),
])
static var HEX_INNER: PackedVector2Array = PackedVector2Array([
	Vector2(56, 7), Vector2(99, 26), Vector2(99, 62),
	Vector2(56, 81), Vector2(13, 62), Vector2(13, 26),
])

const COLOR_TEXT := Color(0.94902, 0.917647, 0.843137, 1)
const COLOR_DESC := Color(0.666667, 0.713725, 0.67451, 1)
const COLOR_GOLD := Color(0.901961, 0.721569, 0.290196, 1)
const COLOR_AVAILABLE := Color(0.658824, 0.827451, 0.356863, 1)
const COLOR_DISABLED := Color(0.666667, 0.713725, 0.67451, 0.65)
const COLOR_WARN := Color(0.886275, 0.415686, 0.239216, 1)
## 六边形内部颜色；外框颜色由已升级 / 可升级 / 未解锁状态决定。
const PANEL_BG := Color(0.0784314, 0.101961, 0.0941176, 0.97)
const PANEL_BG_LOCKED := Color(0.0509804, 0.0666667, 0.0588235, 0.94)
const PANEL_BORDER_LOCKED := Color(0.36, 0.39, 0.37, 0.9)
const BORDER_SELECTED := Color(0.901961, 0.721569, 0.290196, 1)


## 技能树画布（左侧 ScrollContainer 内）
var _canvas: SkillTreeCanvas
## 右侧详情容器
var _detail_vbox: VBoxContainer
## skill_id -> 父 skill_id（根为 0）
var _parent_map: Dictionary = {}
## skill_id -> 节点左上角位置（相对画布）
var _node_pos: Dictionary = {}
## skill_id -> 运行时按钮，用于焦点恢复与单节点升级反馈。
var _node_buttons: Dictionary = {}
## 当前选中的技能 id（右侧详情 + 节点高亮）
var _selected_skill: int = 0
## 页面打开时居中一次；节点选择和升级重建时保留玩家拖动的位置。
var _center_tree_on_build: bool = true

@onready var _back_btn: Button = %BackBtn
@onready var _gold_label: Label = %GoldLabel


func _ready() -> void:
	_back_btn.pressed.connect(_on_back_pressed)
	_canvas = $MainContainer/Panel/HBox/LeftMargin/TreeViewport/TreeCanvas as SkillTreeCanvas
	if _canvas == null:
		push_error("[局外养成] 缺少 TreeCanvas 画布节点")
	_detail_vbox = $MainContainer/Panel/HBox/RightPanel/Margin/DetailVBox as VBoxContainer
	if _detail_vbox == null:
		push_error("[局外养成] 缺少 DetailVBox 详情容器")
	super()


func refresh() -> void:
	_refresh_gold()
	_center_tree_on_build = true
	# 默认选中第一个技能（根节点）展示详情
	if _selected_skill <= 0:
		var rows: Array[Dictionary] = TableDB.rows_of("Skill")
		if not rows.is_empty():
			_selected_skill = int(rows[0].get("Id", 0))
	_build_tree()
	_build_detail()


func _refresh_gold() -> void:
	_refresh_gold_label(_gold_label)


# ---- 技能树构建 ----

## 清空画布上的节点面板与连线数据。
func _clear_tree() -> void:
	if _canvas == null:
		return
	for child in _canvas.get_children():
		child.queue_free()
	_parent_map.clear()
	_node_pos.clear()
	_node_buttons.clear()
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
	_canvas.size = Vector2(canvas_w, canvas_h)

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
	_configure_tree_focus()
	if _center_tree_on_build:
		_center_tree_on_build = false
		call_deferred("_center_tree_canvas")


## 页面打开后把自由画布放回视口中央；拖动期间不限制位置。
func _center_tree_canvas() -> void:
	var viewport := _canvas.get_parent() as Control
	if viewport:
		_canvas.position = (viewport.size - _canvas.size) / 2.0


## 构建单个六边形技能节点；Button 继续负责原生点击、焦点与方向键交互。
func _build_node(skill_id: int, pos: Vector2) -> void:
	var row: Dictionary = TableDB.get_first("Skill", "Id", skill_id)
	if row.is_empty():
		return
	var level: int = SaveSystem.get_skill_level(skill_id)
	var max_level: int = int(row.get("maxLevel", 1))
	var pre: int = int(row.get("previouId", 0))
	var is_root: bool = pre <= 0
	var unlocked: bool = is_root or SaveSystem.get_skill_level(pre) >= 1
	var upgraded: bool = level > 0
	var selected: bool = skill_id == _selected_skill

	var btn := Button.new()
	btn.position = pos
	btn.size = Vector2(NODE_W, NODE_H)
	btn.custom_minimum_size = Vector2(NODE_W, NODE_H)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty_style := StyleBoxEmpty.new()
	for state in [&"normal", &"hover", &"pressed", &"focus"]:
		btn.add_theme_stylebox_override(state, empty_style)

	var state_color: Color = COLOR_GOLD if upgraded else (COLOR_AVAILABLE if unlocked else PANEL_BORDER_LOCKED)
	var outer := Polygon2D.new()
	outer.polygon = HEX_OUTER
	outer.color = state_color
	btn.add_child(outer)

	var inner := Polygon2D.new()
	inner.polygon = HEX_INNER
	inner.color = PANEL_BG if unlocked else PANEL_BG_LOCKED
	btn.add_child(inner)

	if selected:
		var selection := Line2D.new()
		selection.points = HEX_OUTER
		selection.add_point(HEX_OUTER[0])
		selection.width = 2.0
		selection.default_color = BORDER_SELECTED
		btn.add_child(selection)

	var icon_region: Rect2 = Rect2(96, 32, 32, 32) if not unlocked else SKILL_ICON_REGIONS.get(skill_id, Rect2(64, 0, 32, 32))
	var icon := TextureRect.new()
	icon.position = Vector2(38, 20)
	icon.size = Vector2(36, 36)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _create_atlas_icon(icon_region)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.modulate = COLOR_DISABLED if not unlocked else (COLOR_GOLD if upgraded else COLOR_TEXT)
	btn.add_child(icon)

	var level_label := Label.new()
	level_label.position = Vector2(12, 58)
	level_label.size = Vector2(88, 18)
	level_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_label.text = "" if not unlocked else "%d / %d" % [level, max_level]
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_label.add_theme_font_size_override("font_size", 12)
	level_label.add_theme_color_override("font_color", COLOR_GOLD if upgraded else COLOR_AVAILABLE)
	btn.add_child(level_label)

	var skill_name: String = str(row.get("skillName", "未知"))
	var name_label := Label.new()
	name_label.position = Vector2(0, 91)
	name_label.size = Vector2(NODE_W, 22)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = skill_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", COLOR_TEXT if unlocked else COLOR_DISABLED)
	btn.add_child(name_label)

	var status_text: String = "等级 %d / %d" % [level, max_level] if unlocked else "未解锁"
	btn.tooltip_text = "%s · %s" % [skill_name, status_text]
	btn.pressed.connect(_on_node_pressed.bind(skill_id))
	_canvas.add_child(btn)
	_node_buttons[skill_id] = btn
	UIBase.bind_button(btn)

## 直接从现有图集裁切图标，避免引入额外图标管理层。
func _create_atlas_icon(region: Rect2) -> AtlasTexture:
	var icon := AtlasTexture.new()
	icon.atlas = UI_ICONS
	icon.region = region
	return icon


## 返回键向下进入当前技能；根技能向上仍能回到返回键。
func _configure_tree_focus() -> void:
	_back_btn.focus_neighbor_bottom = NodePath()
	var selected_button: Button = _node_buttons.get(_selected_skill) as Button
	if is_instance_valid(selected_button):
		_back_btn.focus_neighbor_bottom = _back_btn.get_path_to(selected_button)
	for skill_id in _node_buttons.keys():
		var button: Button = _node_buttons[skill_id] as Button
		if int(_parent_map.get(skill_id, 0)) <= 0:
			button.focus_neighbor_top = button.get_path_to(_back_btn)


## 点击技能节点：选中并刷新左侧高亮与右侧详情。
func _on_node_pressed(skill_id: int) -> void:
	if skill_id == _selected_skill:
		return
	_selected_skill = skill_id
	_build_tree()
	_build_detail()
	call_deferred("_restore_skill_focus", skill_id, false)


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
		lock_label.text = "未解锁：请先升级前置技能"
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
			upg_btn.theme_type_variation = &"PrimaryButton"
			upg_btn.pressed.connect(_on_upgrade_pressed.bind(skill_id, next_cost))
	upg_btn.icon = _create_atlas_icon(Rect2(64, 32, 32, 32))
	upg_btn.add_theme_constant_override("icon_max_width", 20)
	upg_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_detail_vbox.add_child(upg_btn)

	# 详情动作与当前节点建立水平导航，保留原生方向键行为。
	var selected_button: Button = _node_buttons.get(skill_id) as Button
	if not upg_btn.disabled and is_instance_valid(selected_button):
		selected_button.focus_neighbor_right = selected_button.get_path_to(upg_btn)
		upg_btn.focus_neighbor_left = upg_btn.get_path_to(selected_button)


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
	call_deferred("_restore_skill_focus", skill_id, true)


## 重建后恢复升级节点焦点；仅成功升级时对该节点做一次脉冲反馈。
func _restore_skill_focus(skill_id: int, pulse_node: bool) -> void:
	var button: Button = _node_buttons.get(skill_id) as Button
	if not is_instance_valid(button):
		return
	button.grab_focus()
	if pulse_node:
		UIBase.pulse(button)


func _on_back_pressed() -> void:
	UIManager.close_ui("out_of_battle_upgrade")
