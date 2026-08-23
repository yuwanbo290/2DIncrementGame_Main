extends Node
## 调试系统（Autoload：DebugSystem）。
## 仅编辑器/调试构建生效（OS.has_feature("editor")）；发布包中自动禁用，不提供任何功能，配合导出排除即不被打包。
## 控制台：反引号 ` 开关；指令见项目根目录「调试指令.md」。
## 功能：gold 加金币 / config 改 base_config 数值 / buff 战斗中加 Buff。


const CONSOLE_KEY := KEY_QUOTELEFT
const BG_COLOR := Color(0.05, 0.07, 0.1, 0.85)
const BORDER_COLOR := Color(0.35, 0.45, 0.6, 1)
const TEXT_COLOR := Color(0.85, 0.92, 1.0, 1)
const ACCENT_COLOR := Color(1, 0.85, 0.2, 1)

const HELP_TEXT := """可用指令：
  gold <数量>              添加金币（正数增加 / 负数扣减），如：gold 500
  config <key> <value>     调整 base_config 数值，如：config spawn_interval 1.5
  buff <id> [目标等级]      战斗中为 Buff 添加/提升等级，如：buff 1、buff 2 3
  clear                    清空控制台
  help                     显示本帮助
提示：
- buff 仅可在战斗场景中使用（需先进入战斗）
- config 的 key 见 Resources/Config/base_config.tres"""

## 控制台是否启用（发布包禁用）
var _enabled: bool = false
var _console: CanvasLayer
var _output: RichTextLabel
var _input: LineEdit


func _ready() -> void:
	_enabled = OS.has_feature("editor")
	if not _enabled:
		return
	_build_console()


func _unhandled_input(event: InputEvent) -> void:
	if not _enabled:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == CONSOLE_KEY:
			_toggle_console()
			get_viewport().set_input_as_handled()


# ---- 控制台 UI ----


func _build_console() -> void:
	_console = CanvasLayer.new()
	_console.layer = 100
	add_child(_console)

	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_right = 1.0
	panel.offset_left = 80.0
	panel.offset_top = 24.0
	panel.offset_right = -80.0
	panel.offset_bottom = 260.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = BORDER_COLOR
	panel.add_theme_stylebox_override("panel", style)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.custom_minimum_size = Vector2(0, 170)
	_output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_output.scroll_following = true
	_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_output.add_theme_color_override("default_color", TEXT_COLOR)
	_output.add_theme_font_size_override("normal_font_size", 15)

	_input = LineEdit.new()
	_input.placeholder_text = "输入指令（help 查看帮助；` 关闭控制台）"
	_input.add_theme_font_size_override("font_size", 16)
	_input.text_submitted.connect(_on_command_submitted)

	vbox.add_child(_output)
	vbox.add_child(_input)
	margin.add_child(vbox)
	panel.add_child(margin)
	_console.add_child(panel)
	_console.visible = false
	_print("调试控制台已开启（` 反引号开关）")


func _toggle_console() -> void:
	if _console == null:
		return
	_console.visible = not _console.visible
	if _console.visible:
		_input.grab_focus()
	else:
		_input.release_focus()


func _on_command_submitted(text: String) -> void:
	var trimmed: String = text.strip_edges()
	if trimmed == "":
		return
	_print("[color=#%s]> %s[/color]" % [ACCENT_COLOR.to_html(), trimmed])
	if trimmed.to_lower() == "clear":
		_output.clear()
	else:
		_print(execute_command(trimmed))
	_input.clear()


func _print(text: String) -> void:
	if _output != null:
		_output.append_text(text + "\n")


# ---- 指令解析与执行 ----


## 执行一条调试指令并返回结果文本（独立函数便于无头测试）。
func execute_command(line: String) -> String:
	var parts: PackedStringArray = line.strip_edges().split(" ", false)
	if parts.is_empty():
		return HELP_TEXT
	var cmd: String = parts[0].to_lower()
	match cmd:
		"help":
			return HELP_TEXT
		"gold":
			return _cmd_gold(parts)
		"config":
			return _cmd_config(parts)
		"buff":
			return _cmd_buff(parts)
		_:
			return "未知指令：%s（输入 help 查看可用指令）" % cmd


func _cmd_gold(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "用法：gold <数量>（正数增加 / 负数扣减）"
	var amount: int = parts[1].to_int()
	var new_gold: int = SaveSystem.add_gold(amount)
	SaveSystem.save()
	return "金币 %+d → 当前金币：%d" % [amount, new_gold]


func _cmd_config(parts: PackedStringArray) -> String:
	if parts.size() < 3:
		return "用法：config <key> <value>，如 config spawn_interval 1.5"
	var key: String = parts[1]
	if ConfigSystem.config == null:
		return "base_config 未加载"
	if not _config_has_key(key):
		return "base_config 中不存在字段：%s" % key
	# value 可能含空格（数组写法 [1, 2, 3]），用剩余部分重新拼接
	var value_str: String = " ".join(parts.slice(2))
	var current: Variant = ConfigSystem.config.get(key)
	var parsed: Variant
	match typeof(current):
		TYPE_FLOAT:
			if not value_str.is_valid_float():
				return "数值无效：%s" % value_str
			parsed = value_str.to_float()
		TYPE_INT:
			if not value_str.is_valid_int():
				return "数值无效：%s" % value_str
			parsed = value_str.to_int()
		TYPE_ARRAY:
			parsed = _parse_int_array(value_str)
		TYPE_STRING:
			parsed = value_str
		_:
			return "暂不支持该字段类型：%s" % type_string(typeof(current))
	ConfigSystem.config.set(key, parsed)
	return "config %s = %s" % [key, str(parsed)]


func _config_has_key(key: String) -> bool:
	for p in ConfigSystem.config.get_property_list():
		if p.name == key:
			return true
	return false


## 解析 "[1, 2, 3]" 形式的整型数组
func _parse_int_array(raw: String) -> Array[int]:
	var arr: Array[int] = []
	var cleaned: String = raw.strip_edges().trim_prefix("[").trim_suffix("]")
	for part in cleaned.split(","):
		arr.append(part.strip_edges().to_int())
	return arr


func _cmd_buff(parts: PackedStringArray) -> String:
	if parts.size() < 2:
		return "用法：buff <id> [目标等级]，如 buff 1 或 buff 2 3"
	var buff_id: int = parts[1].to_int()
	var bm: Node = _get_battle_manager()
	if bm == null:
		return "buff 仅可在战斗中添加（请先进入战斗场景）"
	var buff_row: Dictionary = TableDB.get_first("Buff", "Id", buff_id)
	if buff_row.is_empty():
		return "Buff 表中不存在 Id=%d" % buff_id
	var max_level: int = int(buff_row.get("maxLevel", 0))
	var current_level: int = int(bm._buff_levels.get(buff_id, 0))
	var target_level: int = current_level + 1
	if parts.size() >= 3:
		target_level = parts[2].to_int()
	if target_level <= current_level:
		return "Buff %d 当前已是 %d 级（目标 %d）" % [buff_id, current_level, target_level]
	if target_level > max_level:
		return "Buff %d 最大 %d 级（目标 %d）" % [buff_id, max_level, target_level]
	while current_level < target_level:
		if not bm.call("_apply_next_buff_level", buff_id):
			return "Buff %d 应用失败：缺少 buffLevel=%d 配置" % [buff_id, current_level + 1]
		current_level += 1
	return "Buff %d「%s」已升至 %d 级" % [buff_id, str(buff_row.get("buffName", "")), current_level]


## 获取当前战斗场景的 battle_manager 根节点（非战斗返回 null）
func _get_battle_manager() -> Node:
	# 优先当前场景根（battle.tscn 经 change_scene_to_file 加载时）
	var current: Node = get_tree().current_scene
	if current != null and _is_battle_manager(current):
		return current
	# 回退：场景树中查找 Battle 根节点（动态挂载/调试测试场景）
	var battle: Node = get_tree().root.get_node_or_null("Battle")
	if battle != null and _is_battle_manager(battle):
		return battle
	return null


func _is_battle_manager(node: Node) -> bool:
	var script: Script = node.get_script()
	return script != null and script.resource_path.ends_with("battle_manager.gd")

