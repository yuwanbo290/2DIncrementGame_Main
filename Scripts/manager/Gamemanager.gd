extends Node2D
class_name GameManager


func _ready():
	UIManager.initialize($UINode/UIRoot)

	apply_settings(SaveSystem.data.get("settings", {}), get_window())

	UIManager.open_ui(
		"start_ui",
		"res://Scenes/ui/start_ui.tscn"
	)


## 将存档设置应用到窗口和音频；启动与设置界面共用同一入口。
static func apply_settings(settings: Dictionary, window: Window) -> void:
	var res: String = settings.get("resolution", "1280x720")
	var parts: PackedStringArray = res.split("x")
	if parts.size() == 2:
		window.size = Vector2i(int(parts[0]), int(parts[1]))

	var wm: String = settings.get("window_mode", "windowed")
	match wm:
		"fullscreen":
			window.mode = Window.MODE_FULLSCREEN
		"borderless":
			window.mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			window.mode = Window.MODE_WINDOWED

	var buses: Dictionary = {
		"Master": "master_volume",
		"Music": "music_volume",
		"SFX": "sfx_volume",
	}
	for bus_name: String in buses:
		var bus_index: int = AudioServer.get_bus_index(bus_name)
		if bus_index != -1:
			AudioServer.set_bus_volume_db(
				bus_index,
				linear_to_db(float(settings.get(buses[bus_name], 1.0)))
			)
