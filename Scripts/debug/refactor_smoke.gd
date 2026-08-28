extends Node
## Ponytail 重构的最小冒烟检查：验证关键场景、配置副本、敌人上限、有效暴击与原生碰撞。

const SCENES: Array[String] = [
	"res://Scenes/GameManager.tscn",
	"res://Scenes/battle.tscn",
	"res://Scenes/battle/ui/battle_result.tscn",
	"res://Scenes/battle/ui/buff_choice.tscn",
	"res://Scenes/battle/ui/pause_menu.tscn",
	"res://Scenes/ui/start_ui.tscn",
	"res://Scenes/ui/save_select.tscn",
	"res://Scenes/ui/save_slot.tscn",
	"res://Scenes/ui/settings.tscn",
	"res://Scenes/ui/preparation.tscn",
	"res://Scenes/ui/shop.tscn",
	"res://Scenes/ui/weapon.tscn",
	"res://Scenes/ui/out_of_battle_upgrade.tscn",
	"res://Scenes/ui/confirm_dialog.tscn",
]


func _ready() -> void:
	for path in SCENES:
		var scene: PackedScene = load(path) as PackedScene
		assert(scene != null, "场景加载失败: %s" % path)
		var instance: Node = scene.instantiate()
		assert(instance != null, "场景实例化失败: %s" % path)
		instance.free()

	var base: BaseConfig = load("res://Resources/Config/base_config.tres") as BaseConfig
	var run_config: BaseConfig = base.duplicate(true) as BaseConfig
	var original_attack: float = base.base_attack
	run_config.base_attack += 1.0
	assert(is_equal_approx(base.base_attack, original_attack), "本局配置污染了基础资源")
	assert(base.max_enemies == 15, "场上敌人上限配置未加载")

	var crit: Dictionary = PlayerStatsService.get_effective_crit(1.2, 1.5)
	assert(is_equal_approx(float(crit["rate"]), 1.0), "有效暴击率未封顶")
	assert(is_equal_approx(float(crit["dmg"]), 1.8), "溢出暴击率未转化为暴击伤害")

	var bullet := Bullet.new()
	var enemy := Enemy.new()
	assert(bullet is Area2D and enemy is Area2D, "战斗碰撞节点必须使用 Area2D")
	bullet.free()
	enemy.free()

	# 暂停状态下等待入场完成，确认三张有效 Buff 卡都能操作。
	var buff_ui: BuffChoiceUI = load("res://Scenes/battle/ui/buff_choice.tscn").instantiate() as BuffChoiceUI
	add_child(buff_ui)
	var choices: Array[Dictionary] = []
	for id in range(1, 4):
		choices.append({"id": id, "name": str(id), "next_level": 1, "max_level": 1, "prev_desc": "无", "next_desc": "+1"})
	buff_ui.show_choices(choices)
	get_tree().paused = true
	await get_tree().create_timer(0.6).timeout
	for button_name in ["Choice0", "Choice1", "Choice2"]:
		var button: Button = buff_ui.get_node("%" + button_name) as Button
		assert(not button.disabled and button.mouse_filter == Control.MOUSE_FILTER_STOP, "Buff 卡未开放输入: %s" % button_name)
	get_tree().paused = false
	buff_ui.free()

	for filename in DirAccess.get_files_at("res://data"):
		if filename.begins_with("~$"):
			continue
		assert(filename.get_extension().to_lower() == "xlsx", "data 目录只应保留 xlsx 数据源: %s" % filename)

	print("[冒烟检查] 通过：%d 个场景" % SCENES.size())
	get_tree().quit()
