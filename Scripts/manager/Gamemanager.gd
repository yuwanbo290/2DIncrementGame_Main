extends Node2D


func _ready():
	UIManager.initialize($UINode/UIRoot)

	# 应用存档中的设置到全局
	_apply_startup_settings()

	UIManager.open_ui(
		"start_ui",
		"res://Scenes/ui/start_ui.tscn"
	)


func _apply_startup_settings() -> void:
	var settings: Dictionary = SaveSystem.data.get("settings", {})

	# 分辨率
	var res: String = settings.get("resolution", "1280x720")
	var parts: PackedStringArray = res.split("x")
	if parts.size() == 2:
		get_window().size = Vector2i(int(parts[0]), int(parts[1]))

	# 窗口模式
	var wm: String = settings.get("window_mode", "windowed")
	match wm:
		"fullscreen":
			get_window().mode = Window.MODE_FULLSCREEN
		"borderless":
			get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_:
			get_window().mode = Window.MODE_WINDOWED

	# 音量
	var master_vol: float = settings.get("master_volume", 1.0)
	var music_vol: float = settings.get("music_volume", 1.0)
	var sfx_vol: float = settings.get("sfx_volume", 1.0)

	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx != -1:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(master_vol))
	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(music_vol))
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_vol))
