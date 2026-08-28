extends Node

var ui_cache: Dictionary = {}
var ui_root: Node


func initialize(root: Node) -> void:
	ui_root = root

func open_ui(ui_name: String, path: String) -> void:
	if ui_cache.has(ui_name):
		var cached_ui: UIBase = ui_cache[ui_name] as UIBase
		cached_ui.show()
		cached_ui.refresh()
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

func close_ui(ui_name: String) -> void:
	if not ui_cache.has(ui_name):
		return
	var ui: UIBase = ui_cache[ui_name] as UIBase
	ui.hide()


## 切换场景前清理所有缓存的 UI
func clear_all() -> void:
	for ui_name in ui_cache.keys():
		var ui: UIBase = ui_cache[ui_name] as UIBase
		if is_instance_valid(ui):
			ui.queue_free()
	ui_cache.clear()
	ui_root = null
