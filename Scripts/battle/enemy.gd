class_name Enemy
extends Node2D
## 鸭子敌人（色块占位实现）：Ducks 表驱动。
## 外观：圆形色块（颜色按 duckID 从调色板取）+ 名字文字 + 头顶血条。
## 移动：俯视角池塘漂移，duckID 偶数走直线、奇数加正弦摆动（原型：不同鸭子不同轨迹，表内无轨迹字段，按 ID 区分）。
## 血量 / 金币 / 移速来自 Ducks 表行。


signal died(enemy: Enemy)
signal took_damage(enemy: Enemy)

## 色块占位半径
const BODY_RADIUS := 24.0
## 血条尺寸
const HEALTH_BAR_W := 44.0
const HEALTH_BAR_H := 6.0

## 鸭子调色板（duckID -> 身体颜色；越界取模）
const PALETTE: Array[Color] = [
	Color(1.0, 0.85, 0.2, 1),    # 0 黄
	Color(1.0, 0.55, 0.2, 1),    # 1 橙
	Color(1.0, 0.35, 0.35, 1),   # 2 红
	Color(0.75, 0.4, 1.0, 1),    # 3 紫
	Color(0.4, 0.7, 1.0, 1),     # 4 蓝
	Color(0.4, 1.0, 0.6, 1),     # 5 绿
]

## Ducks 表行（只读）
var duck_row: Dictionary = {}
## 当前血量
var health: float = 1.0
## 最大血量
var max_health: float = 1.0
## 击杀金币
var coin: float = 1.0
## 移动速度（像素/秒）
var move_speed: float = 40.0

var _move_dir: Vector2 = Vector2.RIGHT
var _move_time: float = 0.0
var _health_bar: Polygon2D
var _health_bg: Polygon2D


## 由 Ducks 表行构建外观与属性
func setup(row: Dictionary) -> void:
	duck_row = row
	max_health = float(row.get("healthNum", 5.0))
	health = max_health
	coin = float(row.get("coin", 1.0))
	move_speed = float(row.get("moveSpeed", 40.0))
	var duck_id: int = int(row.get("duckID", 1))
	var body_color: Color = PALETTE[duck_id % PALETTE.size()]

	_build_body(body_color, str(row.get("duckName", "鸭")))
	_build_health_bar()
	# 随机漂移方向（偏向中下部，避免全部挤在顶部）
	var angle: float = randf() * TAU
	_move_dir = Vector2.from_angle(angle)
	if _move_dir.y < -0.3:
		_move_dir.y = -_move_dir.y


func _build_body(color: Color, label_text: String) -> void:
	# 圆形色块
	var body: Polygon2D = Polygon2D.new()
	body.polygon = _make_circle_polygon(BODY_RADIUS, 28)
	body.color = color
	add_child(body)

	# 名字文字（色块中央）
	var label: Label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.position = Vector2(-BODY_RADIUS, -BODY_RADIUS)
	label.size = Vector2(BODY_RADIUS * 2.0, BODY_RADIUS * 2.0)


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


## 生成圆形多边形顶点
static func _make_circle_polygon(radius: float, segments: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in segments:
		var angle: float = TAU * float(i) / float(segments)
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	return pts


func _update_health_bar() -> void:
	if _health_bar == null:
		return
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
	# 奇数 duckID：正弦摆动（不同移动轨迹）
	if int(duck_row.get("duckID", 1)) % 2 == 1:
		position.x += sin(_move_time * 2.2) * 30.0 * delta
	# 超出战斗区域后移除
	var view: Vector2 = get_viewport_rect().size if get_viewport() != null else Vector2(1920, 1080)
	if position.x < -80.0 or position.x > view.x + 80.0 or position.y < -80.0 or position.y > view.y + 80.0:
		queue_free()
