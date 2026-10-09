extends SceneTree
const Discovery=preload("res://multiplayer/discovery.gd")
var browser=Discovery.new()
var seconds=0.0
var seen: Dictionary={}

func _initialize():
    var d=Discovery.new()
    var data={"app":Discovery.APP,"type":"room","id":"unit","name":"测试花园","version":Discovery.VERSION,"protocol":Discovery.PROTOCOL,"status":"open","players":1,"port":28712}
    assert(d.accept_advert(data,"192.168.1.2")); assert(d.rooms.unit.joinable)
    data.players=2; data.status="full"
    assert(d.accept_advert(data,"192.168.1.2")); assert(not d.rooms.unit.joinable)
    data.status="playing"; d.accept_advert(data,"192.168.1.2"); assert(Discovery.status_label(d.rooms.unit)=="正在冒险")
    data.status="open"; data.players=1; data.version="0.1.0"
    d.accept_advert(data,"192.168.1.2"); assert(not d.rooms.unit.compatible and not d.rooms.unit.joinable)
    data.players="bad"; assert(not d.accept_advert(data,"192.168.1.2"))
    data.players=INF; assert(not d.accept_advert(data,"192.168.1.2"))
    d.elapsed=6; d.expire_rooms(); assert(d.rooms.unit.status=="closed")
    d.elapsed=14; d.expire_rooms(); assert(d.rooms.is_empty())
    print("DISCOVERY_VALIDATION_AND_EXPIRY_PASS")
    assert(browser.start(false)==OK)

func _process(dt: float) -> bool:
    seconds+=dt; browser.update(dt)
    for room in browser.rooms.values():
        if not seen.has(room.status): print("DISCOVERY_STATUS ",room.status)
        seen[room.status]=true
    if seconds>28:
        var success=seen.has("open") and seen.has("full") and seen.has("playing") and seen.has("closed")
        print("DISCOVERY_NETWORK_STATES_PASS" if success else "DISCOVERY_MISSING_STATES "+str(seen))
        browser.stop(); quit(0 if success else 2)
    return false
