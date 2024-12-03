@tool
extends EditorPlugin


func _enter_tree():
	
	add_autoload_singleton("NexusTCP", "res://addons/godot-nexus/scripts/NexusTcp.gd")
	add_autoload_singleton("NexusWS", "res://addons/godot-nexus/scripts/NexusWebsocket.gd")

func _exit_tree():
	# Clean-up of the plugin goes here.
	remove_autoload_singleton("NexusTCP")
	remove_autoload_singleton("NexusWS")
	pass
