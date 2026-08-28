extends Control

class_name UIBase

## 全项目 UI Theme；项目级 Theme 已配置，保留常量供战斗弹层直接复用。
const BUTTON_THEME := preload("res://Resources/button_theme.tres")

const _TWEEN_META := &"moss_ember_tween"
const _REDUCED_FADE_TIME := 0.08


func _ready() -> void:
	theme = BUTTON_THEME
	for node: Node in find_children("*", "BaseButton", true, false):
		bind_button(node as BaseButton)
	refresh()


## UIManager 重新显示缓存界面时调用；子类仅覆写需要刷新的内容。
func refresh() -> void:
	pass


## 页面转场完成后的默认焦点；需要指定主操作的页面可覆写。
func get_default_focus() -> Control:
	return find_next_valid_focus()


## 页面进入：0.18 秒淡入；减少动态时缩短为轻淡入。
func play_enter() -> Tween:
	show()
	modulate.a = 0.0
	var tween: Tween = _new_tween(self)
	var duration: float = _REDUCED_FADE_TIME if is_reduced_motion() else 0.18
	tween.tween_property(self, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween


## 页面退出完成后调用 callback；调用方无需等待 Tween。
func play_exit(callback: Callable = Callable()) -> Tween:
	var tween: Tween = _new_tween(self)
	var duration: float = _REDUCED_FADE_TIME if is_reduced_motion() else 0.12
	tween.tween_property(self, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if callback.is_valid():
		tween.tween_callback(callback)
	return tween


static func is_reduced_motion() -> bool:
	return bool(SaveSystem.get_setting("reduced_motion", false))


## 弹窗进入；战斗暂停时仍可播放。
static func popup_in(dimmer: Control, body: Control) -> Tween:
	dimmer.modulate.a = 0.0
	body.modulate.a = 0.0
	body.pivot_offset = body.size * 0.5
	var tween: Tween = _new_tween(body)

	if is_reduced_motion():
		body.scale = Vector2.ONE
		tween.tween_property(dimmer, "modulate:a", 1.0, _REDUCED_FADE_TIME)
		tween.parallel().tween_property(body, "modulate:a", 1.0, _REDUCED_FADE_TIME)
		return tween

	body.scale = Vector2.ONE * 0.92
	tween.tween_property(dimmer, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(body, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(body, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween


## 为固定或动态创建的按钮绑定统一 hover / pressed 缩放。
static func bind_button(button: BaseButton) -> void:
	if button == null or button.has_meta(&"moss_ember_button_bound"):
		return
	button.set_meta(&"moss_ember_button_bound", true)
	button.mouse_entered.connect(func(): _scale_button(button, 1.025, 0.09))
	button.mouse_exited.connect(func(): _scale_button(button, 1.025 if button.has_focus() else 1.0, 0.09))
	button.focus_entered.connect(func(): _scale_button(button, 1.025, 0.09))
	button.focus_exited.connect(func(): _scale_button(button, 1.025 if button.is_hovered() else 1.0, 0.09))
	button.button_down.connect(func(): _scale_button(button, 0.96, 0.06))
	button.button_up.connect(func(): _scale_button(button, 1.025 if button.is_hovered() or button.has_focus() else 1.0, 0.06))


## 卡片淡入并轻微放大；最多错峰前 8 项。
static func reveal_card(card: Control, index: int) -> Tween:
	card.pivot_offset = card.size * 0.5
	card.modulate.a = 0.0
	var tween: Tween = _new_tween(card)
	if is_reduced_motion():
		card.scale = Vector2.ONE
		tween.tween_property(card, "modulate:a", 1.0, _REDUCED_FADE_TIME)
		return tween

	card.scale = Vector2.ONE * 0.96
	var delay: float = minf(maxi(index, 0), 7) * 0.04
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_property(card, "modulate:a", 1.0, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween


## 数值变化的短脉冲。
static func pulse(control: Control) -> Tween:
	control.pivot_offset = control.size * 0.5
	var tween: Tween = _new_tween(control)
	if is_reduced_motion():
		control.scale = Vector2.ONE
		tween.tween_property(control, "scale", Vector2.ONE, 0.0)
		return tween

	control.scale = Vector2.ONE
	tween.tween_property(control, "scale", Vector2.ONE * 1.16, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tween


## 平滑更新 Range；用于经验条、进度条和 Slider。
static func tween_range(range_node: Range, target: float, duration: float = 0.16) -> Tween:
	var tween: Tween = _new_tween(range_node)
	if is_reduced_motion():
		range_node.value = target
		tween.tween_property(range_node, "value", target, 0.0)
		return tween
	tween.tween_property(range_node, "value", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return tween


## 结算数值从 0 滚到结果，template 使用一个 %d 占位符。
static func count_label(label: Label, target: int, template: String = "%d") -> Tween:
	var tween: Tween = _new_tween(label)
	if is_reduced_motion():
		label.text = template % target
		tween.tween_property(label, "modulate:a", label.modulate.a, 0.0)
		return tween

	var update_text: Callable = func(value: float) -> void:
		label.text = template % int(round(value))
	tween.tween_method(update_text, 0.0, float(target), 0.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	return tween


static func _new_tween(control: Control) -> Tween:
	var previous: Variant = control.get_meta(_TWEEN_META) if control.has_meta(_TWEEN_META) else null
	if previous is Tween:
		var previous_tween: Tween = previous as Tween
		if previous_tween.is_valid():
			previous_tween.kill()
	var tween: Tween = control.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	control.set_meta(_TWEEN_META, tween)
	return tween


static func _scale_button(button: BaseButton, target: float, duration: float) -> void:
	button.pivot_offset = button.size * 0.5
	var tween: Tween = _new_tween(button)
	if is_reduced_motion():
		button.scale = Vector2.ONE
		tween.tween_property(button, "scale", Vector2.ONE, 0.0)
		return
	tween.tween_property(button, "scale", Vector2.ONE * target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## 刷新金币标签
func _refresh_gold_label(label: Label) -> void:
	if label:
		label.text = "金币: %d" % SaveSystem.get_gold()


## 创建列表行 Panel（带暗林深色样式）
func _create_list_row(min_height: float, bg_color: Color = Color(0.0784314, 0.101961, 0.0941176, 0.95), border_color: Color = Color(0.27451, 0.337255, 0.286275, 1)) -> Panel:
	var row_node: Panel = Panel.new()
	row_node.custom_minimum_size = Vector2(0, min_height)
	row_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	row_node.add_theme_stylebox_override("panel", style)
	return row_node


## 清理容器所有子节点
func _clear_container(container: Node) -> void:
	if container:
		for child in container.get_children():
			child.queue_free()


## 创建使用项目统一 Theme 的文字按钮。
func _create_text_button(label_text: String, min_size: Vector2, font_color: Color = Color(0.94902, 0.917647, 0.843137, 1)) -> Button:
	var btn: Button = Button.new()
	btn.text = label_text
	btn.custom_minimum_size = min_size
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	bind_button(btn)
	return btn


## 创建列表为空时的居中提示文字
func _create_empty_hint(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.666667, 0.713725, 0.67451, 1))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 80)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
