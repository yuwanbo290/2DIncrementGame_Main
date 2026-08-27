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

## 按卡片下标保存对应的 Buff Id；隐藏卡片的位置使用 0 占位。
var _choice_ids: Array[int] = [0, 0, 0]
## 防止快速双击让同一个 Buff 在一次弹层中重复生效。
var _accepting_input: bool = false


# ---- 节点初始化 ----

func _ready() -> void:
	for index in _choice_buttons.size():
		_choice_buttons[index].pressed.connect(_on_choice_pressed.bind(index))
	hide_choices()


# ---- 对外显示接口 ----

## 显示候选卡片。
##
## 每条候选数据由 BattleManager 组装，包含：
## id / name / description / next_level / max_level / effect_text。
## 当有效候选不足三项时，多余卡片会自动隐藏，避免出现可点击的空选项。
func show_choices(choices: Array[Dictionary]) -> void:
	_accepting_input = not choices.is_empty()
	visible = _accepting_input

	for index in _choice_buttons.size():
		var button: Button = _choice_buttons[index]
		if index >= choices.size():
			_choice_ids[index] = 0
			button.visible = false
			button.disabled = true
			continue

		var choice: Dictionary = choices[index]
		_choice_ids[index] = int(choice.get("id", 0))
		button.text = _format_card_text(choice)
		button.visible = true
		button.disabled = false

	# 为键盘/手柄操作提供一个明确的初始焦点；鼠标操作不受影响。
	if _accepting_input:
		_choice_buttons[0].grab_focus()


## 隐藏弹层并立即禁用所有卡片。
## BattleManager 在关闭弹层后负责恢复 SceneTree 的暂停状态。
func hide_choices() -> void:
	_accepting_input = false
	visible = false
	for button in _choice_buttons:
		button.disabled = true


# ---- 卡片文本组装 ----

## 固定卡片使用一个 Button 的多行文字显示全部信息，从而减少重复节点和脚本数量。
## 展示「上一级 → 下一级」效果（上一级为 0 级显示「无」）。
func _format_card_text(choice: Dictionary) -> String:
	return "%s\n升级至 Lv.%d / %d\n\n上一级：%s\n↓\n下一级：%s" % [
		str(choice.get("name", "未知升级")),
		int(choice.get("next_level", 1)),
		int(choice.get("max_level", 1)),
		str(choice.get("prev_desc", "无")),
		str(choice.get("next_desc", "")),
	]


# ---- 玩家选择处理 ----

func _on_choice_pressed(index: int) -> void:
	if not _accepting_input or index < 0 or index >= _choice_ids.size():
		return

	var buff_id: int = _choice_ids[index]
	if buff_id <= 0:
		return

	# 先关闭输入再发信号，确保同一帧内的快速双击只会生效一次。
	_accepting_input = false
	for button in _choice_buttons:
		button.disabled = true
	buff_selected.emit(buff_id)
