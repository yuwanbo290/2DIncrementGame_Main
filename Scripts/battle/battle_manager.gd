extends Node2D
## 战斗管理器：核心战斗循环（色块占位实现）。
## 流程：读配置/武器/技能加成 → 定时按 generateProbability 表加权刷哥布林 → 玩家按住左键射击 →
## 命中扣血、击杀得金币 → 击杀数切换波次（原型：10以内波1 / 10-20波2 / 20+波3，取表内 waveNumber）→
## 达到配置的击杀节点时暂停战斗并进行局内 Buff 三选一 → 时间耗尽结算落盘 → 回备战界面。
## Boss 暂未实现。


## 表名
const TABLE_SPAWN := "generateProbability"
const TABLE_GOBLINS := "Goblins"
const TABLE_BUFF := "Buff"
const TABLE_BUFF_LEVEL := "buffLevel"

## Buff 与局外技能表都使用 changeAttr1~3 / attrValue1~3，统一由同一个属性入口处理。
const ATTRIBUTE_SLOT_COUNT := 3

## 每击杀多少只哥布林切换下一阶段（原型：10以内刷1.2.3，10-20刷2.3.4，以此类推）
const KILLS_PER_STAGE := 10
## 子弹速度
const BULLET_SPEED := 640.0
## 多弹散布半角（弧度）
const SPREAD_HALF_ANGLE := 0.12
## 子弹生成点距玩家中心的距离
const MUZZLE_OFFSET := 26.0

var config: BaseConfig
var _weapon: Dictionary = {}
var _damage_bonus: float = 0.0
var _bullet_count: int = 1
var _ricochet_count: int = 0

var _player: BattlePlayer
var _enemies: Array[Enemy] = []
var _bullets: Array[Bullet] = []

var _time_left: float = 60.0
var _kills: int = 0
var _gold: float = 0.0
var _spawn_timer: float = 0.0
var _stage: int = 1
var _max_stage: int = 1
var _finished: bool = false

## 局内 Buff 状态只存在于当前 Battle 场景，不写入 SaveSystem；重新进入战斗会自然归零。
var _buff_levels: Dictionary = {}
## 指向 config.buff_trigger_kills 中下一个尚未处理的触发节点。
var _next_buff_trigger_index: int = 0
## 弹层打开期间阻止重复触发和快速重复选择。
var _is_choosing_buff: bool = false

@onready var _buff_choice_ui: BuffChoiceUI = $UI/BuffChoiceUI as BuffChoiceUI


func _ready() -> void:
	config = ConfigSystem.config
	if config == null:
		push_error("[战斗] 未找到 ConfigSystem.config")
		return
	_time_left = config.round_time
	_spawn_timer = config.spawn_interval

	_weapon = WeaponService.get_equipped_stats()
	if _weapon.is_empty():
		push_error("[战斗] 没有可用武器（请先在武器界面装备）")
		_weapon = {"weaponName": "空手", "atk": 1.0, "atkSpeed": 1.0}

	_load_meta_bonuses()
	_max_stage = _get_max_stage()

	# 返回按钮：放弃本局直接回备战（不结算）
	var back_btn: TextureButton = $UI/TopBar/BackBtn as TextureButton
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
	if _buff_choice_ui:
		_buff_choice_ui.buff_selected.connect(_on_buff_selected)
	else:
		push_error("[战斗] battle.tscn 缺少 BuffChoiceUI，局内三选一无法显示")

	# 窗口尺寸变化时玩家与背景跟随（如切换全屏/分辨率）
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	_update_hud()


func _on_viewport_size_changed() -> void:
	var view: Vector2 = get_viewport_rect().size
	var bg: ColorRect = $World/Background as ColorRect
	if bg:
		bg.size = view
	if _player != null:
		_player.position = Vector2(view.x / 2.0, view.y - BattlePlayer.MARGIN_BOTTOM)


## 第一帧执行的位置相关初始化（窗口尺寸在 _ready 时尚未生效）
func _initialize_battle() -> void:
	var view: Vector2 = get_viewport_rect().size
	# 背景色块跟随窗口尺寸（Node2D 下锚点无效，手动铺满）
	var bg: ColorRect = $World/Background as ColorRect
	if bg:
		bg.size = view
	_player = BattlePlayer.new()
	add_child(_player)
	_player.setup(
		Vector2(view.x / 2.0, view.y - BattlePlayer.MARGIN_BOTTOM),
		1.0 / float(_weapon.get("atkSpeed", 1.0))
	)
	_player.fire_requested.connect(_on_player_fire)
	_spawn_enemy()


func _on_back_pressed() -> void:
	_finished = true
	_close_buff_choice()
	UIManager.clear_all()
	get_tree().change_scene_to_file("res://Scenes/ui/preparation.tscn")


func _load_meta_bonuses() -> void:
	# 局外技能加成：遍历 Skill 表，把已学等级的 skillLevel 效果累加
	for skill_row in TableDB.rows_of("Skill"):
		var skill_id: int = int(skill_row.get("Id", 0))
		var level: int = SaveSystem.get_skill_level(skill_id)
		if level <= 0:
			continue
		for lv_row in TableDB.get_all("skillLevel", "Id", skill_id):
			if int(lv_row.get("skillLevel", 0)) <= level:
				_apply_attribute_slots(lv_row)


## 当前单发子弹伤害（武器基础值 + 局外技能 + 本局 Buff）。
func get_total_damage() -> float:
	return float(_weapon.get("atk", 1.0)) + _damage_bonus


# ---- 战斗属性统一应用 ----

## 读取一行配置中固定的三组属性字段。
## 局外 skillLevel 与局内 buffLevel 共用此入口，确保同一个属性 key 在两套系统中含义一致。
func _apply_attribute_slots(level_row: Dictionary) -> void:
	for index in range(1, ATTRIBUTE_SLOT_COUNT + 1):
		var attr: String = str(level_row.get("changeAttr%d" % index, ""))
		var value: float = float(level_row.get("attrValue%d" % index, 0.0))
		_apply_attribute_change(attr, value)


## 首版只开放战斗当前已经完整支持的三种属性。
## 未识别 key 会给出警告但不会阻断战斗，便于发现表格拼写错误。
func _apply_attribute_change(attr: String, value: float) -> void:
	match attr:
		"":
			pass
		"atk":
			_damage_bonus += value
		"bulletCount":
			_bullet_count += int(value)
		"ricochetCount":
			_ricochet_count += int(value)
		_:
			push_warning("[战斗] 忽略未支持的属性 key：%s" % attr)


# ---- 局内 Buff：触发与候选抽取 ----

## 检查当前击杀数是否到达下一个三选一节点。
##
## 使用 >= 而不是 ==，可以兼容同一帧连续击杀跨过阈值的情况。
## 使用 while，可以在一次选择结束后继续补处理已经跨过的后续阈值。
func _check_buff_trigger() -> void:
	if _finished or _is_choosing_buff or config == null or _buff_choice_ui == null:
		return

	var trigger_kills: Array[int] = config.buff_trigger_kills
	while _next_buff_trigger_index < trigger_kills.size():
		var threshold: int = trigger_kills[_next_buff_trigger_index]
		if _kills < threshold:
			return

		var choice_count: int = mini(config.buff_choice_count, BuffChoiceUI.CHOICE_CAPACITY)
		var picked_rows: Array[Dictionary] = _roll_buff_choices(choice_count)
		# 当前阈值已完成检查；即使候选池为空也要前进，避免每次击杀都重复尝试同一节点。
		_next_buff_trigger_index += 1
		if picked_rows.is_empty():
			push_warning("[战斗] 击杀节点 %d 没有可用 Buff，已跳过本次三选一" % threshold)
			continue

		var display_choices: Array[Dictionary] = []
		for buff_row in picked_rows:
			display_choices.append(_build_buff_choice_data(buff_row))

		# 先设置互斥标记并完成界面数据刷新，再暂停场景树。
		# BuffChoiceUI 使用 PROCESS_MODE_ALWAYS，因此暂停后按钮仍能响应。
		_is_choosing_buff = true
		_buff_choice_ui.show_choices(display_choices)
		get_tree().paused = true
		return


## 从所有“未满级且存在下一级配置”的 Buff 中加权抽取，且同一次三选一不重复。
## 候选池是新数组，只删除池内引用，不会修改 TableDB 缓存中的原始 rows。
func _roll_buff_choices(choice_count: int) -> Array[Dictionary]:
	var pool: Array[Dictionary] = []
	for buff_row in TableDB.rows_of(TABLE_BUFF):
		var buff_id: int = int(buff_row.get("Id", 0))
		var current_level: int = int(_buff_levels.get(buff_id, 0))
		var max_level: int = int(buff_row.get("maxLevel", 0))
		if buff_id <= 0 or current_level >= max_level:
			continue
		if _get_buff_level_row(buff_id, current_level + 1).is_empty():
			push_warning(
				"[战斗] Buff Id=%d 缺少 buffLevel=%d，已从候选池排除"
				% [buff_id, current_level + 1]
			)
			continue
		pool.append(buff_row)

	var choices: Array[Dictionary] = []
	var draw_count: int = mini(maxi(choice_count, 0), pool.size())
	for _draw_index in draw_count:
		var picked_index: int = _pick_weighted_buff_index(pool)
		choices.append(pool[picked_index])
		pool.remove_at(picked_index)
	return choices


## 使用与刷怪表相同的“总权重减随机值”方式选出一项。
## 当所有权重都小于等于 0 时回退为等概率随机，避免错误配置造成除零问题。
func _pick_weighted_buff_index(pool: Array[Dictionary]) -> int:
	var total_weight: int = 0
	for buff_row in pool:
		total_weight += maxi(int(buff_row.get("weight", 1)), 0)

	if total_weight <= 0:
		return randi() % pool.size()

	var roll: int = randi() % total_weight
	for index in pool.size():
		roll -= maxi(int(pool[index].get("weight", 1)), 0)
		if roll < 0:
			return index
	return pool.size() - 1


# ---- 局内 Buff：等级查询与界面数据 ----

## buffLevel 允许同一 Id 有多行，因此先按 Id 取全部，再精确匹配本次要获得的等级。
func _get_buff_level_row(buff_id: int, level: int) -> Dictionary:
	for level_row in TableDB.get_all(TABLE_BUFF_LEVEL, "Id", buff_id):
		if int(level_row.get("buffLevel", 0)) == level:
			return level_row
	return {}


## 将表格行转换成 UI 所需的只读显示数据；UI 不直接依赖 TableDB 或局内状态。
func _build_buff_choice_data(buff_row: Dictionary) -> Dictionary:
	var buff_id: int = int(buff_row.get("Id", 0))
	var next_level: int = int(_buff_levels.get(buff_id, 0)) + 1
	var level_row: Dictionary = _get_buff_level_row(buff_id, next_level)
	return {
		"id": buff_id,
		"name": str(buff_row.get("buffName", "未知升级")),
		"description": str(buff_row.get("desc", "")),
		"next_level": next_level,
		"max_level": int(buff_row.get("maxLevel", next_level)),
		"effect_text": _describe_buff_level(level_row),
	}


## 把属性 key 转为玩家可读的本级效果文字。
func _describe_buff_level(level_row: Dictionary) -> String:
	var effects: Array[String] = []
	for index in range(1, ATTRIBUTE_SLOT_COUNT + 1):
		var attr: String = str(level_row.get("changeAttr%d" % index, ""))
		var value: float = float(level_row.get("attrValue%d" % index, 0.0))
		if attr == "":
			continue
		var value_text: String = str(int(value)) if is_equal_approx(value, roundf(value)) else "%.2f" % value
		match attr:
			"atk":
				effects.append("伤害 +%s" % value_text)
			"bulletCount":
				effects.append("每次射击子弹 +%s" % value_text)
			"ricochetCount":
				effects.append("边界弹射次数 +%s" % value_text)
			_:
				effects.append("%s +%s" % [attr, value_text])

	if effects.is_empty():
		return "本级没有普通属性变化"
	return "本级效果：%s" % "；".join(effects)


# ---- 局内 Buff：选择、生效与暂停恢复 ----

func _on_buff_selected(buff_id: int) -> void:
	if not _is_choosing_buff:
		return

	_apply_next_buff_level(buff_id)
	_close_buff_choice()

	# 如果同一帧多击杀已经跨过下一个阈值，恢复战斗后继续补弹下一次选择。
	call_deferred("_check_buff_trigger")


## 只应用“当前等级 + 1”这一行，避免重复叠加已经获得过的旧等级效果。
func _apply_next_buff_level(buff_id: int) -> bool:
	var current_level: int = int(_buff_levels.get(buff_id, 0))
	var next_level: int = current_level + 1
	var level_row: Dictionary = _get_buff_level_row(buff_id, next_level)
	if level_row.is_empty():
		push_warning("[战斗] 无法应用 Buff Id=%d：缺少 buffLevel=%d" % [buff_id, next_level])
		return false

	_apply_attribute_slots(level_row)
	var special_effect: String = str(level_row.get("specialEffect", ""))
	if special_effect != "":
		push_warning("[战斗] Buff 特殊效果尚未支持，已忽略：%s" % special_effect)

	_buff_levels[buff_id] = next_level
	return true


## 关闭弹层并解除暂停。所有离开战斗的路径也调用此方法，防止下一场景保持暂停。
func _close_buff_choice() -> void:
	if _buff_choice_ui != null:
		_buff_choice_ui.hide_choices()
	_is_choosing_buff = false
	if get_tree() != null:
		get_tree().paused = false


# ---- 刷怪 ----

func _get_max_stage() -> int:
	var max_stage: int = 1
	for row in TableDB.rows_of(TABLE_SPAWN):
		max_stage = maxi(max_stage, int(row.get("waveNumber", 1)))
	return max_stage


## 按击杀数换算当前阶段（10以内=1，10-19=2，20+ 封顶）
func _stage_from_kills(kills: int) -> int:
	return clampi(kills / KILLS_PER_STAGE + 1, 1, _max_stage)


func _spawn_enemy() -> void:
	var candidates: Array[Dictionary] = []
	var total_weight: int = 0
	for row in TableDB.rows_of(TABLE_SPAWN):
		if int(row.get("waveNumber", 0)) == _stage:
			candidates.append(row)
			total_weight += int(row.get("weight", 1))
	if candidates.is_empty():
		return

	# 加权随机选择哥布林 id
	var roll: int = randi() % maxi(total_weight, 1)
	var pick: Dictionary = candidates[0]
	for row in candidates:
		roll -= int(row.get("weight", 1))
		if roll < 0:
			pick = row
			break

	var goblin_row: Dictionary = TableDB.get_first(TABLE_GOBLINS, "goblinID", int(pick.get("goblinId", 1)))
	if goblin_row.is_empty():
		push_warning("[战斗] Goblins 表缺少 goblinID=%d" % int(pick.get("goblinId", 0)))
		return

	var enemy: Enemy = Enemy.new()
	enemy.setup(goblin_row)
	# 生成位置：屏幕内随机（避开底部玩家区域）
	var view: Vector2 = get_viewport_rect().size if get_viewport() != null else Vector2(1920, 1080)
	enemy.position = Vector2(
		randf_range(60.0, maxf(view.x - 60.0, 120.0)),
		randf_range(60.0, view.y * 0.55)
	)
	enemy.died.connect(_on_enemy_died)
	$World.add_child(enemy)
	_enemies.append(enemy)


# ---- 射击 ----

func _on_player_fire(dir: Vector2) -> void:
	var damage: float = get_total_damage()
	var count: int = maxi(_bullet_count, 1)
	for i in count:
		var offset: float = (float(i) - float(count - 1) / 2.0) * SPREAD_HALF_ANGLE * 2.0
		var bullet_dir: Vector2 = dir.rotated(offset)
		var bullet: Bullet = Bullet.new()
		bullet.setup(bullet_dir, BULLET_SPEED, damage, _ricochet_count)
		bullet.position = _player.position + bullet_dir * MUZZLE_OFFSET
		$World.add_child(bullet)
		_bullets.append(bullet)


# ---- 碰撞与击杀 ----

func _on_enemy_died(enemy: Enemy) -> void:
	_enemies.erase(enemy)
	_gold += enemy.coin
	_kills += 1
	_update_hud()
	enemy.queue_free()

	# 延迟到当前碰撞循环结束后再打开弹层：同一帧的连续击杀会先全部计数，随后只弹出一次选择。
	call_deferred("_check_buff_trigger")


func _process(delta: float) -> void:
	if _finished:
		return
	if _player == null:
		_initialize_battle()
		return

	# 玩家位置始终贴底居中（窗口 resize 后也跟随，比 size_changed 信号更可靠）
	var view: Vector2 = get_viewport_rect().size
	_player.position = Vector2(view.x / 2.0, view.y - BattlePlayer.MARGIN_BOTTOM)

	# 倒计时
	_time_left -= delta
	if _time_left <= 0.0:
		_time_left = 0.0
		_finish_round()
		return

	# 刷怪计时（初始 spawn_interval 秒）
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = config.spawn_interval
		for i in config.spawn_per_wave:
			_spawn_enemy()

	# 阶段切换（击杀数跨过阈值时更新刷怪表）
	var stage: int = _stage_from_kills(_kills)
	if stage != _stage:
		_stage = stage
		_update_hud()

	# 子弹与哥布林碰撞（圆形距离判定）
	for bullet in _bullets:
		if not is_instance_valid(bullet):
			continue
		for enemy in _enemies:
			if not is_instance_valid(enemy):
				continue
			if bullet.position.distance_to(enemy.position) < Bullet.RADIUS + Enemy.BODY_RADIUS:
				enemy.take_damage(bullet.damage)
				bullet.queue_free()
				break

	# 清理已释放的子弹（Array[Bullet] 的 filter 泛型有坑，用手动重建）
	var alive: Array[Bullet] = []
	for b in _bullets:
		if is_instance_valid(b):
			alive.append(b)
	_bullets = alive


func _update_hud() -> void:
	var ui: CanvasLayer = $UI as CanvasLayer
	if ui == null:
		return
	var gold_label: Label = ui.get_node_or_null("TopBar/GoldLabel") as Label
	if gold_label:
		gold_label.text = "金币: %d" % int(_gold)
	var timer_label: Label = ui.get_node_or_null("TopBar/TimerLabel") as Label
	if timer_label:
		timer_label.text = str(ceili(_time_left))
	var kill_label: Label = ui.get_node_or_null("TopBar/KillLabel") as Label
	if kill_label:
		kill_label.text = "击杀: %d" % _kills
	var wave_label: Label = ui.get_node_or_null("TopBar/WaveLabel") as Label
	if wave_label:
		wave_label.text = "阶段 %d" % _stage


func _finish_round() -> void:
	_finished = true
	_close_buff_choice()
	# 结算：局内金币落盘（局外倍率暂为 1.0，原型公式留待配置），统计更新
	SaveSystem.add_gold(int(_gold))
	SaveSystem.set_stat("rounds", SaveSystem.get_stat("rounds") + 1)
	SaveSystem.set_stat("best_kills", maxi(SaveSystem.get_stat("best_kills"), _kills))
	SaveSystem.save()
	UIManager.clear_all()
	get_tree().change_scene_to_file("res://Scenes/ui/preparation.tscn")


# ---- 场景退出兜底 ----

## 正常选择、返回按钮和回合结算都会主动恢复暂停；这里处理编辑器停止或其他外部切场景情况。
func _exit_tree() -> void:
	if _is_choosing_buff and get_tree() != null:
		get_tree().paused = false
