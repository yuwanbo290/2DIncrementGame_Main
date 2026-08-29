class_name WaveEventSystem
extends Node2D
## 波次事件系统：进入下一波时从 waveEvents 表加权随机选事件，
## 播放随机开场动画（全屏色闪 + 事件名缩放浮现）后应用对应效果，持续时间为配置 effect_time。
## 效果配置见 Resources/Events/wave_event_<id>.tres（WaveEventConfig）。


signal event_finished
## 老虎机奖励金币（battle_manager 监听后计入本局金币）
signal reward_gold(amount: int)

const EVENTS_DIR := "res://Resources/Events"
const ENEMY_GROUP := "enemies"


## 当前事件配置
var _config: WaveEventConfig
var _event_id: int = 0
var _active: bool = false
var _effect_time_left: float = 0.0
## 当前波数（精英敌人从当前波刷怪表抽取）
var _current_stage: int = 1

## 各效果间隔计时
var _strike_timer: float = 0.0
var _meteor_timer: float = 0.0
var _plague_timer: float = 0.0
var _plague_tick: float = 0.0
## 点燃状态：Enemy -> 剩余秒
var _burns: Dictionary = {}
## 当前老虎机（击破后触发奖励 / 精英）
var _slot_machine: Enemy = null
var _anim_layer: CanvasLayer = null
## 当前开场动画 tween（触发新事件时 kill，防止旧回调串扰）
var _active_tween: Tween = null


## 触发一个事件：若上一波事件仍在生效，先停止并清理动画，再重新随机触发。
func trigger_event(event_row: Dictionary, stage: int) -> void:
	if _active:
		_stop_effect()
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
	_current_stage = stage
	var event_id := int(event_row.get("eventsId", 0))
	_config = _load_config(event_id)
	if _config == null:
		push_warning("[事件] 缺少配置：%s/wave_event_%d.tres" % [EVENTS_DIR, event_id])
		return
	_event_id = event_id
	_active = true
	_play_opening(event_row)


## 按事件 id 加载对应配置 .tres。
func _load_config(event_id: int) -> WaveEventConfig:
	var path := "%s/wave_event_%d.tres" % [EVENTS_DIR, event_id]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as WaveEventConfig


## 播放事件开场动画（全屏色闪 + 事件名缩放浮现），动画结束后开始效果。
func _play_opening(event_row: Dictionary) -> void:
	_anim_layer = CanvasLayer.new()
	_anim_layer.layer = 60
	add_child(_anim_layer)

	var color := _event_color(_event_id)
	var flash := ColorRect.new()
	flash.color = color.darkened(0.45)
	flash.modulate.a = 0.4
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_anim_layer.add_child(flash)

	var label := Label.new()
	label.text = "⚠ %s ⚠" % str(event_row.get("name", "事件"))
	label.add_theme_font_size_override("font_size", 46)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_anim_layer.add_child(label)

	var tween := create_tween()
	_active_tween = tween
	label.scale = Vector2(0.4, 0.4)
	label.pivot_offset = label.size * 0.5
	tween.tween_property(label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.9)
	tween.tween_property(flash, "modulate:a", 0.0, 0.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_start_effect)
	tween.tween_callback(_anim_layer.queue_free)


## 动画结束：初始化并开始对应事件效果。
func _start_effect() -> void:
	if not _active or _config == null:
		return
	_effect_time_left = _config.effect_time if _config.effect_time > 0.0 else -1.0
	match _event_id:
		1:
			_strike_timer = _rand_interval(_config.thunder_interval_min, _config.thunder_interval_max)
		2:
			_meteor_timer = _rand_interval(_config.meteor_interval_min, _config.meteor_interval_max)
		3:
			_plague_timer = _rand_interval(_config.plague_interval_min, _config.plague_interval_max)
		4:
			_spawn_slot_machine()


func _process(delta: float) -> void:
	if not _active or _config == null:
		return
	# 限时效果：时间耗尽停止（effect_time <= 0 表示整波生效）
	if _effect_time_left > 0.0:
		_effect_time_left -= delta
		if _effect_time_left <= 0.0:
			_stop_effect()
			return
	# 点燃持续掉血（每秒 max_health × burn_damage_ratio）
	if not _burns.is_empty():
		_tick_burns(delta)
	match _event_id:
		1:
			_update_thunder(delta)
		2:
			_update_meteor(delta)
		3:
			_update_plague(delta)


## 停止当前事件：清掉点燃与未击破的老虎机。
func _stop_effect() -> void:
	_active = false
	_burns.clear()
	if _slot_machine != null and is_instance_valid(_slot_machine):
		_slot_machine.queue_free()
	_slot_machine = null
	event_finished.emit()


# ---- 雷暴天 ----

func _update_thunder(delta: float) -> void:
	_strike_timer -= delta
	if _strike_timer <= 0.0:
		_strike_timer = _rand_interval(_config.thunder_interval_min, _config.thunder_interval_max)
		var count := randi_range(_config.thunder_count_min, _config.thunder_count_max)
		for i in count:
			_strike_lightning()


## 随机降下一道落雷：非 Boss 直接秒杀，Boss 掉 thunder_boss_damage_ratio 当前血。
func _strike_lightning() -> void:
	var enemies := get_tree().get_nodes_in_group(ENEMY_GROUP)
	if enemies.is_empty():
		return
	var target: Enemy = enemies[randi() % enemies.size()]
	_spawn_lightning_fx(target.position)
	if target.is_boss:
		target.take_damage(target.health * _config.thunder_boss_damage_ratio)
	else:
		target.take_damage(target.health * 10.0)


## 生成短暂显示的闪电折线（从屏幕上方劈向目标）。
func _spawn_lightning_fx(target_pos: Vector2) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.95, 0.9, 0.4, 1)
	line.points = PackedVector2Array([
		Vector2(target_pos.x, -30.0),
		Vector2(target_pos.x + randf_range(-40.0, 40.0), target_pos.y * 0.5),
		target_pos,
	])
	add_child(line)
	var tween := create_tween()
	tween.tween_interval(0.12)
	tween.tween_property(line, "modulate:a", 0.0, 0.12)
	tween.tween_callback(line.queue_free)


# ---- 火山爆发 ----

func _update_meteor(delta: float) -> void:
	_meteor_timer -= delta
	if _meteor_timer <= 0.0:
		_meteor_timer = _rand_interval(_config.meteor_interval_min, _config.meteor_interval_max)
		var count := randi_range(_config.meteor_count_min, _config.meteor_count_max)
		for i in count:
			_drop_meteor()


## 从屏幕上方掉下一块陨石，落点附近敌人受 meteor_damage_ratio 当前血伤害并点燃。
func _drop_meteor() -> void:
	var view := get_viewport_rect().size
	var target_pos := Vector2(
		randf_range(80.0, maxf(view.x - 80.0, 160.0)),
		randf_range(80.0, view.y * 0.55)
	)
	var meteor := Node2D.new()
	meteor.position = Vector2(target_pos.x, -60.0)
	add_child(meteor)
	var body := Polygon2D.new()
	body.polygon = _make_circle_polygon(18.0, 16)
	body.color = Color(0.9, 0.5, 0.15, 1)
	meteor.add_child(body)
	var tween := create_tween()
	tween.tween_property(meteor, "position", target_pos, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_meteor_impact.bind(target_pos))
	tween.tween_callback(meteor.queue_free)


func _on_meteor_impact(pos: Vector2) -> void:
	var radius: float = _config.meteor_radius
	for enemy in get_tree().get_nodes_in_group(ENEMY_GROUP):
		if is_instance_valid(enemy) and enemy.position.distance_to(pos) < radius:
			enemy.take_damage(enemy.health * _config.meteor_damage_ratio)
			_apply_burn(enemy)


## 给敌人附加点燃状态（每秒 max_health × burn_damage_ratio，持续 burn_duration；重复点燃刷新计时）。
func _apply_burn(enemy: Enemy) -> void:
	if not is_instance_valid(enemy) or enemy.health <= 0.0:
		return
	_burns[enemy] = _config.burn_duration


func _tick_burns(delta: float) -> void:
	var expired: Array[Enemy] = []
	for enemy in _burns.keys():
		if not is_instance_valid(enemy) or enemy.health <= 0.0:
			expired.append(enemy)
			continue
		_burns[enemy] = float(_burns[enemy]) - delta
		enemy.take_damage(enemy.max_health * _config.burn_damage_ratio * delta)
		if float(_burns[enemy]) <= 0.0:
			expired.append(enemy)
	for enemy in expired:
		_burns.erase(enemy)


# ---- 狂风瘟疫 ----

func _update_plague(delta: float) -> void:
	_plague_timer -= delta
	if _plague_timer <= 0.0:
		_plague_timer = _rand_interval(_config.plague_interval_min, _config.plague_interval_max)
		_spawn_wind_fx()
	# 感染期间每秒对全屏敌人扣 max_health × plague_damage_ratio
	_plague_tick += delta
	if _plague_tick >= 1.0:
		_plague_tick = 0.0
		for enemy in get_tree().get_nodes_in_group(ENEMY_GROUP):
			if is_instance_valid(enemy):
				enemy.take_damage(enemy.max_health * _config.plague_damage_ratio)


## 生成绿色狂风特效（一道绿幕横穿屏幕）。
func _spawn_wind_fx() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	var rect := ColorRect.new()
	rect.color = Color(0.3, 0.85, 0.4, 0.25)
	rect.position = Vector2(-400.0, get_viewport_rect().size.y * 0.3)
	rect.size = Vector2(get_viewport_rect().size.x + 800.0, 180.0)
	layer.add_child(rect)
	var tween := create_tween()
	tween.tween_property(rect, "position:x", rect.size.x * 0.5, 0.9)
	tween.tween_callback(layer.queue_free)


# ---- 老虎机 ----

## 场景中心出现一个老虎机（1 血可被子弹命中），击破后随机奖励或精英敌人。
func _spawn_slot_machine() -> void:
	await get_tree().create_timer(_config.slot_spawn_delay).timeout
	if not _active or _event_id != 4:
		return
	var row: Dictionary = TableDB.get_first("Enemy", "enemyID", 1)
	if row.is_empty():
		return
	var machine: Enemy = Enemy.new()
	machine.setup(row)
	machine.setup_slot_machine()
	var view := get_viewport_rect().size
	machine.position = Vector2(view.x / 2.0, view.y * 0.35)
	machine.died.connect(_on_slot_machine_died)
	add_child(machine)
	machine.add_to_group(ENEMY_GROUP)
	_slot_machine = machine


## 老虎机被击破：随机出现精英敌人或奖励金币，事件结束。
func _on_slot_machine_died(_machine: Enemy) -> void:
	_slot_machine = null
	if randf() < _config.slot_elite_ratio:
		_spawn_elite_enemy()
	else:
		reward_gold.emit(_config.slot_reward_gold)
	_stop_effect()


## 生成精英敌人：当前波随机敌人 × slot_elite_hp_ratio 血量、× slot_elite_reward_ratio 奖励，体型更大。
func _spawn_elite_enemy() -> void:
	var candidates: Array[Dictionary] = []
	for row in TableDB.rows_of("generateProbability"):
		if int(row.get("waveNumber", 0)) == _current_stage:
			candidates.append(row)
	if candidates.is_empty():
		return
	var pick: Dictionary = candidates[randi() % candidates.size()]
	var enemy_row: Dictionary = TableDB.get_first("Enemy", "enemyID", int(pick.get("enemyId", 1)))
	if enemy_row.is_empty():
		return
	var elite: Enemy = Enemy.new()
	elite.setup(enemy_row)
	elite.max_health = elite.max_health * _config.slot_elite_hp_ratio
	elite.health = elite.max_health
	elite.coin = elite.coin * _config.slot_elite_reward_ratio
	elite.exp_value = elite.exp_value * _config.slot_elite_reward_ratio
	elite.scale = Vector2.ONE * 1.5
	elite._body_color = Color(0.9, 0.25, 0.25, 1)
	elite.queue_redraw()
	var view := get_viewport_rect().size
	elite.position = Vector2(randf_range(80.0, maxf(view.x - 80.0, 160.0)), view.y * 0.3)
	elite.died.connect(_on_elite_died)
	add_child(elite)
	elite.add_to_group(ENEMY_GROUP)


## 精英敌人被击杀（金币 / 经验已在生成时翻倍，交给击杀方计入）。
func _on_elite_died(_elite: Enemy) -> void:
	pass


# ---- 工具 ----

func _rand_interval(min_v: float, max_v: float) -> float:
	return randf_range(maxf(min_v, 0.1), maxf(max_v, min_v + 0.1))


## 每个事件的代表色（开场动画 / 特效）。
func _event_color(event_id: int) -> Color:
	match event_id:
		1:
			return Color(0.95, 0.9, 0.4, 1)
		2:
			return Color(0.95, 0.45, 0.2, 1)
		3:
			return Color(0.4, 0.85, 0.5, 1)
		4:
			return Color(0.75, 0.4, 0.9, 1)
		_:
			return Color.WHITE


static func _make_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in segments:
		var angle := TAU * float(i) / float(segments)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts

