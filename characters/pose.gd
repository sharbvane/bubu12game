extends RefCounted
## Shared sockets and attack phases: presentation and authoritative projectile
## origins use the same math. Facing never changes the foot pivot.
const DB=preload("res://scripts/catalog.gd")
const FOOT_OFFSET=Vector2(0,22)

static func attack_duration(weapon: String, speed: float) -> float:
    var timing: Dictionary=DB.ATTACK_MOTION.get(weapon,{"windup":0.1,"recover":0.16,"kick":3})
    return (timing.windup+timing.recover)/speed

static func hand_socket(slot: String) -> Vector2:
    return Vector2(-19,-19) if slot=="offhand" else Vector2(19,-19)

static func hand_pose(p: Dictionary, slot: String, action: Dictionary={}) -> Dictionary:
    var socket=hand_socket(slot)
    var angle=-0.65 if slot=="hand" else -2.5
    if not action.is_empty():
        angle=Vector2(action.direction.x*p.face,action.direction.y).angle()
        var elapsed: float=action.time
        var windup: float=action.hit_at
        if DB.WEAPONS[action.weapon].kind=="melee":
            if elapsed<windup: angle-=1.35*(1-pow(elapsed/windup,2))
            else: angle+=lerpf(0.0,1.3,clampf((elapsed-windup)/(action.duration-windup),0,1))
        else:
            var kick=maxf(0,1-(elapsed-windup)/maxf(0.01,action.duration-windup)) if elapsed>=windup else 0.0
            socket-=Vector2.from_angle(angle)*DB.ATTACK_MOTION.get(action.weapon,{"kick":3}).kick*kick
    return {"position":socket,"angle":angle}

static func muzzle(p: Dictionary, slot: String, action: Dictionary) -> Vector2:
    var hand=hand_pose(p,slot,action)
    var local: Vector2=hand.position+Vector2.from_angle(hand.angle)*36
    return p.pos+FOOT_OFFSET+Vector2(local.x*p.face,local.y)

static func aim_from_hand(p: Dictionary, slot: String, target: Vector2) -> Vector2:
    var socket=hand_socket(slot)
    var origin: Vector2=p.pos+FOOT_OFFSET+Vector2(socket.x*p.face,socket.y)
    return (target-origin).normalized()

static func animation_state(p: Dictionary, won: bool=false) -> String:
    if p.down: return "down"
    if won: return "victory"
    if p.get("rescuing",false): return "rescue"
    if p.hurt>0: return "hurt"
    if p.get("dodge_time",0.0)>0: return "dodge"
    if p.get("build_time",0.0)>0: return "build"
    if p.get("item_time",0.0)>0: return "item"
    if p.get("skill_time",0.0)>0: return "skill"
    for action in p.get("actions",{}).values():
        if DB.WEAPONS[action.weapon].kind=="melee": return "melee"
    if not p.get("actions",{}).is_empty(): return "ranged"
    return "move" if p.moving else "idle"
