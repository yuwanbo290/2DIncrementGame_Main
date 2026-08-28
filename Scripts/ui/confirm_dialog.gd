extends ConfirmationDialog
class_name ConfirmDialog

const UI_ICONS := preload("res://Textures/ui/moss_ember_icons.png")


func _ready() -> void:
	# 原生弹窗可能出现在暂停场景，交互与按钮动效始终继续处理。
	process_mode = Node.PROCESS_MODE_ALWAYS
	var confirm_button: Button = get_ok_button()
	var cancel_button: Button = get_cancel_button()
	confirm_button.theme_type_variation = &"PrimaryButton"
	cancel_button.theme_type_variation = &""
	confirm_button.custom_minimum_size = Vector2(112, 44)
	cancel_button.custom_minimum_size = Vector2(96, 44)
	confirm_button.icon = _create_confirm_icon()
	confirm_button.add_theme_constant_override("icon_max_width", 20)
	UIBase.bind_button(confirm_button)
	UIBase.bind_button(cancel_button)


## 使用 Godot 原生 ConfirmationDialog 设置文本和一次性回调。
## [param title_text] 标题文本
## [param message_text] 描述文本
## [param confirm_cb] 确认回调
## [param cancel_cb] 取消回调（可选，默认无操作）
func setup(title_text: String, message_text: String, confirm_cb: Callable, cancel_cb: Callable = Callable()) -> void:
	title = title_text
	dialog_text = message_text
	get_ok_button().text = "确认"
	get_cancel_button().text = "取消"
	confirmed.connect(func():
		if confirm_cb.is_valid():
			confirm_cb.call()
		queue_free()
	, CONNECT_ONE_SHOT)
	canceled.connect(func():
		if cancel_cb.is_valid():
			cancel_cb.call()
		queue_free()
	, CONNECT_ONE_SHOT)
	popup_centered(Vector2i(440, 240))


## 从现有图集中裁切确认图标，保持弹窗继续使用原生按钮结构。
func _create_confirm_icon() -> AtlasTexture:
	var icon := AtlasTexture.new()
	icon.atlas = UI_ICONS
	icon.region = Rect2(96, 64, 32, 32)
	return icon
