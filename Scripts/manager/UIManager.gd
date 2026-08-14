extends Node

var ui_cache = {}

var ui_root: Node = null


func initialize(root: Node):
	ui_root = root

func open_ui(ui_name: String, path: String):
	if ui_cache.has(ui_name):
		ui_cache[ui_name].on_open()

		return

	if ui_root == null:
		push_error("UIRoot 未初始化")

		return

	var scene = load(path)

	var ui = scene.instantiate()

	ui_root.add_child(ui)

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