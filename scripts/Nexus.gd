extends Node

class_name Nexus

@export var lobby_url : String = "localhost/nexus/ws"

signal log(msg)
signal room_data(_peerid, bytes)
signal room_state_changed(id)
signal msg_recieved(msgid, msg)
signal player_msg(id,playername,status)

enum ConnState {
	Offline,
	NoRoom,
	RoomConnecting,
	RoomConected
}
@export var connecting : bool = false
var is_server : bool = false
var peer_id : int = -1
var conn_state : ConnState

var _appname : String = ""
var _players : Dictionary = {}
var _room_id : String=""
var _roomname : String = ""

@export var playername : String = "Player"


func connect_lobby() -> Error:
	print(name, " Nexus has no implemented connect_lobby")
	return ERR_CANT_CONNECT

func close_lobby():
	print(name, " Nexus has no implemented close_lobby")
	pass
	
func is_online() -> bool:
	print(name, " Nexus has no implemented is_online")
	return false

func is_room_online() -> bool:
	print(name, " Nexus has no implemented is_room_online")
	return false

func is_room_server():
	print(name, " Nexus has no implemented is_room_server")
	return false

func create_room(room_id:String="1234",room_pwd:String="") -> Error:
	print(name, " Nexus has no implemented create_room")
	return ERR_CANT_CREATE

func join_room(room_id:String="1234",room_pwd:String="") -> Error:
	print(name, " Nexus has no implemented join_room")
	return ERR_CANT_CONNECT


#func _send_room_packet_to(dst:int, bytes:PackedByteArray, except_peer:int=255):
	#if is_room_online() and bytes.size()>0 and dst!=peer_id:
		#var pk = PackedByteArray([1,0,peer_id,dst,except_peer])
		#pk.append_array(bytes)
		#_send_packet(pk)
		
func send_room_packet(bytes:PackedByteArray, dst:int,except_peer:int=255):
	print(name, " Nexus has no implemented send_room_packet")
	pass

func close_room():
	print(name, " Nexus has no implemented close_room")
	return ERR_FILE_CANT_WRITE

func set_join_status(status:bool):
	print(name, " Nexus has no implemented set_join_status")
	pass

func _poll():
	print(name, " Nexus has no implemented _poll")

#func _on_packet_in(pk:PackedByteArray):
	#pass
