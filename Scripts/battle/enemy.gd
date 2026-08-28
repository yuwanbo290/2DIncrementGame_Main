class_name Enemy
extends Area2D
## 哥布林敌人（色块占位实现）：Enemy 表驱动。
## 外观：带尖耳的圆形色块（颜色按 enemyID 从调色板取）+ 名字文字 + 头顶血条。
## 移动：俯视角战场游荡，enemyID 偶数走直线、奇数加正弦摆动（原型：不同哥布林不同轨迹，表内无轨迹字段，按 ID 区分）。
## 血量 / 金币 / 移速来自 Enemy 表行。


signal died(enemy: Enemy)
signal took_damage(enemy: Enemy)

## 色块占位半径
const BODY_RADIUS := 24.0
## 血条尺寸
const HEALTH_BAR_W := 44.0
const HEALTH_BAR_H := 6.0

## 哥布林调色板（enemyID -> 身体颜色；越界取模）
const PALETTE: Array[Color] = [
	Color(0.38, 0.55, 0.16, 1),  # 0 苔绿
	Color(0.48, 0.66, 0.20, 1),  # 1 黄绿
	Color(0.30, 0.48, 0.13, 1),  # 2 深绿
	Color(0.55, 0.50, 0.18, 1),  # 3 橄榄
	Color(0.25, 0.58, 0.34, 1),  # 4 森林绿
	Color(0.46, 0.40, 0.16, 1),  # 5 泥金
]
## Boss 体型放大倍数（相对普通哥布林）
const BOSS_SCALE := 1.5
## Boss 身体颜色（深红，与普通哥布林的绿色系明显区分）
const BOSS_COLOR := Color(0.62, 0.12, 0.16, 1)

## Enemy 表行（只读）
var enemy_row: Dictionary = {}
## 当前血量
var health: float = 1.0
## 最大血量
var max_health: float = 1.0
## 击杀金币
var coin: float = 1.0
## 击杀经验（局内升级用，来自 Enemy 表 exp 列）
var exp_value: float = 1.0
## 移动速度（像素/秒）
var move_speed: float = 40.0
## 是否为 Boss（waveBoss 表驱动）：放大体型、深红配色、血条常驻
var is_boss: bool = false

var _move_dir: Vector2 = Vector2.RIGHT
var _move_time: float = 0.0
var _body_color: Color = Color.WHITE
var _health_bar: Polygon2D
var _health_bg: Polygon2D


## 由 Enemy 表行构建外观与属性；boss=true 时放大体型、深红配色、血条常驻（waveBoss 表驱动）。
func setup(row: Dictionary, boss: bool = false) -> void:
	is_boss = boss
	enemy_row = row
	max_health = float(row.get("healthNum", 5.0))
	health = max_health
	coin = float(row.get("coin", 1.0))
	exp_value = float(row.get("exp", 1.0))
	move_speed = float(row.get("moveSpeed", 40.0))
	var enemy_id: int = int(row.get("enemyID", 1))
	var body_color: Color = BOSS_COLOR if is_boss else PALETTE[enemy_id % PALETTE.size()]
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	var collision_shape := CollisionShape2D.new()
	var circle_shape := CircleShape2D.new()
	circle_shape.radius = BODY_RADIUS
	collision_shape.shape = circle_shape
	add_child(collision_shape)

	# 表内保留完整名称供日志/图鉴使用；战斗常驻标签去掉公共前缀，避免群怪时文字大面积重叠。
	var display_name: String = str(row.get("enemyName", "哥布林"))
	if is_boss:
		scale = Vector2.ONE * BOSS_SCALE
	else:
		display_name = display_name.trim_prefix("哥布林")
		if display_name == "":
			display_name = "哥布林"
	_build_body(body_color, display_name)
	_build_health_bar()
	# 随机漂移方向（偏向中下部，避免全部挤在顶部）
	var angle: float = randf() * TAU
	_move_dir = Vector2.from_angle(angle)
	if _move_dir.y < -0.3:
		_move_dir.y = -_move_dir.y


func _build_body(color: Color, label_text: String) -> void:
	_body_color = color
	queue_redraw()

	# 名字文字（色块中央）
	var label: Label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.78, 1))
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.03, 1))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.position = Vector2(-BODY_RADIUS, -BODY_RADIUS)
	label.size = Vector2(BODY_RADIUS * 2.0, BODY_RADIUS * 2.0)


func _draw() -> void:
	draw_circle(Vector2.ZERO, BODY_RADIUS, _body_color)
	var ear_color: Color = _body_color.darkened(0.16)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-BODY_RADIUS + 4.0, -8.0),
		Vector2(-BODY_RADIUS - 16.0, -2.0),
		Vector2(-BODY_RADIUS + 3.0, 5.0),
	]), ear_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(BODY_RADIUS - 4.0, -8.0),
		Vector2(BODY_RADIUS + 16.0, -2.0),
		Vector2(BODY_RADIUS - 3.0, 5.0),
	]), ear_color)


func _build_health_bar() -> void:
	# 血条背景（红）
	_health_bg = Polygon2D.new()
	_health_bg.polygon = PackedVector2Array([
		Vector2(-HEALTH_BAR_W / 2.0, -BODY_RADIUS - 14.0),
		Vector2(HEALTH_BAR_W / 2.0, -BODY_RADIUS - 14.0),
		Vector2(HEALTH_BAR_W / 2.0, -BODY_RADIUS - 14.0 + HEALTH_BAR_H),
		Vector2(-HEALTH_BAR_W / 2.0, -BODY_RADIUS - 14.0 + HEALTH_BAR_H),
	])
	_health_bg.color = Color(0.5, 0.1, 0.1, 0.9)
	add_child(_health_bg)

	# 血条前景（绿，宽度按血量比例）
	_health_bar = Polygon2D.new()
	_health_bar.color = Color(0.3, 0.9, 0.3, 0.95)
	add_child(_health_bar)
	_update_health_bar()


func _update_health_bar() -> void:
	if _health_bar == null:
		return
	# 血条默认隐藏，仅受击（血量不满）时显示；Boss 血条常驻
	var show_bar: bool = is_boss or (health < max_health and health > 0.0)
	_health_bg.visible = show_bar
	_health_bar.visible = show_bar
	var ratio: float = clampf(health / max_health, 0.0, 1.0)
	var w: float = HEALTH_BAR_W * ratio
	_health_bar.polygon = PackedVector2Array([
		Vector2(-HEALTH_BAR_W / 2.0, -BODY_RADIUS - 14.0),
		Vector2(-HEALTH_BAR_W / 2.0 + w, -BODY_RADIUS - 14.0),
		Vector2(-HEALTH_BAR_W / 2.0 + w, -BODY_RADIUS - 14.0 + HEALTH_BAR_H),
		Vector2(-HEALTH_BAR_W / 2.0, -BODY_RADIUS - 14.0 + HEALTH_BAR_H),
	])


func take_damage(amount: float) -> void:
	if health <= 0.0:
		return
	health -= amount
	_update_health_bar()
	took_damage.emit(self)
	if health <= 0.0:
		died.emit(self)


func _process(delta: float) -> void:
	_move_time += delta
	position += _move_dir * move_speed * delta
	# 奇数 enemyID：正弦摆动（不同移动轨迹）
	if int(enemy_row.get("enemyID", 1)) % 2 == 1:
		position.x += sin(_move_time * 2.2) * 30.0 * delta
	# 超出战斗区域后移除
	var view: Vector2 = get_viewport_rect().size if get_viewport() != null else Vector2(1920, 1080)
	if position.x < -80.0 or position.x > view.x + 80.0 or position.y < -80.0 or position.y > view.y + 80.0:
		queue_free()
