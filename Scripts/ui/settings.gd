extends UIBase

const RESOLUTIONS: Array[String] = [
	"1280x720",
	"1366x768",
	"1600x900",
	"1920x1080",
	"2560x1440",
	"3840x2160",
]

const WINDOW_MODES: Array[String] = [
	"窗口",
	"全屏",
	"无边框",
]

var _current_settings: Dictionary = {}


func _ready() -> void:
	var res_option: OptionButton = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/DisplaySection/ResolutionRow/ResolutionOption as OptionButton
	res_option.clear()
	for r in RESOLUTIONS:
		res_option.add_item(r)
	res_option.item_selected.connect(_on_resolution_changed)

	var win_option: OptionButton = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/DisplaySection/WindowRow/WindowOption as OptionButton
	win_option.clear()
	for w in WINDOW_MODES:
		win_option.add_item(w)
	win_option.item_selected.connect(_on_window_mode_changed)
	# 分辨率/窗口模式切换时立即保存
	res_option.item_selected.connect(func(_i): _save_immediate())
	win_option.item_selected.connect(func(_i): _save_immediate())

	var master_slider: HSlider = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/AudioSection/MasterRow/MasterSlider as HSlider
	var music_slider: HSlider = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/AudioSection/MusicRow/MusicSlider as HSlider
	var sfx_slider: HSlider = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/AudioSection/SFXRow/SFXSlider as HSlider

	master_slider.value_changed.connect(_on_master_volume_changed)
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)

	var reset_btn: Button = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/BtnRow/ResetBtn as Button
	var save_btn: Button = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/BtnRow/SaveBtn as Button

	reset_btn.pressed.connect(_on_reset_pressed)
	# 保存按钮改为返回：设置已即时保存，无需手动保存
	save_btn.pressed.connect(_on_back_pressed)
	super()


func refresh() -> void:
	_load_settings()


func _load_settings() -> void:
	_current_settings = SaveSystem.data.get("settings", {}).duplicate(true)

	var res_option: OptionButton = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/DisplaySection/ResolutionRow/ResolutionOption as OptionButton
	var win_option: OptionButton = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/DisplaySection/WindowRow/WindowOption as OptionButton
	var master_slider: HSlider = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/AudioSection/MasterRow/MasterSlider as HSlider
	var music_slider: HSlider = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/AudioSection/MusicRow/MusicSlider as HSlider
	var sfx_slider: HSlider = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/AudioSection/SFXRow/SFXSlider as HSlider

	var res: String = _current_settings.get("resolution", "1280x720")
	var res_idx: int = RESOLUTIONS.find(res)
	if res_idx == -1:
		res_idx = 0
	res_option.select(res_idx)

	var wm: String = _current_settings.get("window_mode", "windowed")
	var wm_map: Dictionary = {"windowed": 0, "fullscreen": 1, "borderless": 2}
	var wm_idx: int = wm_map.get(wm, 0)
	win_option.select(wm_idx)

	var master_vol: float = _current_settings.get("master_volume", 1.0)
	var music_vol: float = _current_settings.get("music_volume", 1.0)
	var sfx_vol: float = _current_settings.get("sfx_volume", 1.0)

	master_slider.value = master_vol
	music_slider.value = music_vol
	sfx_slider.value = sfx_vol

	_update_volume_labels()


func _update_volume_labels() -> void:
	var master_val: Label = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/AudioSection/MasterRow/MasterValue as Label
	var music_val: Label = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/AudioSection/MusicRow/MusicValue as Label
	var sfx_val: Label = $MainContainer/VBox/ContentPanel/ContentMargin/ContentVBox/AudioSection/SFXRow/SFXValue as Label

	master_val.text = "%d%%" % int(_current_settings.get("master_volume", 1.0) * 100)
	music_val.text = "%d%%" % int(_current_settings.get("music_volume", 1.0) * 100)
	sfx_val.text = "%d%%" % int(_current_settings.get("sfx_volume", 1.0) * 100)


func _on_resolution_changed(idx: int) -> void:
	var res: String = RESOLUTIONS[idx]
	_current_settings["resolution"] = res
	GameManager.apply_settings(_current_settings, get_window())


func _on_window_mode_changed(idx: int) -> void:
	var mode_map: Dictionary = {0: "windowed", 1: "fullscreen", 2: "borderless"}
	var wm: String = mode_map.get(idx, "windowed")
	_current_settings["window_mode"] = wm
	GameManager.apply_settings(_current_settings, get_window())


func _on_master_volume_changed(value: float) -> void:
	_current_settings["master_volume"] = value
	_update_volume_labels()
	GameManager.apply_settings(_current_settings, get_window())
	_save_immediate()


func _on_music_volume_changed(value: float) -> void:
	_current_settings["music_volume"] = value
	_update_volume_labels()
	GameManager.apply_settings(_current_settings, get_window())
	_save_immediate()


func _on_sfx_volume_changed(value: float) -> void:
	_current_settings["sfx_volume"] = value
	_update_volume_labels()
	GameManager.apply_settings(_current_settings, get_window())
	_save_immediate()


func _on_back_pressed() -> void:
	UIManager.close_ui("settings")


func _on_reset_pressed() -> void:
	var defaults: Dictionary = {
		"master_volume": 1.0,
		"music_volume": 1.0,
		"sfx_volume": 1.0,
		"resolution": "1280x720",
		"window_mode": "windowed",
		"lang": "zh_CN",
	}
	# 先保存默认值，再 _load_settings 才能正确刷新 UI
	_current_settings = defaults.duplicate(true)
	SaveSystem.data["settings"] = defaults.duplicate(true)
	SaveSystem.save()
	_load_settings()
	GameManager.apply_settings(_current_settings, get_window())
	_show_toast("已恢复默认设置")


func _save_immediate() -> void:
	SaveSystem.data["settings"] = _current_settings.duplicate(true)
	SaveSystem.save()


func _show_toast(msg: String) -> void:
	var toast: Label = Label.new()
	toast.text = msg
	toast.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1))
	toast.add_theme_font_size_override("font_size", 18)
	toast.anchor_left = 0.5
	toast.anchor_top = 0.5
	toast.anchor_right = 0.5
	toast.anchor_bottom = 0.5
	toast.offset_left = -80
	toast.offset_right = 80
	toast.offset_top = 40
	toast.offset_bottom = 70
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE

	get_tree().root.add_child(toast)

	var timer: SceneTreeTimer = get_tree().create_timer(1.5)
	timer.timeout.connect(func():
		var tw: Tween = toast.create_tween()
		tw.tween_property(toast, "modulate", Color(1, 1, 1, 0), 0.5)
		tw.tween_callback(toast.queue_free)
	)
