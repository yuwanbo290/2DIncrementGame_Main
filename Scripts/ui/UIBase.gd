extends Control

class_name UIBase

var is_open := false


func on_create():
	pass


func on_open():
	is_open = true

	visible = true


func on_close():
	is_open = false

	visible = false


func on_destroy():
	queue_free()
