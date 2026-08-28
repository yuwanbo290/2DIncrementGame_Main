extends Control

class_name UIBase

## 全项目按钮使用同一份 Godot Theme，由 Button 原生状态处理 hover / pressed / disabled。
const BUTTON_THEME := preload("res://Resources/button_theme.tres")


func _ready() -> void:
	theme = BUTTON_THEME
	refresh()


## UIManager 重新显示缓存界面时调用；子类仅覆写需要刷新的内容。
func refresh() -> void:
	pass


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


## 创建使用项目统一 Theme 的文字按钮。
## 返回的按钮未连接信号、未禁用，由调用方决定 disabled / connect。
## [param label_text] 按钮文字
## [param min_size] 按钮最小尺寸
## [param font_color] 文字颜色
func _create_text_button(label_text: String, min_size: Vector2, font_color: Color = Color(1, 1, 1, 1)) -> Button:
	var btn: Button = Button.new()
	btn.theme = BUTTON_THEME
	btn.text = label_text
	btn.custom_minimum_size = min_size
	btn.add_theme_color_override("font_color", font_color)
	btn.add_theme_color_override("font_hover_color", font_color)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
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
