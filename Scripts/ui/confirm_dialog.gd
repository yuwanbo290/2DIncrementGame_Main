extends ConfirmationDialog
class_name ConfirmDialog

## 使用 Godot 原生 ConfirmationDialog 设置文本和一次性回调。
## [param title_text] 标题文本
## [param message_text] 描述文本
## [param confirm_cb] 确认回调
## [param cancel_cb] 取消回调（可选，默认无操作）
func setup(title_text: String, message_text: String, confirm_cb: Callable, cancel_cb: Callable = Callable()) -> void:
	title = title_text
	dialog_text = message_text
	get_ok_button().text = "确认"
	get_ok_button().theme = UIBase.BUTTON_THEME
	get_cancel_button().text = "取消"
	get_cancel_button().theme = UIBase.BUTTON_THEME
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
