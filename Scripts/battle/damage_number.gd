class_name DamageNumber
extends Node2D
## 命中伤害数字：在受击位置生成，向上飘动并淡出，生命周期结束自动销毁。
## 普通伤害：黄色小字；暴击：橙色大字 + 「暴击」前缀（独特显示）。


const LIFETIME := 0.7
const RISE_SPEED := 80.0
const CRIT_RISE_SPEED := 110.0
## 水平随机漂移范围（像素），避免连续命中时数字完全重叠
const DRIFT_RANGE := 26.0


var _label: Label
var _rise_offset: Vector2


## 在受击位置显示伤害数字；is_crit=true 时使用暴击配色与大字号。
func setup(damage: float, is_crit: bool) -> void:
	var rise_speed: float = CRIT_RISE_SPEED if is_crit else RISE_SPEED
	_rise_offset = Vector2(randf_range(-DRIFT_RANGE, DRIFT_RANGE), -rise_speed * LIFETIME * 0.5)

	_label = Label.new()
	if is_crit:
		_label.text = "暴击 %d" % roundi(damage)
		_label.add_theme_font_size_override("font_size", 22)
		_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.1, 1))
		_label.add_theme_color_override("font_outline_color", Color(0.3, 0.07, 0.0, 1))
	else:
		_label.text = "%d" % roundi(damage)
		_label.add_theme_font_size_override("font_size", 15)
		_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.5, 1))
		_label.add_theme_color_override("font_outline_color", Color(0.12, 0.09, 0.0, 1))
	_label.add_theme_constant_override("outline_size", 3)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)

	# 以文字中心为锚点（Label 尺寸依赖字体，用 get_string_size 即时计算，不等待布局帧）
	var font: Font = _label.get_theme_default_font()
	var text_size: Vector2 = font.get_string_size(
		_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _label.get_theme_font_size("font_size")
	)
	_label.position = Vector2(-text_size.x / 2.0, -text_size.y / 2.0)


func _ready() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", position + _rise_offset, LIFETIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_label, "modulate:a", 0.0, LIFETIME)
	tween.chain().tween_callback(queue_free)
