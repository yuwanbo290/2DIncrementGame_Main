class_name BattleResultUI
extends Control
## 战斗结算弹层：战斗结束后展示本局伤害/击杀/金币/阶段，玩家确认后返回备战界面。
## 本界面只负责展示与发出确认信号；金币落盘与场景切换由 BattleManager 负责。
## 参考 BuffChoiceUI：process_mode=ALWAYS，暂停期间按钮仍可响应。


## 玩家点击「返回备战」时发出
signal continue_pressed

@onready var _damage_label: Label = %DamageLabel
@onready var _kills_label: Label = %KillsLabel
@onready var _gold_label: Label = %GoldLabel
@onready var _stage_label: Label = %StageLabel
@onready var _continue_btn: Button = %ContinueBtn
@onready var _popup_panel: PanelContainer = %PopupPanel
@onready var _dimmer: ColorRect = $Dimmer
@onready var _stat_cards: Array[Control] = [
	$SafeMargin/Center/PopupPanel/Margin/Content/StatsGrid/DamageCard,
	$SafeMargin/Center/PopupPanel/Margin/Content/StatsGrid/KillsCard,
	$SafeMargin/Center/PopupPanel/Margin/Content/StatsGrid/GoldCard,
	$SafeMargin/Center/PopupPanel/Margin/Content/StatsGrid/StageCard,
]


func _ready() -> void:
	_continue_btn.pressed.connect(_on_continue_pressed)
	UIBase.bind_button(_continue_btn)
	visible = false


## 展示结算数据（调用方负责暂停场景树）
func show_result(total_damage: int, kills: int, gold: int, stage: int) -> void:
	visible = true
	UIBase.popup_in(_dimmer, _popup_panel)
	for index in _stat_cards.size():
		UIBase.reveal_card(_stat_cards[index], index)
	UIBase.count_label(_damage_label, total_damage, "%d")
	UIBase.count_label(_kills_label, kills, "%d")
	UIBase.count_label(_gold_label, gold, "%d")
	UIBase.count_label(_stage_label, stage, "%d")
	_continue_btn.grab_focus()


func _on_continue_pressed() -> void:
	continue_pressed.emit()
