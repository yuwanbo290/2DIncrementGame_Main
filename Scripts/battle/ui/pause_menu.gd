class_name PauseMenuUI
extends Control
## 战斗暂停菜单：展示当前玩家属性（含 Buff 括号加成），可继续战斗或返回备战。
## 参考 BattleResultUI：process_mode=ALWAYS，暂停期间按钮仍可响应。


signal resume_pressed
signal quit_pressed

var _stats_label: Label
var _resume_btn: TextureButton
var _quit_btn: TextureButton


func _ready() -> void:
	# 显式在 _ready 初始化，避免动态实例化时 unique name 尚未注册
	_stats_label = get_node("%StatsLabel") as Label
	_resume_btn = get_node("%ResumeBtn") as TextureButton
	_quit_btn = get_node("%QuitBtn") as TextureButton
	_resume_btn.pressed.connect(func(): resume_pressed.emit())
	_quit_btn.pressed.connect(func(): quit_pressed.emit())
	# 与 UIBase._add_hover 一致的提亮效果
	for btn in [_resume_btn, _quit_btn]:
		btn.modulate = Color(1.15, 1.15, 1.15, 1)
		btn.mouse_entered.connect(func(): btn.modulate = Color(1.3, 1.3, 1.3, 1))
		btn.mouse_exited.connect(func(): btn.modulate = Color(1.15, 1.15, 1.15, 1))
	visible = false


## 展示玩家属性（stats 来自 battle_manager.get_in_run_stats()）。
func show_menu(stats: Dictionary) -> void:
	if _stats_label:
		_stats_label.text = PlayerStatsService.format_stats(stats)
	visible = true
	if _resume_btn:
		_resume_btn.grab_focus()


func hide_menu() -> void:
	visible = false
