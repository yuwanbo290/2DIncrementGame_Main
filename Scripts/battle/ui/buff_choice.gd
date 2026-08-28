class_name BuffChoiceUI
extends Control
## 局内 Buff 三选一弹层。
##
## 本界面只负责展示 BattleManager 已整理好的候选数据，并在玩家点击后发出选择信号。
## 表格查询、随机抽取、等级记录和战斗属性修改全部由 BattleManager 负责，避免 UI 与战斗规则耦合。


# ---- 对外信号 ----

## 玩家选择一项升级时发出；参数始终是 Buff 主表中的 int 类型 Id。
signal buff_selected(buff_id: int)


# ---- 固定卡片节点与局部状态 ----

## 战斗管理器会用该容量限制抽取数量，确保配置误设为 3 以上时不会产生“抽到但未显示”的选项。
const CHOICE_CAPACITY := 3

## 首版固定显示三张卡，因此不为单张卡额外拆分脚本或子场景。
## 三个 Button 只在 _ready() 连接一次，重复打开弹层时仅替换显示数据，避免信号重复连接。
@onready var _choice_buttons: Array[Button] = [
	%Choice0 as Button,
	%Choice1 as Button,
	%Choice2 as Button,
]
@onready var _dimmer: Control = $Dimmer
@onready var _popup_panel: Control = $SafeMargin/Center/PopupPanel

## 按卡片下标保存对应的 Buff Id；隐藏卡片的位置使用 0 占位。
var _choice_ids: Array[int] = [0, 0, 0]
## 防止快速双击让同一个 Buff 在一次弹层中重复生效。
var _accepting_input: bool = false
## 卡片入场与选择反馈分别保留一个 Tween，重复打开时先终止旧状态。
var _opening_tween: Tween
var _selection_tween: Tween


# ---- 节点初始化 ----

func _ready() -> void:
	theme = UIBase.BUTTON_THEME
	for index in _choice_buttons.size():
		var button: Button = _choice_buttons[index]
		button.pressed.connect(_on_choice_pressed.bind(index))
		UIBase.bind_button(button)
	hide_choices()


# ---- 对外显示接口 ----

## 显示候选卡片。
##
## 每条候选数据由 BattleManager 组装，包含：
## id / name / next_level / max_level / prev_desc / next_desc。
## 当有效候选不足三项时，多余卡片会自动隐藏，避免出现可点击的空选项。
func show_choices(choices: Array[Dictionary]) -> void:
	if choices.is_empty():
		hide_choices()
		return

	if _opening_tween != null and _opening_tween.is_valid():
		_opening_tween.kill()
	if _selection_tween != null and _selection_tween.is_valid():
		_selection_tween.kill()

	_accepting_input = false
	visible = true
	UIBase.popup_in(_dimmer, _popup_panel)
	var last_reveal: Tween

	for index in _choice_buttons.size():
		var button: Button = _choice_buttons[index]
		_reset_card(button)
		if index >= choices.size():
			_choice_ids[index] = 0
			button.visible = false
			button.disabled = true
			continue

		var choice: Dictionary = choices[index]
		_choice_ids[index] = int(choice.get("id", 0))
		_fill_card(button, choice)
		button.visible = true
		button.disabled = true
		# 入场期间忽略 hover，避免按钮反馈 Tween 中断 reveal 后永远无法开放输入。
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		last_reveal = UIBase.reveal_card(button, index)

	# 最后一张卡完成入场后才开放输入，避免入场和选择 Tween 同时修改缩放。
	_opening_tween = last_reveal
	if _opening_tween != null:
		_opening_tween.finished.connect(_on_opening_finished)
	else:
		call_deferred("_on_opening_finished")


## 隐藏弹层并立即禁用所有卡片。
## BattleManager 在关闭弹层后负责恢复 SceneTree 的暂停状态。
func hide_choices() -> void:
	_accepting_input = false
	if _opening_tween != null and _opening_tween.is_valid():
		_opening_tween.kill()
	if _selection_tween != null and _selection_tween.is_valid():
		_selection_tween.kill()
	_opening_tween = null
	_selection_tween = null
	visible = false
	for button in _choice_buttons:
		button.disabled = true
		_reset_card(button)


# ---- 卡片内容与入场状态 ----

## Button 仍承担整张卡片的点击和焦点，子 Label 只负责建立名称、等级和效果层级。
func _fill_card(button: Button, choice: Dictionary) -> void:
	var content: Control = button.get_node("CardContent") as Control
	(content.get_node("NameLabel") as Label).text = str(choice.get("name", "未知升级"))
	(content.get_node("LevelLabel") as Label).text = "Lv.%d / %d" % [
		int(choice.get("next_level", 1)),
		int(choice.get("max_level", 1)),
	]
	(content.get_node("CurrentLabel") as Label).text = "当前：%s" % str(choice.get("prev_desc", "无"))
	(content.get_node("EffectLabel") as Label).text = str(choice.get("next_desc", ""))


## 缓存弹层再次打开前还原上一轮选择留下的透明度、缩放和焦点状态。
func _reset_card(button: Button) -> void:
	button.modulate = Color.WHITE
	button.scale = Vector2.ONE
	button.pivot_offset = button.size * 0.5
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_ALL
	button.release_focus()


func _on_opening_finished() -> void:
	_opening_tween = null
	if not visible:
		return
	_accepting_input = true
	var focus_target: Button
	for index in _choice_buttons.size():
		var button: Button = _choice_buttons[index]
		button.disabled = _choice_ids[index] <= 0
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		if focus_target == null and not button.disabled:
			focus_target = button
	if focus_target != null:
		focus_target.grab_focus()


# ---- 玩家选择处理 ----

func _on_choice_pressed(index: int) -> void:
	if not _accepting_input or index < 0 or index >= _choice_ids.size():
		return

	var buff_id: int = _choice_ids[index]
	if buff_id <= 0:
		return

	# 先关闭输入，待选择反馈结束后再发信号；战斗会在这段时间继续保持暂停。
	_accepting_input = false
	for button in _choice_buttons:
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var selected: Button = _choice_buttons[index]
	selected.pivot_offset = selected.size * 0.5
	var duration: float = 0.08 if UIBase.is_reduced_motion() else 0.12
	_selection_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)

	# 减少动态效果时仅保留短淡出；正常模式下选中卡同时轻微放大。
	if UIBase.is_reduced_motion():
		_selection_tween.tween_property(selected, "modulate:a", 1.0, duration)
	else:
		_selection_tween.tween_property(selected, "scale", Vector2(1.06, 1.06), duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for other_index in _choice_buttons.size():
		if other_index != index and _choice_buttons[other_index].visible:
			_selection_tween.tween_property(_choice_buttons[other_index], "modulate:a", 0.0, duration)
	_selection_tween.chain().tween_callback(_emit_selection.bind(buff_id))


func _emit_selection(buff_id: int) -> void:
	_selection_tween = null
	buff_selected.emit(buff_id)
