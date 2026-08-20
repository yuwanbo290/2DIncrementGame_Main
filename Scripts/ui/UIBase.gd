extends Control

class_name UIBase

## 像素风按钮底图（同文件资源常量化，见 AI开发规范 5.8）
const BTN_TEXTURE := preload("res://Textures/ui/btn_plain.png")

var is_open: bool = false
var _initialized: bool = false
var _ui_managed: bool = false  # 标记是否由 UIManager 管理


func _ready() -> void:
	# 如果不是由 UIManager 管理（如 change_scene_to_file 直接加载），自动初始化
	if not _ui_managed:
		on_create()
		on_open()


func on_create():
	_initialized = true
	pass


func on_open():
	is_open = true
	visible = true


func on_close():
	is_open = false
	visible = false


func on_destroy():
	queue_free()


# ---- 公共辅助方法（子类可直接调用） ----

## 给按钮添加背景亮度和 hover 高亮效果
func _add_hover(btn: TextureButton, brightness: float = 1.3) -> void:
	btn.modulate = Color(1.15, 1.15, 1.15, 1)  # 正常态稍亮，使按钮更显眼
	btn.mouse_entered.connect(func(): btn.modulate = Color(brightness, brightness, brightness, 1))
	btn.mouse_exited.connect(func(): btn.modulate = Color(1.15, 1.15, 1.15, 1))


## 刷新金币标签
func _refresh_gold_label(label: Label) -> void:
	if label:
		label.text = "金币: %d" % SaveSystem.get_gold()


## 创建列表行 Panel（带像素风深色样式）
func _create_list_row(min_height: float, bg_color: Color = Color(0.12, 0.14, 0.18, 0.95), border_color: Color = Color(0.3, 0.3, 0.4, 1)) -> Panel:
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


## 创建带文字标识的像素风按钮（TextureButton + 铺满的居中 Label）
## 返回的按钮未连接信号、未禁用，由调用方决定 disabled / connect / _add_hover。
## [param label_text] 按钮文字
## [param min_size] 按钮最小尺寸
## [param font_color] 文字颜色
func _create_text_button(label_text: String, min_size: Vector2, font_color: Color = Color(1, 1, 1, 1)) -> TextureButton:
	var btn: TextureButton = TextureButton.new()
	# 脚本里必须用 texture_normal（TextureButton 没有 texture 属性）
	btn.texture_normal = BTN_TEXTURE
	# 底图为 2240x1680，不忽略纹理尺寸会把最小尺寸撑到原图大小、破坏布局
	btn.ignore_texture_size = true
	# 等比覆盖：纹理铺满按钮且不溢出（Godot 默认 STRETCH_KEEP 会按原始像素绘制，纹理 2240 宽会溢出按钮）
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
	btn.custom_minimum_size = min_size

	var label: Label = Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 子 Label 必须忽略鼠标，否则拦截按钮点击（历史踩坑 2）
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return btn


## 创建列表为空时的居中提示文字
func _create_empty_hint(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0, 80)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label
