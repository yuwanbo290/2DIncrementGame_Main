extends Node2D
## 战斗管理器：核心战斗循环（色块占位实现）。
## 流程：读配置/武器/技能加成 → 定时按 generateProbability 表加权刷哥布林 → 玩家按住左键射击 →
## 命中扣血、击杀得金币与经验 → 升级时进行局内 Buff 三选一 → 达到每波门槛生成 Boss →
## 击杀 Boss 推进波次；最后一波完成或时间耗尽时结算落盘并返回备战界面。


## 表名
const TABLE_SPAWN := "generateProbability"
const TABLE_ENEMY := "Enemy"
const TABLE_WAVE_BOSS := "waveBoss"
const TABLE_WAVE_EVENTS := "waveEvents"
const TABLE_BUFF := "Buff"
const TABLE_BUFF_LEVEL := "buffLevel"

## Buff 与 skillLevel 表均使用 changeAttr1~4 / attrValue1~4（含每级 desc 文案），统一由同一个属性入口处理。
const ATTRIBUTE_SLOT_COUNT := 4

## 多轮连射的轮间间隔（秒）
const BURST_INTERVAL := 0.08
## 使用场景树分组统计场上敌人，避免维护一份容易失效的手工数组。
const ENEMY_GROUP := &"battle_enemies"

## skillLevel 表 changeAttr 可直接增强的本局配置字段名（key 与 base_config 字段字符串一致）。
const CONFIG_ATTR_KEYS: Array[String] = [
	"base_attack",
	"base_attack_speed",
	"base_crit_rate",
	"base_crit_dmg",
	"round_time",
	"spawn_interval",
	"spawn_per_wave",
	"exp_gain_rate",
	"coin_gain_rate",
]

var config: BaseConfig
var _weapon: Dictionary = {}
var _damage_bonus: float = 0.0
var _bullet_count: int = 1
var _ricochet_count: int = 0
## 每次射击的额外连射轮数（Buff 属性 burstCount）；实际轮数 = 1 + 该值
var _burst_rounds: int = 0

var _player: BattlePlayer

var _time_left: float = 0.0
var _kills: int = 0
var _gold: float = 0.0
var _spawn_timer: float = 0.0
var _stage: int = 1
var _max_stage: int = 1
var _finished: bool = false
## 当前波内已击杀的普通敌人数量（用于 waveBoss.CreateCost 门槛判定）
var _wave_kills: int = 0
## Boss 是否在场（防止重复生成，击杀后进入下一波）
var _boss_active: bool = false
## Boss 已被击败、等待玩家点击「进入下一波 / 完成讨伐」；点击前保持当前波战斗直至体力耗尽。
var _boss_defeated_pending: bool = false
## 当前提示动画；新提示出现时会终止旧动画。
var _notice_tween: Tween
## 本局累计造成的伤害（含暴击放大），结算界面展示
var _total_damage: float = 0.0
## 结算弹层是否打开（打开期间场景树暂停）
var _is_result_open: bool = false

## 局内 Buff 状态只存在于当前 Battle 场景，不写入 SaveSystem；重新进入战斗会自然归零。
var _buff_levels: Dictionary = {}
## 本局累计经验（当前等级内未消耗部分，攒满 Exp(level) 后升级并扣除）
var _exp: float = 0.0
## 当前局内等级（从 1 开始；升级触发局内 Buff 三选一）
var _level: int = 1
## 弹层打开期间阻止重复触发和快速重复选择。
var _is_choosing_buff: bool = false
## 本局 Buff 提供的属性加成明细（attr key -> 累计值），暂停界面以（）展示
var _buff_bonus: Dictionary = {}
## HUD 只在目标值变化时播放反馈，避免 _process() 每帧重建 Tween。
var _last_timer_second: int = -1
var _last_gold_value: int = -1
var _last_kill_value: int = -1
var _last_stage_value: int = -1
var _last_exp_target: float = -1.0

@onready var _buff_choice_ui: BuffChoiceUI = $UI/BuffChoiceUI as BuffChoiceUI
@onready var _result_ui: BattleResultUI = $UI/BattleResultUI as BattleResultUI
@onready var _pause_ui: PauseMenuUI = $UI/PauseMenuUI as PauseMenuUI
@onready var _world: Node2D = $World
@onready var _background: ColorRect = $World/Background
@onready var _pause_btn: Button = $UI/PauseBtn
@onready var _gold_label: Label = $UI/StatsCard/Margin/Stats/GoldLabel
@onready var _kill_label: Label = $UI/StatsCard/Margin/Stats/KillLabel
@onready var _wave_label: Label = $UI/StatsCard/Margin/Stats/WaveLabel
@onready var _big_timer_label: Label = $UI/BigTimerLabel
@onready var _notice_label: Label = $UI/NoticeLabel
@onready var _exp_bar: ProgressBar = $UI/ExpBar
@onready var _exp_label: Label = $UI/ExpBar/ExpLabel
@onready var _wave_choice_panel: PanelContainer = $UI/WaveChoicePanel
@onready var _next_wave_btn: Button = $UI/WaveChoicePanel/Margin/HBox/NextWaveBtn
@onready var _stay_btn: Button = $UI/WaveChoicePanel/Margin/HBox/StayBtn
@onready var _event_system: WaveEventSystem = $World/WaveEventSystem


func _ready() -> void:
	var shared_config: BaseConfig = ConfigSystem.config
	if shared_config == null:
		push_error("[战斗] 未找到 ConfigSystem.config")
		return
	# 每局使用独立副本，Buff / 技能可以直接修改而不会污染全局基础配置。
	config = shared_config.duplicate(true) as BaseConfig
	_load_meta_bonuses()
	_time_left = config.round_time
	_spawn_timer = config.spawn_interval

	_weapon = WeaponService.get_equipped_stats()
	if _weapon.is_empty():
		push_error("[战斗] 没有可用武器（请先在武器界面装备）")
		# 空手兜底：atk=0 时伤害即玩家基础攻击 base_attack；atkSpeed=1.0 即基础攻速
		_weapon = {"weaponName": "空手", "atk": 0.0, "atkSpeed": 1.0}

	_max_stage = _get_max_stage()

	# 暂停按钮：打开属性面板，可继续战斗或放弃本局返回备战。
	UIBase.bind_button(_pause_btn)
	_pause_btn.pressed.connect(_on_pause_pressed)
	_pause_ui.resume_pressed.connect(_on_pause_resume)
	_pause_ui.quit_pressed.connect(_on_pause_quit)
	_buff_choice_ui.buff_selected.connect(_on_buff_selected)
	if _next_wave_btn:
		_next_wave_btn.pressed.connect(_on_next_wave_pressed)
	if _stay_btn:
		_stay_btn.pressed.connect(_on_stay_pressed)
	if _wave_choice_panel:
		_wave_choice_panel.hide()
	if _event_system:
		_event_system.reward_gold.connect(_on_event_reward_gold)
	_result_ui.continue_pressed.connect(_on_result_continue)

	# 窗口尺寸变化时玩家与背景跟随（如切换全屏/分辨率）
	get_viewport().size_changed.connect(_on_viewport_size_changed)

	_update_hud()


func _on_viewport_size_changed() -> void:
	var view: Vector2 = get_viewport_rect().size
	_background.size = view
	if _player != null:
		_player.position = Vector2(view.x / 2.0, view.y - BattlePlayer.MARGIN_BOTTOM)


## 第一帧执行的位置相关初始化（窗口尺寸在 _ready 时尚未生效）
func _initialize_battle() -> void:
	var view: Vector2 = get_viewport_rect().size
	# 背景色块跟随窗口尺寸（Node2D 下锚点无效，手动铺满）
	_background.size = view
	_player = BattlePlayer.new()
	add_child(_player)
	_player.setup(
		Vector2(view.x / 2.0, view.y - BattlePlayer.MARGIN_BOTTOM),
		_get_fire_interval()
	)
	_player.fire_requested.connect(_on_player_fire)
	_spawn_enemy()
	_show_notice("讨伐开始！第 %d 波" % _stage, 2.0)


## 当前射击间隔（秒）= 1 / (基础攻速 × 武器攻速)，下限 0.05。
func _get_fire_interval() -> float:
	return 1.0 / maxf(config.base_attack_speed * float(_weapon.get("atkSpeed", 1.0)), 0.05)


## 刷新玩家射击间隔：局内 Buff / 技能增强 base_attack_speed 后即时生效。
func _refresh_fire_interval() -> void:
	if _player == null:
		return
	_player.fire_interval = _get_fire_interval()


func _on_back_pressed() -> void:
	_finished = true
	_close_buff_choice()
	UIManager.clear_all()
	get_tree().change_scene_to_file("res://Scenes/ui/preparation.tscn")


# ---- 暂停菜单 ----

## 打开暂停菜单：展示当前玩家属性（含 Buff 括号加成）并暂停场景树。
func _on_pause_pressed() -> void:
	if _finished or _is_choosing_buff or _is_result_open:
		return
	_pause_ui.show_menu(get_in_run_stats())
	get_tree().paused = true


## 继续战斗：关闭暂停菜单并恢复。
func _on_pause_resume() -> void:
	_pause_ui.hide_menu()
	get_tree().paused = false


## 从暂停菜单返回备战：放弃本局（不结算）。
func _on_pause_quit() -> void:
	_pause_ui.hide_menu()
	get_tree().paused = false
	_on_back_pressed()


## 局内当前属性汇总（含武器 + 局外技能 + 局内 Buff），并附带 Buff 加成明细（暂停界面（）展示用）。
func get_in_run_stats() -> Dictionary:
	var base := {
		"base_attack": config.base_attack + _damage_bonus,  # atk 加成并入攻击力
		"base_attack_speed": config.base_attack_speed,
		"base_crit_rate": config.base_crit_rate,
		"base_crit_dmg": config.base_crit_dmg,
		"round_time": config.round_time,
	}
	var stats := PlayerStatsService.compute(base, {}, _weapon, _bullet_count, _burst_rounds + 1)
	stats["buff_bonus"] = _buff_bonus
	return stats


## 把已学习的局外技能加成应用到本局配置副本。
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


## 当前单发子弹基础伤害 = 玩家基础攻击 + 武器攻击 + 局外技能 + 本局 Buff（叠加模型）。
## 实际命中伤害还会被暴击放大：射击时按 config.base_crit_rate 判定，命中则 × base_crit_dmg。
func get_total_damage() -> float:
	return config.base_attack + float(_weapon.get("atk", 0.0)) + _damage_bonus


# ---- 战斗属性统一应用 ----

## 读取一行配置中固定的四组属性字段。
## 局外 skillLevel 与局内 buffLevel 共用此入口，确保同一个属性 key 在两套系统中含义一致。
func _apply_attribute_slots(level_row: Dictionary) -> void:
	for index in range(1, ATTRIBUTE_SLOT_COUNT + 1):
		var attr: String = str(level_row.get("changeAttr%d" % index, ""))
		var value: float = float(level_row.get("attrValue%d" % index, 0.0))
		_apply_attribute_change(attr, value)


## 战斗属性统一应用：既支持战斗内部属性（atk / bulletCount / ricochetCount / burstCount），
## 也支持以 base_config 字段名命名的属性（base_attack / base_attack_speed / base_crit_rate /
## base_crit_dmg / round_time / spawn_interval / spawn_per_wave），后者直接累加到本局生效的 config。
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
		"burstCount":
			_burst_rounds += int(value)
		_:
			if _apply_config_attribute(attr, value):
				return
			push_warning("[战斗] 忽略未支持的属性 key：%s" % attr)


## 把以 base_config 字段名命名的属性 key 累加到本局配置副本。
func _apply_config_attribute(attr: String, value: float) -> bool:
	if not attr in CONFIG_ATTR_KEYS:
		return false
	var current: Variant = config.get(attr)
	match typeof(current):
		TYPE_FLOAT:
			config.set(attr, float(current) + value)
		TYPE_INT:
			config.set(attr, int(current) + int(value))
	# 攻速变化需要立即刷新玩家射击间隔（局内 Buff 选择后即时生效）
	if attr == "base_attack_speed":
		_refresh_fire_interval()
	return true


# ---- 局内 Buff：触发与候选抽取 ----

## 击杀获得经验：累计到升级所需经验后升级并触发局内 Buff 三选一。
## 经验只在当前战斗生效，不写入 SaveSystem；重新进入战斗自然归零。
func _add_exp(amount: float) -> void:
	if amount <= 0.0:
		return
	_exp += amount
	_update_hud()
	# 延迟到当前物理回调结束后再检查升级，避免在碰撞信号中暂停场景树。
	call_deferred("_check_level_up")


## 从当前等级升到下一级所需经验：Exp(level) = exp_base × level^exp_power + exp_linear × (level-1)
func _exp_for_level(level: int) -> float:
	return config.exp_base * pow(float(level), config.exp_power) + config.exp_linear * float(maxi(level - 1, 0))


## 检查当前经验是否足够升级；每次只处理一级：扣除所需经验、等级 +1、弹出三选一。
## 一次获得大量经验连升多级时，玩家选完本次 Buff 后由 _on_buff_selected 继续补弹下一级。
func _check_level_up() -> void:
	if _finished or _is_choosing_buff or config == null:
		return
	var needed: float = _exp_for_level(_level)
	if _exp < needed:
		return

	_exp -= needed
	_level += 1
	_update_hud()
	_open_buff_choice()


## 弹出一轮局内 Buff 三选一并暂停场景树；无可用 Buff 时跳过（经验已扣除，继续检查下一级）。
func _open_buff_choice() -> void:
	var choice_count: int = mini(config.buff_choice_count, BuffChoiceUI.CHOICE_CAPACITY)
	var picked_rows: Array[Dictionary] = _roll_buff_choices(choice_count)
	if picked_rows.is_empty():
		push_warning("[战斗] 升级 Lv.%d 没有可用 Buff，已跳过本次三选一" % _level)
		call_deferred("_check_level_up")
		return

	var display_choices: Array[Dictionary] = []
	for buff_row in picked_rows:
		display_choices.append(_build_buff_choice_data(buff_row))

	# 先设置互斥标记并完成界面数据刷新，再暂停场景树。
	# BuffChoiceUI 使用 PROCESS_MODE_ALWAYS，因此暂停后按钮仍能响应。
	_is_choosing_buff = true
	_buff_choice_ui.show_choices(display_choices)
	get_tree().paused = true


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
## 描述使用配置文本（buffLevel.desc），并展示「上一级 → 下一级」效果（0 级上一级显示「无」）。
func _build_buff_choice_data(buff_row: Dictionary) -> Dictionary:
	var buff_id: int = int(buff_row.get("Id", 0))
	var current_level: int = int(_buff_levels.get(buff_id, 0))
	var next_level: int = current_level + 1
	var prev_row: Dictionary = _get_buff_level_row(buff_id, current_level)
	var next_row: Dictionary = _get_buff_level_row(buff_id, next_level)
	return {
		"id": buff_id,
		"name": str(buff_row.get("buffName", "未知升级")),
		"next_level": next_level,
		"max_level": int(buff_row.get("maxLevel", next_level)),
		"prev_desc": "无" if current_level <= 0 or prev_row.is_empty() else str(prev_row.get("desc", "")),
		"next_desc": str(next_row.get("desc", "")),
	}
# ---- 局内 Buff：选择、生效与暂停恢复 ----

func _on_buff_selected(buff_id: int) -> void:
	if not _is_choosing_buff:
		return

	_apply_next_buff_level(buff_id)
	_close_buff_choice()

	# 若 Boss 等待玩家选择推进，选完 Buff 后继续保持暂停（选择面板仍处于打开状态）
	if _boss_defeated_pending and _wave_choice_panel != null and _wave_choice_panel.visible:
		get_tree().paused = true

	# 若经验仍足够下一级（一次击杀大量经验连升多级），恢复战斗后继续补弹下一次选择。
	call_deferred("_check_level_up")


## 只应用“当前等级 + 1”这一行，避免重复叠加已经获得过的旧等级效果。
func _apply_next_buff_level(buff_id: int) -> bool:
	var current_level: int = int(_buff_levels.get(buff_id, 0))
	var next_level: int = current_level + 1
	var level_row: Dictionary = _get_buff_level_row(buff_id, next_level)
	if level_row.is_empty():
		push_warning("[战斗] 无法应用 Buff Id=%d：缺少 buffLevel=%d" % [buff_id, next_level])
		return false

	# 先记录 Buff 提供的属性加成明细（暂停界面以（）展示），再应用效果
	_accumulate_buff_bonus(level_row)
	_apply_attribute_slots(level_row)
	_buff_levels[buff_id] = next_level
	return true


## 累计本局 Buff 提供的属性加成明细（attr key -> 累计值，暂停界面括号展示用）。
func _accumulate_buff_bonus(level_row: Dictionary) -> void:
	for index in range(1, ATTRIBUTE_SLOT_COUNT + 1):
		var attr: String = str(level_row.get("changeAttr%d" % index, ""))
		var value: float = float(level_row.get("attrValue%d" % index, 0.0))
		if attr != "":
			_buff_bonus[attr] = _buff_bonus.get(attr, 0.0) + value


## 关闭弹层并解除暂停。所有离开战斗的路径也调用此方法，防止下一场景保持暂停。
func _close_buff_choice() -> void:
	_buff_choice_ui.hide_choices()
	_is_choosing_buff = false
	if get_tree() != null:
		get_tree().paused = false


# ---- 刷怪 ----

## 波数上限来自 waveBoss 表（每波击杀门槛达成后刷新 Boss，击杀 Boss 推进下一波）。
func _get_max_stage() -> int:
	var max_stage: int = 1
	for row in TableDB.rows_of(TABLE_WAVE_BOSS):
		max_stage = maxi(max_stage, int(row.get("waveNumber", 1)))
	return max_stage


func _spawn_enemy() -> void:
	# 场上敌人数量达到上限时不再刷怪（等击杀腾出位置）
	if config != null and get_tree().get_node_count_in_group(ENEMY_GROUP) >= config.max_enemies:
		return
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

	var enemy_row: Dictionary = TableDB.get_first(TABLE_ENEMY, "enemyID", int(pick.get("enemyId", 1)))
	if enemy_row.is_empty():
		push_warning("[战斗] Enemy 表缺少 enemyID=%d" % int(pick.get("enemyId", 0)))
		return

	var enemy: Enemy = Enemy.new()
	enemy.setup(enemy_row)
	# 生成位置：屏幕内随机（避开底部玩家区域）
	var view: Vector2 = get_viewport_rect().size if get_viewport() != null else Vector2(1920, 1080)
	enemy.position = Vector2(
		randf_range(60.0, maxf(view.x - 60.0, 120.0)),
		randf_range(60.0, view.y * 0.55)
	)
	enemy.died.connect(_on_enemy_died)
	_world.add_child(enemy)
	enemy.add_to_group(ENEMY_GROUP)


## 当前波对应的 waveBoss 表行（无配置返回空字典）。
func _get_current_wave_boss() -> Dictionary:
	return TableDB.get_first(TABLE_WAVE_BOSS, "waveNumber", _stage)


## 本波击杀数达到 waveBoss.CreateCost 时刷新 Boss（Boss 在场或等待推进时不再触发）。
func _check_boss_spawn() -> void:
	if _boss_active or _boss_defeated_pending or _finished:
		return
	var boss_row: Dictionary = _get_current_wave_boss()
	if boss_row.is_empty():
		return
	var cost: int = int(boss_row.get("CreateCost", 0))
	if cost > 0 and _wave_kills >= cost:
		_spawn_boss()


## 按当前波唯一的 waveBoss 配置生成 Boss（Boss 敌人带 is_boss 标记）。
func _spawn_boss() -> void:
	if _boss_active:
		return
	var pick: Dictionary = _get_current_wave_boss()
	if pick.is_empty():
		push_warning("[战斗] waveBoss 表缺少 waveNumber=%d 的 Boss 配置" % _stage)
		return

	var enemy_row: Dictionary = TableDB.get_first(TABLE_ENEMY, "enemyID", int(pick.get("enemyId", 1)))
	if enemy_row.is_empty():
		push_warning("[战斗] Enemy 表缺少 Boss enemyID=%d" % int(pick.get("enemyId", 0)))
		return

	var boss: Enemy = Enemy.new()
	boss.setup(enemy_row, true)
	# Boss 生成在屏幕上部中央区域，突出存在感
	var view: Vector2 = get_viewport_rect().size if get_viewport() != null else Vector2(1920, 1080)
	boss.position = Vector2(view.x / 2.0, randf_range(60.0, view.y * 0.35))
	boss.died.connect(_on_enemy_died)
	_world.add_child(boss)
	boss.add_to_group(ENEMY_GROUP)
	_boss_active = true
	_show_notice("⚠ BOSS 来袭：%s ⚠" % str(pick.get("name", "Boss")), 2.5)


## Boss 被击杀：弹出「进入下一波 / 继续当前」双按钮并暂停时间，等待玩家选择。
## 「进入下一波」推进波次；「继续当前」留在本波刷怪，直至体力耗尽结算。
func _on_boss_defeated() -> void:
	_boss_active = false
	_wave_kills = 0
	_boss_defeated_pending = true
	_show_notice("BOSS 已击破！", 2.0)
	if _wave_choice_panel == null:
		# 兜底：面板缺失时自动推进，避免卡关
		_advance_next_wave()
		return
	# 延迟到本帧 Buff 升级检查之后显示，避免与升级三选一弹层互相抢占暂停
	call_deferred("_show_wave_choice")


## 显示「进入下一波 / 继续当前」选择面板并暂停场景树（体力倒计时与战斗全部暂停）。
func _show_wave_choice() -> void:
	if not _boss_defeated_pending or _finished:
		return
	_next_wave_btn.text = "完成讨伐" if _stage >= _max_stage else "进入下一波"
	_wave_choice_panel.show()
	get_tree().paused = true


## 点击「进入下一波 / 完成讨伐」：恢复时间并推进波次（最后一波结算）。
func _on_next_wave_pressed() -> void:
	if not _boss_defeated_pending:
		return
	get_tree().paused = false
	_advance_next_wave()


## 点击「继续当前」：留在本波战斗（不再刷新 Boss），恢复时间直至体力耗尽结算。
func _on_stay_pressed() -> void:
	if not _boss_defeated_pending:
		return
	_boss_defeated_pending = true
	if _wave_choice_panel:
		_wave_choice_panel.hide()
	get_tree().paused = false


## 实际推进波次 / 结算：由「进入下一波」或兜底调用。
func _advance_next_wave() -> void:
	_boss_defeated_pending = false
	if _wave_choice_panel:
		_wave_choice_panel.hide()
	# 清除当前场景残留的存活敌人（非死亡），避免混入下一波
	_clear_enemies()
	if _stage >= _max_stage:
		_show_notice("🎉 讨伐完成！", 3.0)
		_finish_round()
		return
	_stage += 1
	_wave_kills = 0
	_show_notice("进入第 %d 波" % _stage, 2.0)
	# 进入下一波：触发随机波次事件（播放动画后应用配置效果）
	_trigger_wave_event()


## 从 waveEvents 表加权随机选一个事件并触发。
func _trigger_wave_event() -> void:
	var rows: Array[Dictionary] = TableDB.rows_of(TABLE_WAVE_EVENTS)
	if rows.is_empty():
		return
	var total_weight: int = 0
	for row in rows:
		total_weight += int(row.get("weight", 1))
	var roll: int = randi() % maxi(total_weight, 1)
	var pick: Dictionary = rows[0]
	for row in rows:
		roll -= int(row.get("weight", 1))
		if roll < 0:
			pick = row
			break
	if _event_system:
		_event_system.trigger_event(pick, _stage)


## 老虎机奖励金币计入本局收益。
func _on_event_reward_gold(amount: int) -> void:
	_gold += amount
	_update_hud()
	_show_notice("🎰 奖励 +%d 金币" % amount, 2.0)


## 清除场上所有存活的敌人（进入下一波前清场；Boss 已死亡，残留为普通小怪）。
func _clear_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group(ENEMY_GROUP):
		if is_instance_valid(enemy):
			enemy.queue_free()


# ---- 射击 ----

func _on_player_fire(dir: Vector2) -> void:
	_fire_burst_round(0, dir)


## 发射一轮子弹（散射 + 每发独立暴击判定）；随后按 BURST_INTERVAL 顺次发射后续轮次。
## 一次射击总轮数 = 1 + _burst_rounds（Buff 属性 burstCount 提供的额外轮数）。
func _fire_burst_round(round_index: int, dir: Vector2) -> void:
	var count: int = maxi(_bullet_count, 1)
	# 有效暴击：暴击率超过 100% 时，每 1% 溢出转化为 1.5% 暴击伤害（隐藏机制）
	var crit: Dictionary = PlayerStatsService.get_effective_crit(config.base_crit_rate, config.base_crit_dmg)
	for i in count:
		# 每发子弹独立判定暴击：命中暴击则本发伤害按暴击倍率放大
		var damage: float = get_total_damage()
		var is_crit: bool = randf() < float(crit["rate"])
		if is_crit:
			damage *= float(crit["dmg"])
		var offset: float = (float(i) - float(count - 1) / 2.0) * config.spread_half_angle * 2.0
		var bullet_dir: Vector2 = dir.rotated(offset)
		var bullet: Bullet = Bullet.new()
		bullet.setup(bullet_dir, config.bullet_speed, damage, _ricochet_count, is_crit)
		bullet.position = _player.position + bullet_dir * config.muzzle_offset
		bullet.hit_enemy.connect(_on_bullet_hit)
		_world.add_child(bullet)

	# 剩余轮次顺次发射（中途战斗结束或场景销毁则停止）
	var total_rounds: int = maxi(_burst_rounds + 1, 1)
	if round_index + 1 < total_rounds:
		await get_tree().create_timer(BURST_INTERVAL).timeout
		if _finished or not is_instance_valid(self) or not is_inside_tree():
			return
		_fire_burst_round(round_index + 1, dir)


# ---- 碰撞与击杀 ----

func _on_enemy_died(enemy: Enemy) -> void:
	# 金币与经验按 coin_gain_rate / exp_gain_rate 加成（Buff / 局外技能可提升）
	_gold += enemy.coin * (1.0 + config.coin_gain_rate)
	_kills += 1
	_add_exp(enemy.exp_value * (1.0 + config.exp_gain_rate))
	if enemy.is_boss:
		_on_boss_defeated()
	else:
		_wave_kills += 1
		_check_boss_spawn()
	_update_hud()
	enemy.queue_free()


## 子弹通过 Area2D 碰撞信号上报命中；伤害统计与反馈仍由战斗管理器统一处理。
func _on_bullet_hit(enemy: Enemy, damage: float, is_crit: bool) -> void:
	if not is_instance_valid(enemy) or enemy.health <= 0.0:
		return
	enemy.take_damage(damage)
	_total_damage += damage
	_spawn_damage_number(enemy.position, damage, is_crit)


## 在受击位置生成伤害数字（普通/暴击样式由 DamageNumber 决定）。
func _spawn_damage_number(world_pos: Vector2, damage: float, is_crit: bool) -> void:
	var number: DamageNumber = DamageNumber.new()
	number.setup(damage, is_crit)
	number.position = world_pos
	_world.add_child(number)


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

	# HUD 每帧接收状态，但仅在整数秒或目标值变化时更新动效。
	_update_hud()

	# 刷怪逻辑：场上全灭时立即刷新一批；否则按 spawn_interval 间隔计时刷怪。
	# （spawn_per_wave 与 max_enemies 共同限制单次刷怪数量）
	if get_tree().get_node_count_in_group(ENEMY_GROUP) == 0:
		_spawn_timer = config.spawn_interval
		for i in config.spawn_per_wave:
			_spawn_enemy()
	else:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = config.spawn_interval
			for i in config.spawn_per_wave:
				_spawn_enemy()

## 显示居中的大号提示文本（Boss 来袭 / 波次切换 / 通关），自动淡出。
func _show_notice(text: String, duration: float = 2.0) -> void:
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_label.text = text
	_notice_label.show()
	_notice_label.modulate.a = 1.0
	_notice_tween = create_tween()
	_notice_tween.tween_interval(maxf(duration - 0.5, 0.0))
	_notice_tween.tween_property(_notice_label, "modulate:a", 0.0, minf(duration, 0.5))
	_notice_tween.tween_callback(_notice_label.hide)


func _update_hud() -> void:
	var gold_value: int = int(_gold)
	if gold_value != _last_gold_value:
		_gold_label.text = "金币: %d" % gold_value
		if _last_gold_value >= 0:
			UIBase.pulse(_gold_label)
		_last_gold_value = gold_value

	if _kills != _last_kill_value:
		_kill_label.text = "击杀: %d" % _kills
		if _last_kill_value >= 0:
			UIBase.pulse(_kill_label)
		_last_kill_value = _kills

	if _stage != _last_stage_value:
		_wave_label.text = "阶段 %d" % _stage
		if _last_stage_value >= 0:
			UIBase.pulse(_wave_label)
		_last_stage_value = _stage

	# 最后 10 秒只在整数秒变化时脉冲一次，不再逐帧修改字号。
	var remain: int = ceili(_time_left)
	if remain != _last_timer_second:
		_big_timer_label.text = "体力: %d" % remain
		_big_timer_label.add_theme_color_override(
			"font_color",
			Color("c84d45") if remain <= 10 else Color("e6b84a")
		)
		if _last_timer_second >= 0 and remain <= 10:
			UIBase.pulse(_big_timer_label)
		_last_timer_second = remain

	# 底部经验条：进度 = 当前经验 / 升级所需经验
	if config != null:
		var needed: float = maxf(_exp_for_level(_level), 1.0)
		_exp_bar.max_value = needed
		if not is_equal_approx(_exp, _last_exp_target):
			UIBase.tween_range(_exp_bar, _exp, 0.16)
			_last_exp_target = _exp
		_exp_label.text = "Lv.%d ｜ %d/%d" % [_level, int(_exp), int(needed)]


func _finish_round() -> void:
	_finished = true
	_boss_defeated_pending = false
	if _wave_choice_panel:
		_wave_choice_panel.hide()
	_close_buff_choice()
	# 展示结算弹层并暂停；金币落盘与统计更新延后到玩家点「返回备战」确认时执行
	_is_result_open = true
	_result_ui.show_result(roundi(_total_damage), _kills, int(_gold), _stage)
	get_tree().paused = true


## 结算弹层确认：落盘本局收益与统计，解除暂停并回备战界面。
func _on_result_continue() -> void:
	if not _is_result_open:
		return
	_is_result_open = false
	# 结算：局内金币落盘（局外倍率暂为 1.0，原型公式留待配置），统计更新
	SaveSystem.add_gold(int(_gold))
	SaveSystem.set_stat("rounds", SaveSystem.get_stat("rounds") + 1)
	SaveSystem.set_stat("best_kills", maxi(SaveSystem.get_stat("best_kills"), _kills))
	SaveSystem.save()
	get_tree().paused = false
	UIManager.clear_all()
	get_tree().change_scene_to_file("res://Scenes/ui/preparation.tscn")


# ---- 场景退出兜底 ----

## 正常选择、返回按钮和回合结算都会主动恢复暂停；这里处理编辑器停止或其他外部切场景情况。
func _exit_tree() -> void:
	if get_tree() == null:
		return
	get_tree().paused = false
