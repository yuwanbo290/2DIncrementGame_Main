extends Node2D
## 战斗管理器：核心战斗循环（色块占位实现）。
## 流程：读配置/武器/技能加成 → 定时按 generateProbability 表加权刷鸭 → 玩家按住左键射击 →
## 命中扣血、击杀得金币 → 击杀数切换波次（原型：10以内波1 / 10-20波2 / 20+波3，取表内 waveNumber）→
## 时间耗尽结算落盘 → 回备战界面。
## 3选1 Buff 与 Boss 暂未实现（用户明确先不做）。


## 表名
const TABLE_SPAWN := "generateProbability"
const TABLE_DUCKS := "Ducks"

## 每击杀多少只鸭子切换下一阶段（原型：10以内刷1.2.3，10-20刷2.3.4，以此类推）
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
				for i in range(1, 4):
					var attr: String = str(lv_row.get("changeAttr%d" % i, ""))
					var value: float = float(lv_row.get("attrValue%d" % i, 0.0))
					match attr:
						"atk":
							_damage_bonus += value
						"bulletCount":
							_bullet_count += int(value)
						"ricochetCount":
							_ricochet_count += int(value)
						_:
							pass  # 未识别的属性 key 忽略（specialEffect 等暂不处理）


## 当前武器的每秒伤害（含技能加成）
func get_total_damage() -> float:
	return float(_weapon.get("atk", 1.0)) + _damage_bonus


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

	# 加权随机选择鸭子 id
	var roll: int = randi() % maxi(total_weight, 1)
	var pick: Dictionary = candidates[0]
	for row in candidates:
		roll -= int(row.get("weight", 1))
		if roll < 0:
			pick = row
			break

	var duck_row: Dictionary = TableDB.get_first(TABLE_DUCKS, "duckID", int(pick.get("duckId", 1)))
	if duck_row.is_empty():
		push_warning("[战斗] Ducks 表缺少 duckID=%d" % int(pick.get("duckId", 0)))
		return

	var enemy: Enemy = Enemy.new()
	enemy.setup(duck_row)
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

	# 子弹与鸭子碰撞（圆形距离判定）
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
	# 结算：局内金币落盘（局外倍率暂为 1.0，原型公式留待配置），统计更新
	SaveSystem.add_gold(int(_gold))
	SaveSystem.set_stat("rounds", SaveSystem.get_stat("rounds") + 1)
	SaveSystem.set_stat("best_kills", maxi(SaveSystem.get_stat("best_kills"), _kills))
	SaveSystem.save()
	UIManager.clear_all()
	get_tree().change_scene_to_file("res://Scenes/ui/preparation.tscn")
