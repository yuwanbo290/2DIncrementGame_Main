extends Control
class_name ConfirmDialog

## 可复用的二次确认对话框
## 用法：实例化场景后调用 setup() 设置文本和回调

@onready var _title: Label = $DialogPanel/DialogMargin/DialogVBox/Title
@onready var _message: Label = $DialogPanel/DialogMargin/DialogVBox/Message
@onready var _confirm_btn: TextureButton = $DialogPanel/DialogMargin/DialogVBox/BtnRow/ConfirmBtn
@onready var _cancel_btn: TextureButton = $DialogPanel/DialogMargin/DialogVBox/BtnRow/CancelBtn

var _confirm_callback: Callable
var _cancel_callback: Callable


func _ready() -> void:
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_add_hover(_confirm_btn)
	_add_hover(_cancel_btn)


## 设置对话框内容
## [param title_text] 标题文本
## [param message_text] 描述文本
## [param confirm_cb] 确认回调
## [param cancel_cb] 取消回调（可选，默认无操作）
func setup(title_text: String, message_text: String, confirm_cb: Callable, cancel_cb: Callable = Callable()) -> void:
	_title.text = title_text
	_message.text = message_text
	_confirm_callback = confirm_cb
	_cancel_callback = cancel_cb


func _on_confirm_pressed() -> void:
	if _confirm_callback.is_valid():
		_confirm_callback.call()
	queue_free()


func _on_cancel_pressed() -> void:
	if _cancel_callback.is_valid():
		_cancel_callback.call()
	queue_free()


func _add_hover(btn: TextureButton, brightness: float = 1.15) -> void:
	btn.mouse_entered.connect(func(): btn.modulate = Color(brightness, brightness, brightness, 1))
	btn.mouse_exited.connect(func(): btn.modulate = Color(1, 1, 1, 1))
