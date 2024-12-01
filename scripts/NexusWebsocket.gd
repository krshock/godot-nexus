extends Nexus

class_name NexusWebsocket

var wsclient : WebSocketPeer = WebSocketPeer.new()

var on_connected_packet # PackedByteArray

func _ready():
	log.connect(func(msg):
		print(playername, " -> ",  str(msg))
	)
	player_msg.connect(func(_id,_name,_status):
		log.emit(playername+" Player_msg: " + str(_id)+ " Name="+_name+ " Status:"+str(_status))
	)
	room_state_changed.connect(func(id):
		log.emit("room_state_changed, " + str(ConnState.keys()[id]))	
	)
	#await get_tree().create_timer(1.5).timeout
	#while is_instance_valid(self):
		#if connecting and wsclient.get_ready_state()==WebSocketPeer.STATE_CLOSED:
			#connect_lobby()
		#await get_tree().create_timer(1.5).timeout


#func connect_lobby() -> Error:
	#wsclient.supported_protocols = []
	#return wsclient.connect_to_url("ws://"+lobby_url)

func close_lobby():
	wsclient.close()
	
func is_online():
	return wsclient.get_ready_state()==WebSocketPeer.STATE_OPEN

func is_room_online():
	return conn_state==ConnState.RoomConected

func is_room_server():
	return peer_id==0

func create_room(room_id:String="1234",room_pwd:String="") -> Error:
	if conn_state!=ConnState.Offline:
		print("Cannot create, conn:state="+str(conn_state))
		return ERR_CANT_CREATE
	var msg = {
		"room_id":room_id,
		"room_pwd" : room_pwd,
		"app_name" : _appname,
		"player_name":playername}
	conn_state = ConnState.RoomConnecting
	room_state_changed.emit(conn_state)
	is_server = true
	var pk : PackedByteArray = PackedByteArray([0,0])
	pk.append_array(JSON.stringify(msg).to_utf8_buffer())
	on_connected_packet = pk
	print(wsclient.connect_to_url("ws://"+lobby_url))
	return OK

func join_room(room_id:String="1234",room_pwd:String="") -> Error:
	if conn_state!=ConnState.Offline:
		print("Cannot join, conn:state="+str(conn_state))
		return ERR_CANT_CREATE
	var msg = {
		"room_id":room_id,
		"room_pwd" : room_pwd,
		"app_name" : _appname,
		"player_name":playername}
	conn_state = ConnState.RoomConnecting
	room_state_changed.emit(conn_state)
	is_server = false
	
	var pk : PackedByteArray = PackedByteArray()
	pk.append(0)
	pk.append(1) #Join room
	pk.append_array(JSON.stringify(msg).to_utf8_buffer())
	on_connected_packet = pk
	print(wsclient.connect_to_url("ws://"+lobby_url))

	return OK


func _send_packet(bytes:PackedByteArray):
	if is_online():
		wsclient.send(bytes)

#func _send_room_packet_to(dst:int, bytes:PackedByteArray, except_peer:int=255):
	#if is_room_online() and bytes.size()>0 and dst!=peer_id:
		#var pk = PackedByteArray([1,0,peer_id,dst,except_peer])
		#pk.append_array(bytes)
		#_send_packet(pk)
		
func send_room_packet(bytes:PackedByteArray, dst:int,except_peer:int=255):
	if is_room_online():
		if peer_id!=0 and dst!=0:
			print_debug("Only host can send broadcasts, packet not sent")
			return
		var p = PackedByteArray([1,0,peer_id,dst,except_peer])
		p.append_array(bytes)
		wsclient.send(p)

func close_room():
	wsclient.close()
	conn_state = ConnState.Offline
	room_state_changed.emit(conn_state)
	return OK

func set_join_status(status:bool):
	if is_server and is_online(): 
		var pk = PackedByteArray([1,2, 1 if status else 0])
		_send_packet(pk)

var old_state : int = -1

func _process(_delta):
	_poll()

func _poll():
	wsclient.poll()

	var state = wsclient.get_ready_state()
	if state!=old_state:

		old_state = state
		var states = ["Connecting", "Connected", "Clossing", "Closed"]
		print("NEW_SOCKET_STATE: " + states[state])
		
		if state == WebSocketPeer.STATE_OPEN:		
			if on_connected_packet:
				wsclient.send(on_connected_packet)
				on_connected_packet = null
		elif state == WebSocketPeer.STATE_CLOSED:
			conn_state = ConnState.Offline
			room_state_changed.emit(conn_state)
			
	if state == WebSocketPeer.STATE_OPEN:
		
		while wsclient.get_available_packet_count():
			var pk = wsclient.get_packet()
			_on_packet_in(pk)

func _on_packet_in(pk:PackedByteArray):
	if pk[0]==1 and pk[1]==0:
		var ori = pk[2]
		var dst = pk[3]
		var bytes = pk.slice(4,pk.size())
		room_data.emit(ori,bytes)
		return
	elif pk.size()>=3 and pk[0]==2:
		var str = pk.slice(3,pk.size()).get_string_from_utf8()
		msg_recieved.emit(pk[1],str)
		if  pk[1]==0: #Room Connecting
			var msg = pk.slice(3,pk.size()).get_string_from_utf8()
			conn_state = ConnState.RoomConnecting
			room_state_changed.emit(conn_state)
			print(playername, "> " , msg)
			return
		elif pk[1]==1 or pk[1]==2: #Cannot connect to room
			var msg = pk.slice(3,pk.size()).get_string_from_utf8()
			wsclient.close()
			conn_state = ConnState.Offline
			room_state_changed.emit(conn_state)
			print(playername,"> ", msg)
			return
		elif pk[1]==5:
			var room = pk.slice(3,pk.size()).get_string_from_utf8()
			print(playername, "> connected to room ", room)
			conn_state = ConnState.RoomConected
			room_state_changed.emit(conn_state)
			_roomname = room
			return
		elif pk[1]==111:
			var msg = pk.slice(3,pk.size()).get_string_from_utf8()
			print(playername,"> msg:", msg)
			return
	elif pk.size()>5 and pk[0]==1 and pk[1]==3:
		var _player_name : String = pk.slice(4,pk.size()).get_string_from_utf8()
		if pk[3]==1:# Player Join
			_players[pk[2]] = _player_name
			player_msg.emit(pk[2], _player_name,1)
			return
		elif pk[3]==2:# Player (self info)
			playername = _player_name
			peer_id = pk[2]
			_players[pk[2]] = _player_name
			player_msg.emit(pk[2], _player_name,2)
			return
		elif pk[3]==0:
			_players.erase(pk[2])
			if pk[2]==0:
				peer_id=-1
			player_msg.emit(pk[2], _player_name,0)
			return
	print(playername, "> unhandled package ", pk)
