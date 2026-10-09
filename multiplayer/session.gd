extends Node
const Simulation = preload("res://scripts/simulation.gd")
const Discovery = preload("res://multiplayer/discovery.gd")
const PORT = 28712
const PROTOCOL = Discovery.PROTOCOL
const SAVE_PATH="user://garden_checkpoint_v1_4.dat"
const SAVE_VERSION=1
var discovery=Discovery.new()
var room_id=""
var model = Simulation.new()
var mode = "solo"
var message = ""
var selected = "yier"
var send_clock = 0.0
var received_states = 0
var last_received = 0.0
var lobby_age = 0.0
var action_times: Dictionary = {}
var snapshot_sequence=0
var incoming_sequence=-1
var applied_sequence=-1
var incoming_size=0
var incoming_parts: Array=[]
var max_snapshot_bytes=0
var cosmetics: Dictionary={}
var last_saved_round=0
var pending_guest: Dictionary={}

func _ready():
    var config=ConfigFile.new()
    if config.load("user://appearance.cfg")==OK: cosmetics=config.get_value("appearance","characters",{})
    multiplayer.connected_to_server.connect(_connected)
    multiplayer.connection_failed.connect(_failed)
    multiplayer.server_disconnected.connect(_lost_host)
    multiplayer.peer_disconnected.connect(_peer_left)

func local_id() -> int:
    return multiplayer.get_unique_id() if mode!="solo" and multiplayer.has_multiplayer_peer() else 1

func authority() -> bool:
    return mode!="client"

func close():
    discovery.stop()
    mode="solo"
    if multiplayer.has_multiplayer_peer(): multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer=null
    received_states=0; send_clock=0; lobby_age=0
    action_times.clear()
    snapshot_sequence=0; incoming_sequence=-1; applied_sequence=-1; incoming_parts.clear()
    pending_guest.clear(); last_saved_round=0

func read_save() -> Dictionary:
    if not FileAccess.file_exists(SAVE_PATH): return {}
    var f=FileAccess.open(SAVE_PATH,FileAccess.READ)
    if f==null: return {}
    var saved=f.get_var(false)
    if not saved is Dictionary or saved.get("version",0)!=SAVE_VERSION: return {}
    var state=saved.get("state",{})
    if not state is Dictionary or not state.has("players") or not state.has("core"): return {}
    if int(state.get("checkpoint_round",0))<2 or int(state.get("checkpoint_round",0))>4: return {}
    return state

func has_save() -> bool:
    var state=read_save()
    return not state.is_empty() and int(state.checkpoint_round)<=3

func resume_solo() -> bool:
    var state=read_save()
    if state.is_empty() or int(state.checkpoint_round)>3: return false
    close(); model=Simulation.new(); model.restore(state)
    for id in model.players.keys():
        if id!=1: model.players.erase(id)
    model.phase="camp"; model.notice="存档已读取 · %d-0 特殊补给" % model.round_no
    last_saved_round=model.checkpoint_round
    return true

func host_saved() -> Error:
    var state=read_save()
    if state.is_empty() or int(state.checkpoint_round)>3: return ERR_FILE_NOT_FOUND
    var character: String=state.players[1].character
    var err=host(character)
    if err!=OK: return err
    model.restore(state)
    for id in model.players.keys():
        if id!=1:
            pending_guest=model.players[id].duplicate(true)
            model.players.erase(id); model.inputs.erase(id); model.input_age.erase(id)
            break
    model.phase="lobby"; model.notice="读取 %d-0 存档，等待伙伴加入" % model.round_no
    last_saved_round=model.checkpoint_round
    return OK

func save_checkpoint():
    if not authority() or model.checkpoint_round<=last_saved_round: return
    if model.checkpoint_round<2 or model.checkpoint_round>4: return
    var f=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if f==null: message="自动存档失败：无法写入设备存储"; return
    f.store_var({"version":SAVE_VERSION,"state":model.snapshot()})
    f.close(); last_saved_round=model.checkpoint_round

func solo(character: String):
    close(); model=Simulation.new(); model.add_player(1,character); apply_cosmetics(1,cosmetics.get(character,{})); model.begin_run()

func host(character: String) -> Error:
    close()
    var peer=ENetMultiplayerPeer.new()
    var err=peer.create_server(PORT,4,3)
    if err!=OK: message="创建失败，端口可能正在被另一个房间使用。"; return err
    multiplayer.multiplayer_peer=peer
    mode="host"; model=Simulation.new(); model.add_player(1,character)
    apply_cosmetics(1,cosmetics.get(character,{}))
    room_id="%x-%x" % [Time.get_ticks_usec(),randi()]
    err=discovery.start(true)
    if err!=OK: message=discovery.error; close(); model.phase="menu"; return err
    message="房间已开启，等待另一只小熊加入。"
    return OK

func browse():
    close(); model=Simulation.new(); model.phase="join"
    var err=discovery.start(false)
    message="正在寻找同一 Wi-Fi 下的小花园…" if err==OK else discovery.error

func join_discovered(id: String, character: String) -> Error:
    if not discovery.rooms.has(id) or not discovery.rooms[id].joinable:
        message="房间状态已改变，请选择可加入的房间。"; return ERR_UNAVAILABLE
    return join_room(discovery.rooms[id].address,character,int(discovery.rooms[id].port))

func room_metadata() -> Dictionary:
    var count=model.players.size()
    var state="open" if model.phase=="lobby" and count<2 else "full" if model.phase=="lobby" else "playing"
    return {"app":Discovery.APP,"type":"room","id":room_id,"name":model.DB.CHARACTERS[model.players[1].character].name+"的小花园", "version":Discovery.VERSION,"protocol":PROTOCOL,"status":state,"players":count,"port":PORT}

func join_room(address: String, character: String, port: int=PORT) -> Error:
    close()
    address=address.strip_edges()
    if not address.is_valid_ip_address(): message="房间地址已失效，请刷新房间列表。"; return ERR_INVALID_PARAMETER
    var peer=ENetMultiplayerPeer.new()
    var err=peer.create_client(address,port,3)
    if err!=OK: message="连接未能开始，请检查地址与网络。"; return err
    multiplayer.multiplayer_peer=peer
    mode="client"; selected=character; model=Simulation.new(); model.phase="lobby"
    message="正在连接房主…"; last_received=Time.get_ticks_msec()/1000.0
    return OK

func _connected():
    register_player.rpc_id(1,PROTOCOL,selected,cosmetics.get(selected,{}))
    message="已连接，等待房主开始。"

func _failed():
    browse()
    message="连接失败或房间已关闭。请确认连接同一 Wi-Fi，稍后点选房间重试。"

func _lost_host():
    if mode!="client": return
    message="与房主的连接已断开。请回主菜单重新加入。"
    close(); model.result=message; model.phase="result"; model.revision+=1

func _peer_left(id: int):
    if mode!="host" or not model.players.has(id): return
    if model.phase=="result": return
    if model.phase=="lobby":
        model.players.erase(id); model.inputs.erase(id); model.input_age.erase(id)
        message="伙伴离开了，等待重新加入。"
    else: model.result="伙伴已断开连接，本局结束。"; model.phase="result"
    model.revision+=1

@rpc("any_peer", "call_remote", "reliable", 0)
func register_player(protocol: int, character: String, appearance: Dictionary={}):
    if mode!="host": return
    var id=multiplayer.get_remote_sender_id()
    if model.players.has(id): return
    if protocol!=PROTOCOL or model.phase!="lobby" or model.players.size()>=2:
        reject_join.rpc_id(id,"版本不兼容" if protocol!=PROTOCOL else "房间已经开局" if model.phase!="lobby" else "房间已满")
        return
    if not model.DB.CHARACTERS.has(character): return
    if character==model.players[1].character: character="bubu" if character=="yier" else "yier"
    if pending_guest.is_empty():
        model.add_player(id,character)
        apply_cosmetics(id,appearance)
    else:
        var old_id: int=pending_guest.id
        pending_guest.id=id; pending_guest.ready=false
        model.players[id]=pending_guest; model.inputs[id]=Vector2.ZERO; model.input_age[id]=0
        for b in model.buildings:
            if b.owner==old_id: b.owner=id
        pending_guest={}
    message="伙伴已加入。两只小熊都准备好了！"

@rpc("authority", "call_remote", "reliable", 0)
func reject_join(reason: String):
    browse(); message=reason+"，请选择其他房间。"

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func receive_input(direction: Vector2):
    if mode=="host": model.set_input(multiplayer.get_remote_sender_id(),direction)

@rpc("any_peer", "call_remote", "reliable", 0)
func receive_action(action: String, key: String):
    if mode!="host": return
    var id=multiplayer.get_remote_sender_id()
    if not model.players.has(id) or action.length()>20 or key.length()>32: return
    var now=Time.get_ticks_msec()
    if now-int(action_times.get(id,0))<90: return
    action_times[id]=now
    apply_action(id,action,key)

func act(action: String, key: String=""):
    if mode=="client":
        if multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED: receive_action.rpc_id(1,action,key)
    else: apply_action(local_id(),action,key)

func apply_action(id: int, action: String, key: String):
    match action:
        "skill": model.use_skill(id)
        "upgrade": model.choose_upgrade(id,key)
        "buy": model.buy(id,key)
        "reroll": model.reroll(id)
        "equip":
            var parts=key.split(":")
            if parts.size()==2: model.equip(id,parts[0],parts[1])
        "gear":
            var parts=key.split(":")
            if parts.size()==2: model.equip_gear(id,parts[0],parts[1])
        "core_growth": model.choose_core(id,key)
        "skill_growth": model.choose_skill_growth(id,key)
        "place_core": model.place_core(id)
        "dash": model.dash_player(id)
        "item":
            if key.is_valid_int(): model.use_item(id,int(key))
        "discard":
            if model.phase in ["camp","deploy"] and model.players.has(id) and key.is_valid_int():
                var p: Dictionary=model.players[id]
                var index=int(key)
                if not p.ready and index>=0 and index<p.items.size(): p.items.remove_at(index); p.ui_revision+=1
        "ready": model.ready_player(id)
        "pause":
            if model.phase in ["battle","boss_outro","deploy","camp"]: model.resume_phase=model.phase; model.phase="paused"; model.revision+=1
            elif model.phase=="paused": model.phase=model.resume_phase; model.revision+=1
        "start":
            if id==1 and model.phase=="lobby" and model.players.size()==2:
                if model.checkpoint_round>=2: model.phase="camp"; model.revision+=1
                else: model.begin_run()

func apply_cosmetics(id: int, appearance: Dictionary):
    if not model.players.has(id): return
    var p: Dictionary=model.players[id]
    var key=appearance.get("outfit","plain")
    p.outfit=key if key is String and model.DB.COSTUMES.has(key) else "plain"

func save_cosmetics(character: String, appearance: Dictionary):
    cosmetics[character]=appearance.duplicate()
    var config=ConfigFile.new(); config.set_value("appearance","characters",cosmetics); config.save("user://appearance.cfg")

func build(key: String, at: Vector2):
    if mode=="client":
        if multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED: receive_build.rpc_id(1,key,at)
    else: model.build(local_id(),key,at)

@rpc("any_peer","call_remote","reliable",0)
func receive_build(key: String, at: Vector2):
    if mode=="host" and key.length()<24 and at.is_finite(): model.build(multiplayer.get_remote_sender_id(),key,at)

func tick(dt: float, direction: Vector2):
    discovery.update(dt,room_metadata() if mode=="host" else {})
    send_clock+=dt
    if authority():
        model.set_input(local_id(),direction)
        model.step(dt)
        save_checkpoint()
    if mode=="solo": return
    if send_clock>=0.0667:
        send_clock=0
        if mode=="host" and multiplayer.get_peers().size()>0:
            var raw=var_to_bytes(model.snapshot())
            var packet=raw.compress(FileAccess.COMPRESSION_ZSTD)
            snapshot_sequence+=1
            max_snapshot_bytes=maxi(max_snapshot_bytes,packet.size())
            var count=ceili(packet.size()/1000.0)
            for id in model.players:
                if id!=1 and id in multiplayer.get_peers():
                    for index in range(count):
                        receive_state_chunk.rpc_id(id,snapshot_sequence,index,count,packet.slice(index*1000,(index+1)*1000),raw.size())
        elif mode=="client" and multiplayer.multiplayer_peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
            receive_input.rpc_id(1,direction)
    if mode=="client" and Time.get_ticks_msec()/1000.0-last_received>15:
        _lost_host()

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func receive_state_chunk(sequence: int, index: int, count: int, packet: PackedByteArray, raw_size: int):
    if mode!="client" or sequence<=applied_sequence or sequence<incoming_sequence: return
    if count<1 or count>128 or index<0 or index>=count or packet.is_empty() or packet.size()>1000 or raw_size<=0 or raw_size>2000000: return
    if sequence!=incoming_sequence:
        incoming_sequence=sequence; incoming_size=raw_size
        incoming_parts.clear(); incoming_parts.resize(count)
    if incoming_parts.size()!=count or incoming_size!=raw_size: return
    incoming_parts[index]=packet
    for part in incoming_parts:
        if part==null: return
    var complete=PackedByteArray()
    for part in incoming_parts: complete.append_array(part)
    applied_sequence=sequence; incoming_parts.clear()
    receive_state(complete,raw_size)

func receive_state(packet: PackedByteArray, raw_size: int):
    if mode!="client" or raw_size<=0 or raw_size>2000000 or packet.size()>200000: return
    var raw=packet.decompress(raw_size,FileAccess.COMPRESSION_ZSTD)
    if raw.is_empty(): return
    var state=bytes_to_var(raw)
    if not state is Dictionary or not state.has("players"): return
    model.restore(state)
    received_states+=1
    last_received=Time.get_ticks_msec()/1000.0

func _exit_tree():
    discovery.stop()
