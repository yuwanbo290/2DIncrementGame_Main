extends Node


func _ready():
	UIManager.initialize($UINode/UIRoot)

	UIManager.open_ui(
		"start_ui",
		"res://Scenes/ui/start_ui.tscn"
	)
