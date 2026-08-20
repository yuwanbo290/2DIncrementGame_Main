extends Node

var ui_cache = {}

var ui_root: Node = null


func initialize(root: Node):
	ui_root = root

func open_ui(ui_name: String, path: String):
	if ui_cache.has(ui_name):
		ui_cache[ui_name].on_open()
		return

	# 如果 ui_root 无效（如场景切换后），使用 SceneTree.root 作为后备
	var root: Node = ui_root
	if not is_instance_valid(root):
		root = get_tree().root

	var scene_res: PackedScene = load(path)
	if scene_res == null:
		push_error("无法加载场景: " + path)
		return

	var ui: Node = scene_res.instantiate()
	ui._ui_managed = true  # 标记为由 UIManager 管理，_ready 不自动初始化
	root.add_child(ui)

	ui.on_create()
	ui.on_open()

	ui_cache[ui_name] = ui

func close_ui(ui_name: String):
	if not ui_cache.has(ui_name):
		return

	ui_cache[ui_name].on_close()

func destroy_ui(ui_name: String):
	if not ui_cache.has(ui_name):
		return

	var ui = ui_cache[ui_name]

	ui.on_destroy()

	ui_cache.erase(ui_name)


## 切换场景前清理所有缓存的 UI
func clear_all():
	for ui_name in ui_cache.keys():
		var ui = ui_cache[ui_name]
		if is_instance_valid(ui):
			ui.on_destroy()
	ui_cache.clear()
	ui_root = null