extends Node

class_name NetComponent

var nentity : NetEntity
var cid : int = -1


func send_comp_msg(peer_target:int,msgid:int, param, except_peer:int=255):
	if nentity and cid!=-1:
		nentity.send_comp_msg(peer_target, cid, msgid, param, except_peer)

func _recieve_packet(orip:int, msgid:int, param):
	pass
