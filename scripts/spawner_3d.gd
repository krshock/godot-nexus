extends Node3D

class_name Spawner3D

@export var net_root : NetRoot

func _ready():
	assert(net_root,"property net_root not set in node " + name)
	net_root.player_status.connect(func(id,_name,_status):
		if is_host() and _status==1:
			var sp = preload("res://fps/spawns/base_player.tscn")
			var i = sp.instantiate()
			if i is CharacterBase:
				i.net_root = net_root
				i.peer_id=id
				i._disable_on_sync = true
			add_child(i)
	)
	await get_tree().process_frame
	if is_host():
		if net_root.playerid == 0:
			var sp = preload("res://fps/spawns/base_player.tscn")
			var i = sp.instantiate()
			if i is CharacterBase:
				i.net_root = net_root
				i.peer_id=net_root.playerid
				net_root.input_entity = i
			add_child(i)

func is_host():
	return net_root and net_root.is_host()

func send_net_msg(target_peer:int, msgid:int, variant):
	if net_root and net_root.nexus:
		var pk = PackedByteArray([3,msgid])
		if variant:
			pk.append_array(var_to_bytes(variant))
		net_root.nexus.send_room_packet(pk,target_peer)


func _recieve_packet(orip:int, msgid:int, bytes):
	pass
