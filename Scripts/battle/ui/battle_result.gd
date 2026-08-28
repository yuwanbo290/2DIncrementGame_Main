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


func _ready() -> void:
	_continue_btn.theme = UIBase.BUTTON_THEME
	_continue_btn.pressed.connect(_on_continue_pressed)
	visible = false


## 展示结算数据（调用方负责暂停场景树）
func show_result(total_damage: int, kills: int, gold: int, stage: int) -> void:
	_damage_label.text = "本局伤害：%d" % total_damage
	_kills_label.text = "击杀数量：%d" % kills
	_gold_label.text = "获得金币：%d" % gold
	_stage_label.text = "结束阶段：%d" % stage
	visible = true
	_continue_btn.grab_focus()


func _on_continue_pressed() -> void:
	continue_pressed.emit()
