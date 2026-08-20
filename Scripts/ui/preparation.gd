extends UIBase

func on_create():
	var back_btn: TextureButton = $TopBar/BackBtn as TextureButton
	var upgrade_btn: TextureButton = $MainContainer/VBox/MainRow/LeftVBox/UpgradeBtn as TextureButton
	var shop_btn: TextureButton = $MainContainer/VBox/MainRow/LeftVBox/ShopBtn as TextureButton
	var equip_btn: TextureButton = $MainContainer/VBox/MainRow/CenterVBox/EquipBtn as TextureButton
	var start_btn: TextureButton = $MainContainer/VBox/MainRow/CenterVBox/StartHuntBtn as TextureButton

	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		_add_hover(back_btn)
	if upgrade_btn:
		upgrade_btn.pressed.connect(_on_upgrade_pressed)
		_add_hover(upgrade_btn)
	if shop_btn:
		shop_btn.pressed.connect(_on_shop_pressed)
		_add_hover(shop_btn)
	if equip_btn:
		equip_btn.pressed.connect(_on_equip_pressed)
		_add_hover(equip_btn)
	if start_btn:
		start_btn.pressed.connect(_on_start_battle_pressed)
		_add_hover(start_btn)


func on_open():
	super()
	_refresh_top_bar()


func on_close():
	super()


func on_destroy():
	super()


func _refresh_top_bar() -> void:
	var gold_label: Label = $TopBar/GoldLabel as Label
	var slot_info: Label = $TopBar/SlotInfo as Label
	_refresh_gold_label(gold_label)
	if slot_info:
		var slot: Dictionary = SaveSystem.get_current_slot()
		slot_info.text = slot.get("name", "未选择存档")


func _on_back_pressed() -> void:
	UIManager.close_ui("preparation")
	UIManager.open_ui("save_select", "res://Scenes/ui/save_select.tscn")


func _on_upgrade_pressed() -> void:
	UIManager.open_ui("out_of_battle_upgrade", "res://Scenes/ui/out_of_battle_upgrade.tscn")


func _on_shop_pressed() -> void:
	UIManager.open_ui("shop", "res://Scenes/ui/shop.tscn")


func _on_equip_pressed() -> void:
	UIManager.open_ui("equipment", "res://Scenes/ui/equipment.tscn")


func _on_start_battle_pressed() -> void:
	SaveSystem.save()
	UIManager.clear_all()
	get_tree().change_scene_to_file("res://Scenes/battle.tscn")
