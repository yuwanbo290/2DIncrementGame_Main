class_name PauseMenuUI
extends Control
## 战斗暂停菜单：展示当前玩家属性（含 Buff 括号加成），可继续战斗或返回备战。
## 参考 BattleResultUI：process_mode=ALWAYS，暂停期间按钮仍可响应。


signal resume_pressed
signal quit_pressed

@onready var _stats_label: Label = %StatsLabel
@onready var _resume_btn: Button = %ResumeBtn
@onready var _quit_btn: Button = %QuitBtn
@onready var _popup_panel: PanelContainer = %PopupPanel
@onready var _dimmer: ColorRect = $Dimmer


func _ready() -> void:
	_resume_btn.pressed.connect(func(): resume_pressed.emit())
	_quit_btn.pressed.connect(func(): quit_pressed.emit())
	UIBase.bind_button(_resume_btn)
	UIBase.bind_button(_quit_btn)
	visible = false


## 展示玩家属性（stats 来自 battle_manager.get_in_run_stats()）。
func show_menu(stats: Dictionary) -> void:
	_stats_label.text = PlayerStatsService.format_stats(stats)
	visible = true
	UIBase.popup_in(_dimmer, _popup_panel)
	_resume_btn.grab_focus()


func hide_menu() -> void:
	visible = false
