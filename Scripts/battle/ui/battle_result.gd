class_name BattleResultUI
extends Control
## 战斗结算弹层：战斗结束后展示本局伤害/击杀/金币/阶段，玩家确认后返回备战界面。
## 本界面只负责展示与发出确认信号；金币落盘与场景切换由 BattleManager 负责。
## 参考 BuffChoiceUI：process_mode=ALWAYS，暂停期间按钮仍可响应。


## 玩家点击「返回备战」时发出
signal continue_pressed

var _damage_label: Label
var _kills_label: Label
var _gold_label: Label
var _stage_label: Label
var _continue_btn: TextureButton


func _ready() -> void:
	# 显式在 _ready 初始化：@onready + % 在节点 _enter_tree 阶段 unique name 尚未注册，
	# 动态实例化场景时会导致引用为空，这里统一延迟到 _ready（子节点均已入树）再获取。
	_damage_label = get_node("%DamageLabel") as Label
	_kills_label = get_node("%KillsLabel") as Label
	_gold_label = get_node("%GoldLabel") as Label
	_stage_label = get_node("%StageLabel") as Label
	_continue_btn = get_node("%ContinueBtn") as TextureButton
	_continue_btn.pressed.connect(_on_continue_pressed)
	# 与 UIBase._add_hover 一致的提亮效果（本类不继承 UIBase，手动实现）
	_continue_btn.modulate = Color(1.15, 1.15, 1.15, 1)
	_continue_btn.mouse_entered.connect(func(): _continue_btn.modulate = Color(1.3, 1.3, 1.3, 1))
	_continue_btn.mouse_exited.connect(func(): _continue_btn.modulate = Color(1.15, 1.15, 1.15, 1))
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
