extends Node

class_name NetEntity
@export var net_id : int = -1
@export var net_root : NetRoot
var peer_id : int = -1
var _disable_autoregister: bool = false
var _disable_on_sync = false
var components : Dictionary = {}
var _component_id : int = 0
func _ready():
	if Engine.is_editor_hint():
		return
	if net_root==null:
		if get_parent() is NetRoot:
			net_root = get_parent()
		elif owner is NetRoot:
			net_root = owner
		if get_parent() is NetEntity:
			if get_parent().net_id < NetRoot.MAX_STATIC_NID and get_parent().net_root!=null:
				net_root = get_parent().net_root
		
	assert(net_root,"Node has no NetEntity parent")
	if !_disable_autoregister:
		net_root.register_entity(self)
		#print(name, " netid=", net_id)

func is_input_entity():
	return net_root and net_root.input_entity == self
	
func is_host():
	return net_root and net_root.is_host()

func register_component(net_cmp:Node, _component_id:int):
	assert(!components.has(_component_id),"register_component: already taken component id: " + str(net_cmp.get_path()))
	components[_component_id] = net_cmp
	net_cmp.tree_exiting.connect(func():
		unregister_component(_component_id)
	)

func unregister_component(_component_id:int):
	assert(components.has(_component_id),"unregister_component: component not registered: ")
	components.erase(_component_id)
	

func logger(msg:String):
	if net_root:
		net_root.log.emit(msg)

func get_sync_data():
	return [net_id,name, peer_id]

var _net_sync_initialized : bool =false
func set_sync_data(arr):
	if _net_sync_initialized:
		return
	net_id = arr[0]
	if name!=arr[1]:
		name = arr[1]
	peer_id = arr[2]

func send_net_msg(peer_target:int, msgid:int, param, except_peer:int=255):
	if net_root and net_root.is_online():
		var bytes = var_to_bytes(param)
		net_root.send_entity_packet(peer_target,net_id,msgid,bytes, except_peer)

func broadcast_net_msg(msgid:int, param, except_peer:int=255):
	if net_root and net_root.is_online():
		var peer_target : int = 255 if is_host() else 0
		var bytes = var_to_bytes(param)
		net_root.send_entity_packet(peer_target,net_id,msgid,bytes, except_peer)


func send_component_msg(cid:int, msgid:int, param, except_peer=255):
	if net_root and net_root.is_online():
		var target_peer : int = 255 if is_host() else 0
		var bytes = var_to_bytes(param)
		net_root.send_component_packet(target_peer,net_id,cid,msgid,bytes,except_peer)

func broadcast_component_msg(cid:int,msgid:int, param, except_peer:int=255):
	if net_root and net_root.is_online():
		var peer_target : int = 255 if is_host() else 0
		var bytes : PackedByteArray = []
		if param!=null:
			bytes = var_to_bytes(param)
		net_root.send_component_packet(peer_target,net_id,cid,msgid,bytes, except_peer)

func _recieve_component_packet(origin_peer:int, cid:int, msgid:int, params):
	if components.has(cid):
		var component : Node = components[cid]
		if component.has_method("_recieve_packet"):
			component._recieve_packet(origin_peer,msgid, params)

func _recieve_packet(origin_peer:int, msgid:int, params):
	pass
