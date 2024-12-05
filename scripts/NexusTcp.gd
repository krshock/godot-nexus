extends Nexus

class_name MobNexusTCP
var tcp_server : TCPServer = TCPServer.new()
var tcp_client : TcpConnection = TcpConnection.new(StreamPeerTCP.new())
var tcp_psc : PacketPeerStream = PacketPeerStream.new()
var _peer_streams : Array[TcpConnection] = [null]

var accepting_new_connections : bool = false

var client_on_connect_packet = null

class TcpConnection extends RefCounted:
	var stream_peer_tcp : StreamPeerTCP
	var packet_peer_stream : PacketPeerStream
	var _last_status : StreamPeerTCP.Status
	signal connected
	
	func _init(_stream_peer_tcp:StreamPeerTCP):
		stream_peer_tcp = _stream_peer_tcp
		packet_peer_stream = PacketPeerStream.new()
		packet_peer_stream.stream_peer = stream_peer_tcp

	
	func get_available_packet_count()->int:
		return packet_peer_stream.get_available_packet_count()

	func get_packet() ->PackedByteArray:
		return packet_peer_stream.get_packet()

	func put_packet(bytes:PackedByteArray):
		packet_peer_stream.put_packet(bytes)

	func get_status() -> StreamPeerTCP.Status:
		if stream_peer_tcp:
			return stream_peer_tcp.get_status()
		else:
			return StreamPeerTCP.Status.STATUS_NONE

	func poll():
		stream_peer_tcp.poll()
		if _last_status!=stream_peer_tcp.get_status():
			_last_status = stream_peer_tcp.get_status()
			if _last_status == StreamPeerTCP.Status.STATUS_CONNECTED:
				connected.emit()
	
	func close():
		if stream_peer_tcp:
			packet_peer_stream.stream_peer = null
			stream_peer_tcp.disconnect_from_host()
			stream_peer_tcp = null

func _ready():
	tcp_client.connected.connect(func():
		if !is_server:
			if client_on_connect_packet:
				tcp_client.put_packet(client_on_connect_packet)
				client_on_connect_packet = null
	)
	log.connect(func(msg):
		print(playername, " -> ",  str(msg))
	)
	#player_msg.connect(func(_id,_name,_status):
		#log.emit("Player_msg: " + str(_id)+ " Name="+_name+ " Status:"+str(_status))
	#)


func _process(delta):
	_poll()

func is_online() -> bool:
	return conn_state==ConnState.RoomConected

func create_room(room_id:String="1234",room_pwd:String="") -> Error:
	var l = tcp_server.listen(7777)
	if l==OK:
		is_server = true
		peer_id = 0
		_players = {0: playername}
		conn_state = ConnState.RoomConected
		room_state_changed.emit(conn_state)
		print("Room Created")
		return OK
	print("Cant Create Room")
	return ERR_CANT_OPEN


func join_room(room_id:String="1234",room_pwd:String="") -> Error:
	if OK==tcp_client.stream_peer_tcp.connect_to_host("127.0.0.1",7777):
		is_server = false
		peer_id = 1
		_players = {}
		
		var msg = {
		"room_id":room_id,
		"room_pwd" : room_pwd,
		"app_name" : _appname,
		"player_name":playername}

		conn_state = ConnState.RoomConnecting
		room_state_changed.emit(conn_state)
		
		var pk : PackedByteArray = PackedByteArray()
		pk.append(0)
		pk.append(1) #Join room
		pk.append_array(JSON.stringify(msg).to_utf8_buffer())
		
		client_on_connect_packet = pk
		print("Joining...")
		return OK
	print("Cant Join Room")
	return ERR_CANT_CONNECT


func close_room():
	tcp_server.stop()
	for peer : TcpConnection in _peer_streams:
		if peer==null:
			continue
		peer.close()

func set_join_status(status:bool):
	if is_server:
		accepting_new_connections = status

func _poll():
	if is_server:
		if accepting_new_connections:
			while tcp_server.is_connection_available():
				var cli : StreamPeerTCP = tcp_server.take_connection()
				var tcp_conn = TcpConnection.new(cli)
				var _peer_id = _peer_streams.size()
				_peer_streams.append(tcp_conn)
				print("TCP Connection Accepted: peer_id=", _peer_id)
		for idx in range(1,_peer_streams.size()):
			var cli : TcpConnection = _peer_streams[idx]
			if cli==null:
				continue
			cli.poll()
			var _status = cli.get_status()
			if _status==StreamPeerTCP.Status.STATUS_CONNECTED:
				while cli.get_available_packet_count()>0:
					var pk = cli.get_packet()
					_on_packet_in(pk, idx)
			elif _status==StreamPeerTCP.Status.STATUS_NONE:
				print(playername, " peer ", idx, " disconnected")
				cli.close()
				player_msg.emit(idx,_players[idx], 0)
				_peer_streams[idx] = null
				_players.erase(idx)
	else:
		tcp_client.poll()
		while tcp_client.get_available_packet_count()>0:
			var pk = tcp_client.get_packet()
			_on_client_packet(pk)
#func _on_new_client(conn:TcpConnection, peer_id:int):
	#if !is_server:
		#return
	#conn.put_packet(_build_msg_packet(0,0,"Ingresando a Room"))
	#conn.put_packet(_build_player_packet(peer_id,_players[peer_id],2))
	#for k in _players.keys():
		#conn.put_packet(_build_player_packet(peer_id,_players[k],1))
	#_players[peer_id] = "Player" + str(peer_id)
	#conn.put_packet(_build_msg_packet(5,0,"Room ingresado"))

func _on_client_packet(pk:PackedByteArray):
	if pk[0]==1 and pk[1]==0:
		var ori = pk[2]
		var dst = pk[3]
		var bytes = pk.slice(4,pk.size())
		room_data.emit(ori,bytes)
		return
	elif pk[0]==2:
		if pk[1]==0:
			return
		if pk[1]==1 or pk[1]==2:
			conn_state = ConnState.NoRoom
			room_state_changed.emit(conn_state)
			return
		elif pk[1]==5:
			var room = pk.slice(3,pk.size()).get_string_from_utf8()
			conn_state = ConnState.RoomConected
			room_state_changed.emit(conn_state)
			return
	elif pk[0]==1 and pk[1]==3:
		var playerid = pk[2]
		var status = pk[3]
		var _name = pk.slice(4,pk.size()).get_string_from_utf8()
		#print(playername, " playermsg: peer_id", playerid, " name:", _name, " status:",)
		if status == 1:
			_players[playerid] = _name
			player_msg.emit(playerid, _name,status)
			return
		elif status == 2:
			playername = _name
			_players[playerid] = _name
			peer_id = playerid
			player_msg.emit(playerid, _name,status)
			return
		elif status == 0:
			if _players.has(playerid):
				_players.erase(playerid)
			player_msg.emit(playerid,_name,status)
			return
	print("lost packet: _on_client_packet, peer_id=",peer_id, " packet=", pk)


func _on_packet_in(pk:PackedByteArray, _peer_id:int):
	if pk[0]==1 and pk[1]==0:
		var ori = pk[2]
		var dst = pk[3]
		var bytes = pk.slice(4,pk.size())
		room_data.emit(ori,bytes)
		return
	elif pk[0] == 0 and pk[1]==1 and pk.size()>5 and !_players.has(_peer_id):
		var json_src = pk.slice(2,pk.size()).get_string_from_utf8()
		var json = JSON.parse_string(json_src)
		if json==null:
			print("json didnt parse:")
			print(json_src)
		else:
			if _appname!=json["app_name"]:
				_send_packet_to(_build_msg_packet(2,0,"Incompatible Game"),_peer_id)
				print("appname not supported:", json["app_name"])
				return
			_send_packet_to(_build_msg_packet(0,0,"Ingresando a Room"),_peer_id)
			_send_packet_to(_build_player_packet(_peer_id, json["player_name"], 1),255)
			for k in _players.keys():
				_send_packet_to(_build_player_packet(k,_players[k],1), _peer_id)
			_send_packet_to(_build_player_packet(_peer_id, json["player_name"], 2),_peer_id)
			_send_packet_to(_build_msg_packet(5,0,"Room ingresado"),_peer_id)
			_players[_peer_id] = json["player_name"]
			player_msg.emit(_peer_id,json["player_name"], 1)
			print("player added: ", json["player_name"])
			return
	print("unread packet: _on_packet_in, peer_id=",_peer_id, " packet=", pk)
	
func _send_packet_to(packet:PackedByteArray,target_peer:int, except:int=255):
	if packet.size()==0:
		print("Empty Packet")
		print_stack()
		return
	if is_server and target_peer!=0:
		if target_peer==255:
			for idx in range(1,_peer_streams.size()):
				var conn : TcpConnection = _peer_streams[idx]
				if conn == null or idx==except: continue
				if conn.get_status()==StreamPeerTCP.Status.STATUS_CONNECTED:
					conn.put_packet(packet)
			return
		else:
			if target_peer>0 and target_peer<_peer_streams.size():
				var conn : TcpConnection = _peer_streams[target_peer]
				if conn == null: return
				if conn.get_status()==StreamPeerTCP.Status.STATUS_CONNECTED:
					conn.put_packet(packet)
					return
	elif !is_server and target_peer==0:
		if tcp_client.get_status()==StreamPeerTCP.Status.STATUS_CONNECTED:
			tcp_client.put_packet(packet)
			return
	print(playername, " Packet not sent, dst:", target_peer)
	print(packet)
	print_stack()
	

func send_room_packet(bytes:PackedByteArray, target_peer:int,except:int=255):
	if bytes.size()==0 or conn_state!=ConnState.RoomConected:
		pass
	elif is_server and target_peer!=0:
		if target_peer==255:
			for idx in range(1,_peer_streams.size()):
				var conn : TcpConnection = _peer_streams[idx]
				if conn == null or idx==except: continue
				if conn.get_status()==StreamPeerTCP.Status.STATUS_CONNECTED:
					conn.put_packet(_build_room_packet(0,idx,bytes))
			return
		else:
			if target_peer>=1 and target_peer<_peer_streams.size():
				var conn : TcpConnection = _peer_streams[target_peer]
				if conn == null: return
				if conn.get_status()==StreamPeerTCP.Status.STATUS_CONNECTED:
					conn.put_packet(_build_room_packet(0,target_peer,bytes))
					return
	elif !is_server and target_peer==0:
		if tcp_client.get_status()==StreamPeerTCP.Status.STATUS_CONNECTED:
			var pk = _build_room_packet(peer_id,target_peer,bytes)
			#print(playername, " client_pk=", pk)
			tcp_client.put_packet(pk)
			return
	print("Packet not sent, ori:", target_peer)
	print(bytes)

func _build_msg_packet(cmd:int, msgid:int, msg:String):
	var pk = PackedByteArray([2,cmd,msgid])
	pk.append_array(msg.to_utf8_buffer())
	return pk

func _build_player_packet(playerid:int,_name:String,status:int):
	var pk = PackedByteArray([1,3,playerid,status])
	pk.append_array(_name.to_utf8_buffer())
	return pk

func _build_room_packet(from:int, to:int, packet:PackedByteArray) -> PackedByteArray:
	var p = PackedByteArray([1,0,from,to])
	p.append_array(packet)
	return p
