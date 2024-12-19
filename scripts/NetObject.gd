extends Node

class_name NetObject

@export var obj_id : int = -1
@export var net_root : NetRoot

func _ready():
	if net_root==null:
		if get_tree().root.get_child(0) is NetRoot:
			net_root = get_tree().root.get_child(0)
		elif owner is NetRoot:
			net_root = owner
		elif owner and owner.owner is NetRoot:
			net_root = owner.owner
		elif owner.owner and owner.owner.owner is NetRoot:
			net_root = owner.owner.owner
	assert(net_root)
	net_root.register_object(self)

func get_sync_data():
	return [obj_id,name]

func is_input_object():
	return net_root and net_root.input_entity == self

func is_host():
	return net_root and net_root.is_host()

func get_peer_id():
	return net_root.playerid


func send_net_msg(peer_target:int, msgid:int, param, except_peer:int=255):
	if net_root and net_root.is_online():
		var bytes = var_to_bytes(param)
		net_root.send_object_packet(peer_target,obj_id,msgid,bytes, except_peer)

func broadcast_net_msg(msgid:int, param, except_peer:int=255):
	if net_root and net_root.is_online():
		var peer_target : int = 255 if is_host() else 0
		var bytes = var_to_bytes(param)
		net_root.send_object_packet(peer_target,obj_id,msgid,bytes, except_peer)

func set_sync_data(arr):
	obj_id = arr[0]
	if name!=arr[1]:
		name = arr[1]

func _recieve_packet(origin_peer:int, msgid:int, params):
	pass
