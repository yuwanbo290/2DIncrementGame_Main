extends Node

var ui_cache: Dictionary = {}
var ui_root: Node
var _input_blocker: Control
var _active_transitions: Dictionary = {}


func initialize(root: Node) -> void:
	ui_root = root
	_input_blocker = Control.new()
	_input_blocker.name = "TransitionInputBlocker"
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_blocker.focus_mode = Control.FOCUS_NONE
	_input_blocker.z_index = 4096
	ui_root.add_child(_input_blocker)
	_input_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_input_blocker.hide()


func open_ui(ui_name: String, path: String) -> void:
	if ui_cache.has(ui_name):
		var cached_ui: UIBase = ui_cache[ui_name] as UIBase
		_show_ui(cached_ui, true)
		return

	# 如果 ui_root 无效（如场景切换后），使用 SceneTree.root 作为后备
	var root: Node = ui_root
	if not is_instance_valid(root):
		root = get_tree().root

	var scene_res: PackedScene = load(path)
	if scene_res == null:
		push_error("无法加载场景: " + path)
		return

	var ui: UIBase = scene_res.instantiate() as UIBase
	if ui == null:
		push_error("UI 场景根节点必须继承 UIBase: " + path)
		return
	root.add_child(ui)
	ui_cache[ui_name] = ui
	_show_ui(ui, false)


func close_ui(ui_name: String) -> void:
	if not ui_cache.has(ui_name):
		return
	var ui: UIBase = ui_cache[ui_name] as UIBase
	if not is_instance_valid(ui) or not ui.visible:
		return
	var tween: Tween = ui.play_exit(_finish_close.bind(ui))
	_track_transition(ui, tween)


func _show_ui(ui: UIBase, refresh_content: bool) -> void:
	ui.show()
	if refresh_content:
		ui.refresh()
	var tween: Tween = ui.play_enter()
	_track_transition(ui, tween)


func _finish_close(ui: UIBase) -> void:
	if not is_instance_valid(ui):
		return
	ui.hide()


## 同一页面重入时替换旧 Tween；不同页面可同时淡入淡出。
func _track_transition(ui: UIBase, tween: Tween) -> void:
	_active_transitions[ui.get_instance_id()] = tween
	if is_instance_valid(_input_blocker):
		_input_blocker.show()
	if ui_root is Control:
		(ui_root as Control).focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	tween.finished.connect(_finish_transition.bind(ui, tween), CONNECT_ONE_SHOT)


func _finish_transition(ui: UIBase, tween: Tween) -> void:
	var instance_id: int = ui.get_instance_id()
	if _active_transitions.get(instance_id) != tween:
		return
	_active_transitions.erase(instance_id)
	if not _active_transitions.is_empty():
		return
	if is_instance_valid(_input_blocker):
		_input_blocker.hide()
	if ui_root is Control:
		(ui_root as Control).focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
	_focus_top_ui()


## 转场结束后把焦点交给最上层可见页面；覆盖层关闭时会自然回到底层页面。
func _focus_top_ui() -> void:
	if not is_instance_valid(ui_root):
		return
	var children: Array[Node] = ui_root.get_children()
	children.reverse()
	for child in children:
		if child is UIBase and child.visible:
			var focus_target: Control = (child as UIBase).get_default_focus()
			if focus_target:
				focus_target.grab_focus()
			return


## 切换场景前清理所有缓存的 UI
func clear_all() -> void:
	for ui_name in ui_cache.keys():
		var ui: UIBase = ui_cache[ui_name] as UIBase
		if is_instance_valid(ui):
			ui.queue_free()
	ui_cache.clear()
	_active_transitions.clear()
	if is_instance_valid(_input_blocker):
		_input_blocker.hide()
	_input_blocker = null
	ui_root = null
