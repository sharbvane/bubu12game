extends RefCounted
## Broadcast queries, unicast replies. Browsers use ephemeral ports so several
## clients on one computer work without sharing a UDP listening port.
const APP = "bubu-garden"
const PORT = 28713
const VERSION = "1.5.0"
const PROTOCOL = 6
const EXPIRE = 4.5
var socket: PacketPeerUDP
var hosting = false
var rooms: Dictionary = {}
var subscribers: Dictionary = {}
var advert: Dictionary = {}
var elapsed = 0.0
var pulse = 0.0
var revision = 0
var error = ""
var targets: Array[String] = []

func start(host: bool) -> Error:
    stop()
    hosting=host; elapsed=0; pulse=1
    socket=PacketPeerUDP.new()
    var result=socket.bind(PORT if host else 0,"0.0.0.0")
    if result!=OK:
        socket=null
        error="无法开启房间发现，请检查是否已有房间运行。"
        return result
    socket.set_broadcast_enabled(true)
    targets=["255.255.255.255","127.0.0.1"]
    # Limited broadcast works without knowing the mask; /24 directed broadcasts
    # additionally cover common Wi-Fi adapters when a VPN changes the default route.
    for ip in IP.get_local_addresses():
        if not ip.contains(":") and not ip.begins_with("127.") and not ip.begins_with("169.254."):
            var parts=ip.split(".")
            if parts.size()==4:
                var destination="%s.%s.%s.255" % [parts[0],parts[1],parts[2]]
                if not destination in targets: targets.append(destination)
    error=""
    return OK

func stop():
    if socket!=null:
        if hosting and not advert.is_empty():
            advert.status="closed"
            for client in subscribers.values(): send(advert,client.ip,client.port)
        socket.close(); socket=null
    rooms.clear(); subscribers.clear(); advert.clear(); revision+=1

func send(data: Dictionary, ip: String, port: int):
    socket.set_dest_address(ip,port)
    socket.put_packet(JSON.stringify(data).to_utf8_buffer())

func update(dt: float, metadata: Dictionary={}):
    if socket==null: return
    elapsed+=dt; pulse+=dt
    if hosting:
        var changed=advert!=metadata
        advert=metadata.duplicate()
        if changed:
            for client in subscribers.values(): send(advert,client.ip,client.port)
    if pulse>=1.0:
        pulse=0
        if not hosting:
            for ip in targets: send({"app":APP,"type":"probe"},ip,PORT)
        for key in subscribers.keys():
            if elapsed-subscribers[key].seen>8: subscribers.erase(key)
    # Bound work and validate every untrusted datagram before touching game state.
    for _i in range(mini(socket.get_available_packet_count(),64)):
        var packet=socket.get_packet()
        var ip=socket.get_packet_ip()
        var port=socket.get_packet_port()
        if packet.size()>2048: continue
        var parser=JSON.new()
        if parser.parse(packet.get_string_from_utf8())!=OK: continue
        var data=parser.data
        if not data is Dictionary or data.get("app")!=APP: continue
        if hosting:
            if data.get("type")!="probe" or advert.is_empty(): continue
            var key=ip+":"+str(port)
            if subscribers.has(key) and elapsed-subscribers[key].seen<0.25: continue
            if not subscribers.has(key) and subscribers.size()>=32: continue
            subscribers[key]={"ip":ip,"port":port,"seen":elapsed}
            send(advert,ip,port)
        else: accept_advert(data,ip)
    expire_rooms()

func accept_advert(data: Dictionary, ip: String) -> bool:
    if data.get("app")!=APP or data.get("type")!="room" or not ip.is_valid_ip_address(): return false
    for key in ["id","name","version","status"]:
        if not data.get(key) is String or data[key].length()>64 or data[key].is_empty(): return false
    if not data.status in ["open","full","playing","closed"]: return false
    for key in ["protocol","players","port"]:
        if not (data.get(key) is float or data.get(key) is int): return false
        if not is_finite(float(data[key])) or float(data[key])!=floor(float(data[key])): return false
    if data.players<0 or data.players>2 or data.port<1024 or data.port>65535 or data.protocol<1 or data.protocol>10000: return false
    var key: String=data.id
    if not rooms.has(key) and rooms.size()>=32: return false
    var entry=data.duplicate()
    entry.address=ip; entry.seen=elapsed
    entry.compatible=int(data.protocol)==PROTOCOL and data.version==VERSION
    entry.joinable=entry.compatible and data.status=="open" and data.players<2
    if rooms.has(key):
        # Do not replace a working LAN address with our loopback test response.
        if ip.begins_with("127.") and not rooms[key].address.begins_with("127."): entry.address=rooms[key].address
        var old=rooms[key].duplicate(); old.erase("seen")
        var fresh=entry.duplicate(); fresh.erase("seen")
        if old!=fresh: revision+=1
    else: revision+=1
    rooms[key]=entry
    return true

func expire_rooms():
    for key in rooms.keys():
        var r: Dictionary=rooms[key]
        if elapsed-r.seen>EXPIRE and r.status!="closed":
            r.status="closed"; r.joinable=false; revision+=1
        if elapsed-r.seen>EXPIRE+8:
            rooms.erase(key); revision+=1

static func status_label(room: Dictionary) -> String:
    if room.status=="closed": return "房间已关闭"
    if not room.compatible: return "版本不兼容 · "+room.version
    if room.status=="playing": return "正在冒险"
    if room.status=="full": return "房间已满"
    return "等待伙伴 · 点击加入"
