extends Node

class_name NetRoot

@export var nexus : Nexus

const MAX_STATIC_NID = 20

var entities : Array[NetEntity]= [] 

signal log(msg)

signal room_state_changed(room_state)
signal game_stage_changed(state)
var game_stage : int = 0

var playerid : int = -1
var playername : String = "Singleplayer"
var _is_host : bool = false
var _is_online : bool = true
var _players : Dictionary = {}

var input_entity : NetEntity



signal player_status(_id,_name,_status)

var _initialized : bool = false
func _enter_tree():
	entities.resize(128)
	if nexus==null:
		nexus = MobNexus
	log.connect(func(sss):
		print(playername, " log: ", sss)
	)
	if nexus and nexus.peer_id!=-1:
		_is_host = nexus.is_server
		playerid = nexus.peer_id
		playername = nexus.playername
		print("playerid: ", playerid)
		nexus.room_data.connect(func(orip,data):
			if !_on_room_data(orip, data):
				log.emit("Packet not processed: " + str(data))
		)
		nexus.room_state_changed.connect(func(st):
			log.emit("Roomstate: ", Nexus.ConnState.keys()[st])
			print(playername, "> roomstate:",  Nexus.ConnState.keys()[st])
			room_state_changed.emit(st)
		)
		tree_exiting.connect(func():
			if nexus:
				nexus.close_room()
		)
		_players = nexus._players.duplicate()
		print(playername, " playerlist: ", _players)
		nexus.player_msg.connect(func(id, pname, status):
			log.emit("player_msg: " + str(id) + " name:"+pname+ " status="+str(status))
			if status==2:
				playerid = id
				playername = pname
				_players[id] = pname
			elif status==1:
				_players[id] = pname
			elif status==0 and id!=0:
				_players.erase(id)
			player_status.emit(id,pname,status)
		)
		nexus.set_join_status(true)
		if !is_host():
			nexus.send_room_packet(PackedByteArray([NetMsg.EnterRoom,0]),0)
	else:
		_is_host = true
		playerid = 0
		_players = {}
		_players[0] = playername
	assert(playerid!=-1,"PLayerid is not initialized at the start of the scene")
	_sync_corroutine()

func _sync_corroutine():
	if !is_host():
		return
	while is_instance_valid(self):
		for idx in range(MAX_STATIC_NID, entities.size()):
			if is_instance_valid(entities[idx]):
				if nexus:
					var pk = PackedByteArray([NetMsg.EntitySync,idx])
					pk.append_array(var_to_bytes(entities[idx].get_sync_data()))
					nexus.send_room_packet(pk,255)
		await get_tree().create_timer(1.0).timeout

func _on_sync(entityid:int,data):
	if is_instance_valid(entities[entityid]) and !entities[entityid]._disable_on_sync:
		entities[entityid].set_sync_data(data)

enum NetMsg {
	EnterRoom,
	EntityMsg,
	EntitySync,
	GamestateSet,
	CmdSpawn,
	ComponentMsg,
	DestroyEntity
}
func _on_room_data(ori_peer: int, bytes: PackedByteArray) -> bool:
	#log.emit("Romm Data: source="+str(ori_peer))
	#print(playername, " _on_room_data ", bytes)
	if bytes[0]==NetMsg.EntityMsg: #Entity Msg
		if bytes[1] >= entities.size() or !is_instance_valid(entities[bytes[1]]):
			return false
		var ins = entities[bytes[1]]
		var param_bytes : PackedByteArray = bytes.slice(3,bytes.size())
		var param = null
		if param_bytes.size()>0:
			param = bytes_to_var(param_bytes)
		ins._recieve_packet(ori_peer, bytes[2], param)
		return true
	elif bytes[0]==NetMsg.ComponentMsg:
		if bytes[1] >= entities.size() or !is_instance_valid(entities[bytes[1]]):
			return false
		var ins : NetEntity = entities[bytes[1]]
		var cid = bytes[2]
		if !ins.components.has(cid) or is_instance_valid(ins.components[cid]):
			return false
		var nc : NetComponent = ins.components[cid]
		var msgid = bytes[3]
		var param_bytes : PackedByteArray = bytes.slice(4,bytes.size())
		var param = null
		if param_bytes.size()>0:
			param = bytes_to_var(param_bytes)
		nc._recieve_packet(ori_peer, msgid,param)
		return true
	elif bytes[0]==NetMsg.DestroyEntity and !is_host():
		destroy_entity(bytes[1])
		return true
	elif bytes[0]==NetMsg.EntitySync and !is_host():
		var params = bytes_to_var(bytes.slice(2,bytes.size()))
		_on_sync(bytes[1], params)
		return true
	elif bytes[0]==NetMsg.CmdSpawn and !is_host():
		var params = bytes_to_var(bytes.slice(1,bytes.size()))
		cmd_spawn(params[0], params[1], params[2])
		return true
	elif ori_peer==0 and bytes[0]==NetMsg.GamestateSet:
		game_stage = bytes[1]
		game_stage_changed.emit(game_stage)
		return true
	elif bytes[0]==NetMsg.EnterRoom and is_host():
		_send_sync_room_to_peer(ori_peer)
		return true
	return false

func _send_sync_room_to_peer(peerid:int):
	for idx in range(MAX_STATIC_NID, entities.size()):
		if is_instance_valid(entities[idx]):
			var e = entities[idx]
			cmd_spawn(str(get_path_to(e.get_parent())),e.scene_file_path, e.get_sync_data(),peerid)
			

func set_game_stage(_game_stage):
	game_stage = _game_stage
	game_stage_changed.emit(_game_stage)
	if is_host() and is_online():
		nexus.send_room_packet([NetMsg.GamestateSet,_game_stage],255)


func is_online():
	return _is_online and nexus and nexus.conn_state == Nexus.ConnState.RoomConected


## Register a scene entity in the NetRoot repository
func register_entity(entity:NetEntity) -> bool:
	assert(entity)
	var do_spawn : bool = false
	if entity.net_id!=-1:
		assert(entities[entity.net_id] == null,"reregistering net_id, id already in use")
		if entity.net_id >= MAX_STATIC_NID:
			if is_host():
				assert(false, "dynamic net_id is not allowed pre-initiaalization")
				return false
	else:
		var nid = _empty_entity_slot()
		if nid==null:
			assert(false,"Entity DB is full full")
			return false
		if entities[nid]!=null:
			assert(false, "Entity net_id already taken")
			return false
		entity.net_id = nid
		do_spawn = true
	assert(entities[entity.net_id] == null)
	entities[entity.net_id] = entity
	entity.tree_exiting.connect(func():
		unregister_entity(entity)
	)
	if is_host() && do_spawn:
		#log.emit(entity.name)
		#log.emit(get_path_to(entity.get_parent()))
		#log.emit(entity.scene_file_path)
		queue_net_spawn(entity)
	return true

func get_room_name() -> String:
	if !nexus:
		return "room"
	else:
		return nexus._roomname

func set_join_status(can:bool):
	if nexus:
		nexus.set_join_status(can)
func queue_net_spawn(obj:NetEntity):
	await get_tree().process_frame
	cmd_spawn(str(get_path_to(obj.get_parent())),obj.scene_file_path, obj.get_sync_data())

func cmd_spawn(spawn_path:String,res_path:String,sync_data, peer_id:int=255):
	if is_host() and nexus:
		var pk = PackedByteArray([NetMsg.CmdSpawn])
		pk.append_array(var_to_bytes([spawn_path,res_path,sync_data]))
		nexus.send_room_packet(pk,peer_id)
	else:
		if entities[sync_data[0][0]]!=null:
			return
		var parent_node = get_node_or_null(spawn_path)
		if parent_node:
			var ps = load(res_path).instantiate()
			if ps is NetEntity:
				ps._disable_autoregister = true
				ps.net_root = self
				ps.set_sync_data(sync_data)
				parent_node.add_child(ps)
				register_entity(ps)
			

func is_host():
	return _is_host


## Networking functionality: send room packet to a client in the same room
func send_entity_packet(peer_tgt:int,netid:int,msgid:int,bytes:PackedByteArray, except_peer:int=255):
	if netid==-1: return		
	if nexus and nexus.is_online() and peer_tgt!=playerid:
		if except_peer!=255 and nexus._players.size()<=2:#dont repeat packet to the network
			return
		var pk = PackedByteArray([NetMsg.EntityMsg,netid, msgid])
		if bytes.size()>0:
			pk.append_array(bytes)
		nexus.send_room_packet(pk,peer_tgt,except_peer)

## Networking functionality: send room packet to a client in the same room
func send_component_packet(peer_tgt:int,netid:int,cid:int, msgid:int,bytes:PackedByteArray, except_peer:int=255):
	if netid==-1: return		
	if nexus and nexus.is_online() and peer_tgt!=playerid:
		if except_peer!=255 and nexus._players.size()<=2:#dont repeat packet to the network
			return
		var pk = PackedByteArray([NetMsg.ComponentMsg,netid, cid, msgid])
		if bytes.size()>0:
			pk.append_array(bytes)
		nexus.send_room_packet(pk,peer_tgt,except_peer)

#func _send_packet_to_host(pk:PackedByteArray):
	#if nexus:
		#nexus._send_packet_to_host(pk)

func unregister_entity(entity: NetEntity):
	assert(entity)
	assert(entity.net_id!=-1,"Uninitialized net_id")
	assert(entities[entity.net_id]==entity, "Invalid net_id reference")
	entities[entity.net_id] = null
	entity.net_id = -1

func destroy_entity(netid:int):
	if netid>=MAX_STATIC_NID and netid<entities.size():
		var e = entities[netid]
		if is_instance_valid(e):
			if is_host():
				e.queue_free()
				if nexus:
					var pk = PackedByteArray([NetMsg.DestroyEntity, netid])
					nexus.send_room_packet(pk,255)
			else:
				e.queue_free()
				
func _empty_entity_slot():
	for n in range(MAX_STATIC_NID,entities.size()):
		if entities[n]==null:
			return n
	return null
