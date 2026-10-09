extends RefCounted
const DB=preload("res://scripts/catalog.gd")
const C=preload("res://scripts/garden_content.gd")
const Pose=preload("res://characters/pose.gd")
const MAX_ENEMIES=90
const MAX_SHOTS=120
const MAX_DROPS=100
const MAX_BUILDINGS=36
const GRID=64.0
var players: Dictionary={}
var enemies: Array=[]
var shots: Array=[]
var drops: Array=[]
var effects: Array=[]
var buildings: Array=[]
var zones: Array=[]
var rocks: Array=[]
var core: Dictionary={}
var phase="lobby"
var resume_phase="battle"
var round_no=1
var wave=0
var clock=0.0
var elapsed=0.0
var world_time=0.0
var kills=0
var level=1
var xp=0
var total_xp=0
var spawn_clock=0.0
var link_charge=0.0
var linked=false
var result=""
var uid=0
var revision=0
var revive_clock=10.0
var time_stop=0.0
var time_owner=0
var intel=0
var boss_defeated=false
var outro_time=0.0
var checkpoint_round=0
var notice=""
var rng=RandomNumberGenerator.new()
var inputs: Dictionary={}
var input_age: Dictionary={}

func _init(seed_value: int=0):
    if seed_value: rng.seed=seed_value
    else: rng.randomize()
    for rock in DB.OBSTACLES: rocks.append({"pos":Vector2(rock.x,rock.y),"radius":rock.z,"hp":220.0})
    core={"pos":DB.ARENA/2,"hp":950.0,"max_hp":950.0,"regen":1.0,"armor":0.0,"shield":0.0,"shield_max":0.0,"aura":0.0,"repair":0.0,"guard":0.0,"attack":0.0,"vine":0.0,"timer":0.0,"hurt":0.0,"placed":false,"carrier":0}

func next_id() -> int:
    uid+=1
    return uid

func add_player(id: int, character: String):
    if players.size()>=2 or not DB.CHARACTERS.has(character): return
    var c: Dictionary=DB.CHARACTERS[character]
    players[id]={"id":id,"character":character,"pos":DB.ARENA/2+Vector2(-50 if players.is_empty() else 50,90),"hp":c.hp,"max_hp":c.hp,"speed":c.speed,"damage":c.damage,"armor":c.armor,"crit":0.05,"attack_speed":1.0,"regen":0.0,"magnet":78.0,"build_power":1.0,"area":1.0,"cooldown_bonus":0.0,"weapons":{c.weapon:1},"equipment":{"hand":c.weapon,"offhand":""},"gear":{"head":"","body":"","feet":"","charm":""},"owned":[],"items":["heal_seed","home","bomb"],"inventory":{"fence":3,"turret":1},"timers":{},"coins":90,"pending":0,"offers":[],"stock":[],"bought":[],"ready":false,"down":false,"revive":0.0,"rescuing":false,"invuln":0.0,"skill_cd":0.0,"shield":0.0,"hurt":0.0,"attack":0.0,"face":1,"facing":"front","moving":false,"damage_dealt":0.0,"healed":0.0,"actions":{},"anim_clock":0.0,"skill_time":0.0,"dodge_time":0.0,"build_time":0.0,"item_time":0.0,"down_time":0.0,"hit_serial":0,"ui_revision":0,"core_tokens":0,"first_guard":true,"move_time":0.0,"dash_cd":0.0,"dash":0.0,"shock_cd":0.0,"familiar_cd":0.0,"mirror":0.0,"rocket":0.0,"energy":0.0,"combos":{},"item_cd":0.0,"last_direction":Vector2.RIGHT}
    players[id].outfit="plain"
    players[id].skill_power=1; players[id].skill_haste=0; players[id].skill_tokens=0
    inputs[id]=Vector2.ZERO; input_age[id]=0.0
    refresh_stock(players[id]); revision+=1

func set_input(id: int, direction: Vector2):
    if players.has(id) and direction.is_finite(): inputs[id]=direction.limit_length(1); input_age[id]=0.0

func begin_run():
    if players.is_empty(): return
    phase="deploy"; wave=0; round_no=1
    core.carrier=players.keys()[rng.randi_range(0,players.size()-1)]
    notice="1-0 无限时部署：举莓玩家在合适位置放下大甜莓后开始"
    revision+=1

func place_core(id: int) -> bool:
    if phase!="deploy" or id!=core.carrier or core.placed: return false
    core.pos=players[id].pos
    if not valid_site(core.pos,55): notice="此处有障碍或建筑，请移动后放置"; return false
    core.placed=true; core.carrier=0
    begin_wave(); return true

func begin_wave():
    if round_no>DB.ROUND_COUNT: return
    wave+=1; phase="battle"; clock=DB.WAVE_SECONDS[wave-1]; spawn_clock=1.6
    shots.clear(); enemies.clear(); zones.clear(); effects.clear()
    boss_defeated=false; core.shield=core.shield_max
    notice="第 %d-%d 波 · %s" % [round_no,wave,C.INTEL[(6+(round_no-2)*4+(wave-1)%4) if round_no>1 else intel]]
    for p in players.values():
        p.ready=false; p.first_guard=true; p.actions.clear(); p.timers.clear()
        p.hp=minf(p.max_hp,p.hp+p.max_hp*.12); p.invuln=2.0
    if wave==6:
        spawn_enemy(DB.BOSS_KINDS[round_no-1],core.pos+Vector2(0,-420))
        effect("boss_intro",core.pos+Vector2(0,-420),160,.9)
    revision+=1

func finish_round():
    for d in drops: claim_drop(d,players.values()[0])
    drops.clear()
    if round_no>=DB.ROUND_COUNT:
        checkpoint_round=DB.ROUND_COUNT+1
        finish(true); return
    round_no+=1; wave=0; intel=(round_no-1)%C.INTEL.size()
    enter_camp()
    checkpoint_round=round_no

func enter_camp():
    for d in drops: claim_drop(d,players.values()[0])
    drops.clear(); shots.clear(); enemies.clear(); zones.clear(); effects.clear()
    phase="camp"; time_stop=0; time_owner=0
    notice="第 %d-%d %s · 全员准备后继续" % [round_no,wave,"核心与技能强化" if special_supply_open() else "波后补给"]
    for p in players.values():
        if core_shop_open() and p.gear.charm=="purse": p.coins+=mini(50,int(p.coins*.1))
        p.coins+=45 if core_shop_open() else 12
        p.pending=maxi(1,p.pending); p.core_tokens=1 if special_supply_open() else 0
        p.skill_tokens=1 if special_supply_open() else 0
        p.offers=choose_random(DB.UPGRADES.keys(),3); p.bought=[]; p.ready=false
        p.down=false; p.hp=maxf(p.hp,p.max_hp*.5); p.actions.clear()
        refresh_stock(p); p.ui_revision+=1
    revision+=1

func spawn_enemy(kind: String, at: Vector2):
    if enemies.size()>=MAX_ENEMIES or not DB.ENEMIES.has(kind): return
    var d: Dictionary=DB.ENEMIES[kind]
    var hp: float=d.hp*(1+(round_no-1)*.32+(wave-1)*.08)*(1.45 if players.size()==2 else 1.0)
    if kind in DB.BOSS_KINDS: hp=d.hp*(1+(round_no-1)*.28)*(1.45 if players.size()==2 else 1.0)
    enemies.append({"id":next_id(),"kind":kind,"pos":at.clamp(Vector2(65,65),DB.ARENA-Vector2(65,65)),"hp":hp,"max_hp":hp,"speed":d.speed*(1+mini(round_no,10)*.025),"damage":d.damage*(1+(round_no-1)*.1),"radius":d.radius,"cooldown":rng.randf_range(1.0,2.0),"hurt":0.0,"age":0.0,"attack_time":0.0,"warning":0.0,"target":Vector2.ZERO,"direction":Vector2.DOWN,"stun":0.0,"slow":0.0,"honey":0,"burn":0.0,"bubble":0.0,"link":0,"push":Vector2.ZERO,"charge":0.0,"burrow":0.0,"elite":false})

func spawn_pack():
    var pools=[["sprout","crow","bee"],["sprout","termite","mushroom"],["acorn","healer","sprout"],["mole","sprout","bomber"],["charger","shield_bug","sprout"],["moth","leech","mimic"]]
    var count=1+(1 if players.size()==2 else 0) if wave==6 else 2+wave/3+mini(round_no/2,3)+(1 if players.size()==2 else 0)
    for n in range(count):
        var special=["wasp","thornling","hedgehog","seedcaster"] if round_no==2 else ["shade","crystal_crab","spore_bat","root_brute"]
        var pool: Array=(special if rng.randf()<.82 else pools[intel]) if round_no>1 else pools[intel] if rng.randf()<.65 else ["sprout","bee","acorn","charger","bomber"]
        var kind: String=pool[rng.randi_range(0,pool.size()-1)]
        var angle=rng.randf_range(-.7,.7) if intel==0 and rng.randf()<.7 else rng.randf()*TAU
        spawn_enemy(kind,core.pos+Vector2.from_angle(angle)*rng.randf_range(550,740))
        if not enemies.is_empty() and wave>=4 and rng.randf()<.1:
            enemies[-1].elite=true; enemies[-1].hp*=1.8; enemies[-1].max_hp*=1.8

func step(dt: float):
    if phase not in ["battle","boss_outro","deploy","camp"]: return
    if core.placed and core.hp<=0: finish(false,"大甜莓被摧毁了"); return
    var frozen=time_stop>0
    if frozen: time_stop=maxf(0,time_stop-dt)
    else:
        world_time+=dt
        for i in range(effects.size()-1,-1,-1):
            effects[i].ttl-=dt
            if effects[i].ttl<=0: effects.remove_at(i)
    var alive=players.values().filter(func(p): return not p.down)
    linked=alive.size()==2 and alive[0].pos.distance_to(alive[1].pos)<185
    if not frozen: link_charge=clampf(link_charge+(dt*7.5 if linked else -dt*2),0,100)
    for p in players.values():
        if not frozen or p.id==time_owner: step_player(p,dt)
    if not core.placed and players.has(core.carrier): core.pos=players[core.carrier].pos
    if phase=="boss_outro":
        elapsed+=dt; outro_time=maxf(0,outro_time-dt)
        for e in enemies:
            if e.get("defeated",false): e.defeat_time+=dt
        collect_drops(dt)
        if outro_time<=0: finish_round()
        return
    if phase!="battle": return
    elapsed+=dt
    if not frozen:
        clock=maxf(0,clock-dt)
        core.hurt=maxf(0,core.hurt-dt); core.hp=minf(core.max_hp,core.hp+core.regen*dt)
        for p in players.values(): p.rescuing=false
        for p in players.values():
            if not p.down: continue
            var rescuers=alive.filter(func(a): return not a.down and a.hurt<=0 and a.pos.distance_to(p.pos)<100)
            p.revive=p.revive+dt if not rescuers.is_empty() else 0.0
            for helper in rescuers: helper.rescuing=true
            if p.revive>=5: revive(p)
        if players.values().all(func(p):return p.down):
            revive_clock-=dt
            if revive_clock<=0:
                for p in players.values():
                    revive(p); p.pos=resolve_position(core.pos+Vector2(70 if p.id==players.keys()[0] else -70,60),20)
                revive_clock=10
        else: revive_clock=10
        step_core(dt); step_buildings(dt)
        for e in enemies:
            if e.hp>0: step_enemy(e,dt)
    step_zones(dt,frozen)
    step_shots(dt,frozen); cleanup_enemies()
    if phase=="boss_outro": return
    if not frozen: collect_drops(dt)
    if core.hp<=0: finish(false,"大甜莓被摧毁了"); return
    if frozen: return
    if clock<=0:
        if wave==6:
            if not boss_defeated:
                hurt_core(core.max_hp*.22)
                if core.hp<=0 or round_no==DB.ROUND_COUNT: finish(false,"Boss 突破了大甜莓防线"); return
                notice="Boss 撤退撞伤核心；下回合加强火力"
            finish_round()
        else: enter_camp()
        return
    spawn_clock-=dt
    if spawn_clock<=0: spawn_pack(); spawn_clock=3.5 if wave==6 else maxf(.8,2.4-wave*.16-mini(round_no,8)*.1)

func step_player(p: Dictionary, dt: float):
    p.anim_clock+=dt; input_age[p.id]+=dt
    for key in ["hurt","attack","invuln","skill_cd","shield","skill_time","dodge_time","build_time","item_time","dash_cd","dash","shock_cd","familiar_cd","mirror","rocket","item_cd"]: p[key]=maxf(0,p.get(key,0.0)-dt)
    if p.down: p.down_time=p.get("down_time",0.0)+dt
    if p.down: p.moving=false; return
    var direction: Vector2=inputs.get(p.id,Vector2.ZERO) if input_age[p.id]<.45 else Vector2.ZERO
    p.moving=direction.length_squared()>.01
    if p.moving:
        p.last_direction=direction.normalized(); p.move_time+=dt
        p.facing="back" if direction.y<-.45 else "front" if direction.y>.45 else "side"
    else: p.move_time=0
    if absf(direction.x)>.1: p.face=1 if direction.x>0 else -1
    var speed: float=p.speed+(minf(90,p.move_time*18) if p.gear.feet=="runner" else 0.0)+(28 if p.gear.feet=="moon_boots" else 0)
    if p.dash>0 or p.rocket>0: direction=p.last_direction; speed=650 if p.rocket>0 else 800
    p.pos=resolve_position(p.pos+direction*speed*dt,20)
    if phase!="battle": return
    var regen: float=p.regen+(.8 if linked else 0.0)+(1.5 if p.gear.charm=="root_charm" else 0.0)
    if linked and players.values().any(func(a):return a.gear.charm=="couple"): regen+=2
    p.hp=minf(p.max_hp,p.hp+regen*dt)
    if p.rocket>0:
        for e in enemies:
            if e.pos.distance_to(p.pos)<70: hit_enemy(e,70*dt,p.id,false,"rocket",p.last_direction); e.push=p.last_direction*280
    if p.gear.charm=="familiar" and p.familiar_cd<=0:
        area_damage(p.pos,100,18*p.damage,p.id,"star"); p.familiar_cd=1.2
    for slot in p.actions.keys():
        var action: Dictionary=p.actions[slot]; action.time+=dt
        if not action.released and DB.WEAPONS[action.weapon].kind not in ["melee","area","star"]:
            for e in enemies:
                if e.id==action.target and e.hp>0: action.direction=Pose.aim_from_hand(p,slot,e.pos); action.target_pos=e.pos; break
        if not action.released and action.time>=action.hit_at: action.released=true; release_attack(p,slot,action)
        if action.time>=action.duration: p.actions.erase(slot)
    for slot in ["offhand","hand"]:
        var weapon: String=p.equipment[slot]
        if weapon.is_empty(): continue
        p.timers[slot]=p.timers.get(slot,0.0)-dt
        if p.timers[slot]<=0 and attack(p,weapon,slot): p.timers[slot]=DB.WEAPONS[weapon].cooldown/(p.attack_speed*(1.2 if linked else 1.0))

func revive(p: Dictionary):
    p.down=false; p.down_time=0.0; p.hp=p.max_hp*.4; p.invuln=3.0; p.revive=0.0
    effect("heal",p.pos,90,.7)

func target_for(e: Dictionary) -> Dictionary:
    var decoys=buildings.filter(func(b):return b.hp>0 and b.kind=="scarecrow" and b.pos.distance_to(e.pos)<380)
    if not decoys.is_empty(): return nearest_player(e.pos,decoys)
    var candidates=players.values().filter(func(p):return not p.down)
    if e.kind in ["termite","leech","root_brute"] and not buildings.is_empty():
        var available=buildings.filter(func(b):return b.hp>0)
        if not available.is_empty(): return nearest_player(e.pos,available)
    if e.kind in ["crow","bee","mole","snail","queen_wasp","moon_treant"] or candidates.is_empty(): return core
    candidates.append(core)
    return nearest_player(e.pos,candidates)

func step_enemy(e: Dictionary, dt: float):
    e.age+=dt; e.hurt=maxf(0,e.hurt-dt); e.attack_time=maxf(0,e.get("attack_time",0.0)-dt)
    for key in ["stun","slow","burn","bubble"]: e[key]=maxf(0,e[key]-dt)
    if e.burn>0: e.hp-=dt*8
    if e.get("bubble_mark",false) and e.bubble<=0: e.bubble_mark=false; area_damage(e.pos,110,24,0,"bubble")
    if e.age<.65 or e.stun>0 or e.bubble>0: return
    var target=target_for(e)
    var offset: Vector2=target.pos-e.pos
    var distance=offset.length()
    if offset.length()>1: e.direction=offset.normalized()
    e.cooldown-=dt
    var move=1.0
    if e.kind in ["acorn","mimic","seedcaster","spore_bat"]:
        move=0.0 if distance<300 else 1.0
        if distance<140: move=-.5
        if e.cooldown<=0:
            var kind="acorn" if e.kind not in ["seedcaster","spore_bat"] else e.kind
            if e.kind=="mimic":
                var living=players.values().filter(func(p):return not p.down)
                if not living.is_empty(): kind=nearest_player(e.pos,living).equipment.hand
            projectile(e.pos,offset.normalized()*230,e.damage,0,kind,4)
            e.attack_time=.48
            if e.kind=="mimic": projectile(e.pos,offset.normalized().rotated(.16)*230,e.damage,0,kind,4)
            e.cooldown=1.4 if e.kind=="spore_bat" else 1.7 if e.kind=="seedcaster" else 2.0
    elif e.kind=="healer" and e.cooldown<=0:
        for other in enemies:
            if other.pos.distance_to(e.pos)<180: other.hp=minf(other.max_hp,other.hp+12)
        e.attack_time=.48
        effect("heal",e.pos,180,.5); e.cooldown=3.0
    elif e.kind in ["charger","thornling","queen_wasp"] or (e.kind=="snail" and e.hp<e.max_hp*.4):
        if e.warning>0:
            e.warning-=dt; move=0
            if e.warning<=0: e.charge=.8; e.attack_time=.55
        elif e.charge>0:
            e.charge-=dt
            var next: Vector2=e.pos+e.target*(570 if e.kind in ["snail","queen_wasp"] else 440)*dt
            var safe=resolve_position(next,e.radius)
            if next.distance_to(safe)>4: e.stun=1.5; e.charge=0; effect("slam",e.pos,90,.35)
            e.pos=safe; move=0
            if e.kind in ["snail","queen_wasp"]:
                for b in buildings:
                    if b.pos.distance_to(e.pos)<e.radius+30: hurt_building(b,75*dt)
        elif e.cooldown<=0:
            e.target=offset.normalized(); e.warning=.9 if e.kind!="queen_wasp" else .65; e.cooldown=4 if e.kind!="queen_wasp" else 3
            e.attack_time=1.1
            effect("warning",e.pos+e.target*130,65,.9)
    if e.kind=="snail" and e.cooldown<=0 and e.hp>=e.max_hp*.4: add_zone("slime",e.pos,95,7,0,0); e.cooldown=2.0; e.attack_time=.48
    if e.kind=="moon_treant" and e.cooldown<=0:
        for n in range(4): add_zone("meteor",e.pos+Vector2.from_angle(n*TAU/4+e.age)*rng.randf_range(100,260),70,1.0,e.damage,0)
        e.cooldown=3.5; e.attack_time=.6; effect("warning",e.pos,210,.8)
    if e.kind=="queen_wasp" and e.hp<e.max_hp*.5 and fmod(e.age,12)<dt:
        for n in range(3): spawn_enemy("wasp",e.pos+Vector2.from_angle(n*TAU/3)*100)
    if e.kind=="shade": move=1.6 if fmod(e.age,5)<1 else 1.0
    if e.kind=="mole": e.burrow=fmod(e.age,6); move=1.4 if e.burrow<3.5 else .7
    var flying=e.kind in ["crow","bee","moth","wasp","spore_bat","queen_wasp","shade"] or (e.kind=="mole" and e.burrow<3.5)
    var speed: float=e.speed*move*(.42 if e.slow>0 else 1.0)*(1-minf(.6,e.honey*.15))
    var at: Vector2=e.pos+offset.normalized()*speed*dt+e.push*dt
    e.push=e.push.move_toward(Vector2.ZERO,dt*650)
    if e.push.length()>100:
        for other in enemies:
            if other.id!=e.id and other.hp>0 and other.pos.distance_to(e.pos)<other.radius+e.radius: hit_enemy(other,12,0,false,"collision",e.push.normalized()); e.push*=.65
    e.pos=at.clamp(Vector2(55,55),DB.ARENA-Vector2(55,55)) if flying else resolve_position(at,e.radius)
    if not flying:
        for b in buildings:
            if b.hp<=0 or b.kind in ["spikes","spring","trap"]: continue
            var delta: Vector2=e.pos-b.pos
            if delta.length()<e.radius+30:
                if e.kind=="leech": b.disabled=2.0; e.pos=b.pos; return
                if e.get("bite",0.0)<=0:
                    hurt_building(b,e.damage*(2.0 if e.kind in ["termite","snail","root_brute","moon_treant"] else 1.0))
                    e.attack_time=.45
                    if b.kind=="fence": hit_enemy(e,14,0,false,"thorns")
                    e.bite=.9
                e.pos=b.pos+(delta.normalized() if delta.length()>1 else Vector2.RIGHT)*(e.radius+30)
    e.bite=maxf(0,e.get("bite",0.0)-dt)
    if distance<e.radius+48 and target==core and e.get("bite",0.0)<=0:
        hurt_core(e.damage); e.bite=.9; e.attack_time=.45
        if e.kind=="crow":
            for p in players.values(): p.coins=maxi(0,p.coins-2)
    for p in players.values():
        if not p.down and e.pos.distance_to(p.pos)<e.radius+19:
            hurt_player(p,e.damage,e.pos); e.attack_time=.45

func step_core(dt: float):
    for p in players.values():
        if not p.down and p.pos.distance_to(core.pos)<250: p.hp=minf(p.max_hp,p.hp+core.aura*dt)
    for b in buildings:
        if b.pos.distance_to(core.pos)<260: b.hp=minf(b.max_hp,b.hp+core.repair*dt)
    core.timer-=dt
    if core.timer<=0:
        core.timer=1
        if core.vine>0: area_damage(core.pos,155,core.vine*16,0,"vine")
        if core.attack>0:
            var targets=enemies.filter(func(e):return e.hp>0 and e.pos.distance_to(core.pos)<420)
            if not targets.is_empty(): projectile(core.pos,(nearest_player(core.pos,targets).pos-core.pos).normalized()*450,core.attack*22,-1,"wand",1.3)

func step_buildings(dt: float):
    for b in buildings:
        b.disabled=maxf(0,b.disabled-dt); b.hurt=maxf(0,b.hurt-dt)
        if b.ttl>0:
            b.ttl-=dt
            if b.ttl<=0:
                if b.get("decoy",false): area_damage(b.pos,210,150,b.owner,"bomb")
                b.hp=0
        if b.hp<=0 or b.disabled>0: continue
        b.timer-=dt
        if b.timer>0: continue
        var def: Dictionary=C.BUILDINGS[b.kind]
        var owner: Dictionary=players.get(b.owner,{})
        var power: float=owner.get("build_power",1.0)
        var teamwork=players.values().filter(func(p):return not p.down and p.pos.distance_to(b.pos)<180).size()==2
        b.timer=def.cooldown/(1.2 if teamwork else 1.0)
        var targets=enemies.filter(func(e):return e.hp>0 and e.pos.distance_to(b.pos)<def.range)
        var amount: float=def.damage*power
        if b.kind in ["fountain","repair","moon_lantern"]:
            var efficiency=1.5 if owner.get("gear",{}).get("head","")=="mechanic" else 1.0
            for other in buildings:
                if other.pos.distance_to(b.pos)<def.range: other.hp=minf(other.max_hp,other.hp+amount*efficiency)
            if b.kind=="fountain":
                if core.pos.distance_to(b.pos)<def.range: core.hp=minf(core.max_hp,core.hp+amount*efficiency)
                for p in players.values():
                    if not p.down and p.pos.distance_to(b.pos)<def.range: p.hp=minf(p.max_hp,p.hp+amount*efficiency)
        elif b.kind=="frost":
            for e in targets: e.slow=1.6
        elif b.kind=="wall": pass
        elif not targets.is_empty():
            var target=nearest_player(b.pos,targets)
            if b.kind=="turret": projectile(b.pos,(target.pos-b.pos).normalized()*480,amount,b.owner,"seed",1.2)
            elif b.kind=="beehive":
                for n in [-1,0,1]: projectile(b.pos,(target.pos-b.pos).normalized().rotated(n*.13)*530,amount,b.owner,"hive_bow",1.2)
            elif b.kind=="mortar": add_zone("meteor",target.pos,95,.7,amount,b.owner)
            elif b.kind=="root_tower":
                add_zone("meteor",target.pos,105,.55,amount,b.owner)
                target.slow=2.0
            elif b.kind=="spikes":
                for e in targets: hit_enemy(e,amount,b.owner,false,"spikes")
            elif b.kind=="spring": target.push=(target.pos-b.pos).normalized()*600; hit_enemy(target,amount,b.owner,false,"spring")
            elif b.kind=="trap": target.stun=.6 if target.kind in DB.BOSS_KINDS else 4; hit_enemy(target,amount,b.owner,false,"trap"); b.hp=0
    for i in range(buildings.size()-1,-1,-1):
        if buildings[i].hp<=0: effect("poof",buildings[i].pos,35,.5); buildings.remove_at(i)

func add_zone(kind: String, at: Vector2, radius: float, ttl: float, damage: float, owner: int):
    if zones.size()<45: zones.append({"id":next_id(),"kind":kind,"pos":at,"radius":radius,"ttl":ttl,"duration":ttl,"damage":damage,"owner":owner})

func step_zones(dt: float, frozen: bool=false):
    for i in range(zones.size()-1,-1,-1):
        var z: Dictionary=zones[i]
        if frozen and z.owner!=time_owner: continue
        z.ttl-=dt
        if z.kind=="heal":
            for p in players.values():
                if not p.down and (not frozen or p.id==time_owner) and p.pos.distance_to(z.pos)<z.radius: p.hp=minf(p.max_hp,p.hp+8*dt)
            if not frozen and core.pos.distance_to(z.pos)<z.radius: core.hp=minf(core.max_hp,core.hp+10*dt)
        elif z.kind=="slime":
            for p in players.values():
                if not p.down and p.moving and p.pos.distance_to(z.pos)<z.radius: p.pos-=p.last_direction*p.speed*dt*.45
            for b in buildings:
                if b.pos.distance_to(z.pos)<z.radius: hurt_building(b,4*dt)
        elif z.kind=="vacuum":
            for e in enemies:
                if not frozen and e.kind not in DB.BOSS_KINDS and not e.elite and e.pos.distance_to(z.pos)<z.radius: e.pos=e.pos.move_toward(z.pos,dt*85)
        elif z.kind=="banana":
            for e in enemies:
                if e.pos.distance_to(z.pos)<z.radius: e.stun=.6 if e.kind in DB.BOSS_KINDS else 2.5; z.ttl=0; break
        if z.ttl<=0:
            if z.kind=="meteor": area_damage(z.pos,z.radius,z.damage,z.owner,"star"); effect("slam",z.pos,z.radius,.5)
            elif z.kind=="bomb": explode(z.pos,z.radius,z.damage,z.owner,true)
            zones.remove_at(i)

func step_shots(dt: float, frozen: bool):
    for i in range(shots.size()-1,-1,-1):
        var s: Dictionary=shots[i]
        if frozen and s.owner!=time_owner: continue
        s.ttl-=dt
        if s.kind=="shovel" and s.age>.48 and players.has(s.owner): s.vel=(players[s.owner].pos-s.pos).normalized()*430
        s.age+=dt
        var old: Vector2=s.pos; s.pos+=s.vel*dt
        if s.owner==0:
            if segment_distance(core.pos,old,s.pos)<45: hurt_core(s.damage); s.ttl=0
            for p in players.values():
                if not p.down and segment_distance(p.pos,old,s.pos)<22: hurt_player(p,s.damage,s.pos); s.ttl=0; break
            for b in buildings:
                if segment_distance(b.pos,old,s.pos)<28: hurt_building(b,s.damage); s.ttl=0; break
        else:
            for e in enemies:
                var pass_id=str(e.id)+("r" if s.age>.48 else "f") if s.kind=="shovel" else str(e.id)
                if e.hp>0 and e.age>=.4 and not pass_id in s.hit and segment_distance(e.pos,old,s.pos)<e.radius+7:
                    s.hit.append(pass_id); hit_enemy(e,s.damage,s.owner,s.crit,s.kind,s.vel.normalized())
                    if s.kind=="shovel": continue
                    if s.bounce>0:
                        s.bounce-=1
                        var targets=enemies.filter(func(a):return a.hp>0 and not str(a.id) in s.hit and a.pos.distance_to(e.pos)<230)
                        if not targets.is_empty(): s.vel=(nearest_player(e.pos,targets).pos-e.pos).normalized()*s.vel.length(); break
                    s.ttl=0; break
        if s.ttl<=0 or s.pos.x<0 or s.pos.y<0 or s.pos.x>DB.ARENA.x or s.pos.y>DB.ARENA.y: shots.remove_at(i)

func cleanup_enemies():
    var boss_down=false
    for i in range(enemies.size()-1,-1,-1):
        var e: Dictionary=enemies[i]
        if e.hp>0 or e.get("defeated",false): continue
        kills+=1
        if e.kind in DB.BOSS_KINDS:
            boss_down=true; boss_defeated=true; e.defeated=true; e.defeat_time=0.0; e.hp=0
            phase="boss_outro"; outro_time=10.0; notice="%s被击败！拾取战利品 · 10 秒后进入下一回合" % DB.ENEMIES[e.kind].name
            var boss_data: Dictionary=DB.ENEMIES[e.kind]
            drops.append({"id":next_id(),"pos":e.pos+Vector2(0,52),"xp":boss_data.xp,"coin":boss_data.coin,"item":boss_data.get("drop","rescue_flower")})
            effect("boss_down",e.pos,e.radius*2,1.0)
            continue
        if e.kind=="bomber": explode(e.pos,120,45,0,true)
        var d: Dictionary=DB.ENEMIES[e.kind]
        if drops.size()<MAX_DROPS:
            var drop={"id":next_id(),"pos":e.pos,"xp":d.xp,"coin":d.coin}
            if rng.randf()<d.get("drop_chance",0.0): drop.item=d.drop
            drops.append(drop)
        else: reward(d.xp,d.coin)
        effect("poof",e.pos,e.radius,.35); enemies.remove_at(i)
    if boss_down:
        for i in range(enemies.size()-1,-1,-1):
            if not enemies[i].get("defeated",false): effect("poof",enemies[i].pos,enemies[i].radius,.3); enemies.remove_at(i)
        shots.clear(); zones.clear()

func claim_drop(d: Dictionary, p: Dictionary):
    reward(int(d.get("xp",0)),int(d.get("coin",0)))
    var key: String=d.get("item","")
    if not key.is_empty():
        p.items.append(key)
        p.ui_revision+=1
    effect("pickup",d.pos,35 if not key.is_empty() else 28,.25)

func collect_drops(dt: float):
    for i in range(drops.size()-1,-1,-1):
        var d: Dictionary=drops[i]
        for p in players.values():
            if p.down: continue
            var radius: float=p.magnet+(80 if p.gear.head=="magnet_cap" else 0)+(100 if p.gear.charm=="lantern" else 0)
            var dist: float=p.pos.distance_to(d.pos)
            if dist<radius:
                d.pos=d.pos.move_toward(p.pos,dt*400)
                if dist<28: claim_drop(d,p); drops.remove_at(i); break

func resolve_position(at: Vector2, radius: float) -> Vector2:
    at=at.clamp(Vector2(45,45)+Vector2.ONE*radius,DB.ARENA-Vector2(45,45)-Vector2.ONE*radius)
    for rock in rocks:
        if rock.hp<=0: continue
        var delta: Vector2=at-rock.pos
        if delta.length()<rock.radius+radius: at=rock.pos+(delta.normalized() if delta.length()>.01 else Vector2.RIGHT)*(rock.radius+radius)
    return at

static func segment_distance(point: Vector2, start: Vector2, end: Vector2) -> float:
    return point.distance_to(Geometry2D.get_closest_point_to_segment(point,start,end))

func nearest_player(at: Vector2, candidates: Array) -> Dictionary:
    if candidates.is_empty(): return core
    var best: Dictionary=candidates[0]
    for p in candidates:
        if p.pos.distance_squared_to(at)<best.pos.distance_squared_to(at): best=p
    return best

func attack(p: Dictionary, weapon: String, slot: String="hand") -> bool:
    if p.actions.has(slot) or p.down or weapon.is_empty(): return false
    var w: Dictionary=DB.WEAPONS[weapon]
    var targets=enemies.filter(func(e):return e.hp>0 and e.age>=.4 and e.pos.distance_to(p.pos)<w.range)
    if targets.is_empty(): return false
    var target=nearest_player(p.pos,targets)
    var crit=rng.randf()<minf(.8,p.crit)
    var damage: float=w.damage*p.damage*(1+(p.weapons.get(weapon,1)-1)*.32)*(2 if crit else 1)
    var speed=clampf(p.attack_speed*(1.2 if linked else 1.0),.5,3)
    var timing: Dictionary=DB.ATTACK_MOTION.get(weapon,{"windup":.10,"recover":.16,"kick":3})
    p.attack=(timing.windup+timing.recover)/speed
    p.actions[slot]={"seq":next_id(),"weapon":weapon,"time":0.0,"hit_at":timing.windup/speed,"duration":p.attack,"released":false,"direction":Pose.aim_from_hand(p,slot,target.pos),"damage":damage,"crit":crit,"target":target.id,"target_pos":target.pos}
    if weapon in ["spoon","wand","needle","petal"]: effect("windup_"+weapon,Pose.muzzle(p,slot,p.actions[slot]),0,timing.windup/speed,p.actions[slot].direction.angle())
    return true

func release_attack(p: Dictionary, slot: String, a: Dictionary):
    var weapon: String=a.weapon
    var w: Dictionary=DB.WEAPONS[weapon]
    var forward: Vector2=a.direction
    var origin=Pose.muzzle(p,slot,a)
    effect("release_"+weapon,origin,0,.25,forward.angle())
    var damage: float=a.damage
    var radius: float=w.range*p.area
    if weapon=="shears":
        p.combos[slot]=p.combos.get(slot,0)+1
        if p.combos[slot]%3==0:
            damage*=2.2
            if p.equipment.hand=="shears" and p.equipment.offhand=="shears": radius*=1.6
    if weapon=="moon":
        p.energy+=20
        if p.energy>=100: p.energy=0; radius=300*p.area; damage*=3; effect("combo",p.pos,radius,.6)
    if w.kind in ["melee","area"]:
        effect("swing_"+weapon,p.pos,radius,.28,forward.angle())
        for e in enemies:
            var delta: Vector2=e.pos-p.pos
            if e.hp>0 and delta.length()<radius+e.radius and (w.kind=="area" or delta.normalized().dot(forward)>-.2):
                hit_enemy(e,damage,p.id,a.crit,weapon,delta.normalized())
                e.push=delta.normalized()*(620 if weapon=="radish" else 520 if weapon=="root_hammer" else 80)
    elif w.kind=="star":
        add_zone("meteor",a.target_pos,110*p.area,.7,damage,p.id)
        if weapon=="prism_staff":
            for n in [-1,1]: add_zone("meteor",a.target_pos+forward.orthogonal()*n*95,60*p.area,.95,damage*.42,p.id)
    else:
        projectile(origin,forward*w.speed,damage,p.id,weapon,1.45,a.crit)
        if weapon=="shovel" and p.equipment.hand=="shovel" and p.equipment.offhand=="shovel": projectile(origin,forward.rotated(.22)*w.speed,damage*.75,p.id,weapon,1.45,a.crit)
        if weapon=="hive_bow": projectile(origin,forward.rotated(.18)*w.speed,damage*.75,p.id,weapon,1.45,a.crit)
    if slot=="offhand" and p.mirror>0:
        if w.kind in ["melee","area"]: area_damage(p.pos,radius,damage*.8,p.id,weapon)
        elif w.kind=="star": add_zone("meteor",a.target_pos+Vector2(35,0),110*p.area,.8,damage*.8,p.id)
        else: projectile(origin,forward.rotated(-.14)*w.speed,damage*.8,p.id,weapon,1.45)

func projectile(at: Vector2, velocity: Vector2, damage: float, owner: int, kind: String, lifetime: float, crit: bool=false):
    if shots.size()<MAX_SHOTS: shots.append({"id":next_id(),"pos":at,"vel":velocity,"damage":damage,"owner":owner,"kind":kind,"ttl":lifetime,"crit":crit,"age":0.0,"hit":[],"bounce":2 if kind=="wand" and owner!=0 else 0})

func area_damage(at: Vector2, radius: float, damage: float, owner: int, kind: String="skill"):
    for e in enemies:
        if e.hp>0 and e.pos.distance_to(at)<radius+e.radius: hit_enemy(e,damage,owner,false,kind,(e.pos-at).normalized())

func hit_enemy(e: Dictionary, damage: float, owner: int, crit: bool=false, weapon: String="skill", direction: Vector2=Vector2.ZERO):
    if e.hp<=0: return
    if e.kind in ["shield_bug","crystal_crab"] and direction.dot(e.direction)<-.3: damage*=.25
    if e.kind=="hedgehog" and players.has(owner) and players[owner].pos.distance_to(e.pos)<120: hurt_player(players[owner],4,e.pos)
    if weapon=="honey": e.honey=mini(3,e.honey+1)
    if weapon=="flame":
        e.burn=3
        if e.honey>0:
            var extra=e.honey*20; e.honey=0
            area_damage(e.pos,115,extra,owner,"combustion"); effect("slam",e.pos,115,.45)
    if weapon=="bubble" and e.kind not in DB.BOSS_KINDS and not e.elite and rng.randf()<.3: e.bubble=1.8; e.bubble_mark=true
    if weapon=="thread":
        var others=enemies.filter(func(a):return a.id!=e.id and a.hp>0 and a.pos.distance_to(e.pos)<250)
        if not others.is_empty():
            var other=nearest_player(e.pos,others); e.link=other.id; other.link=e.id
    if weapon=="bee_blade" or weapon=="hive_bow": e.burn=maxf(e.burn,2.5)
    if weapon=="root_hammer": e.stun=maxf(e.stun,.55 if e.kind in DB.BOSS_KINDS else 1.5)
    e.hp-=damage; e.hurt=.12
    if e.link!=0:
        for other in enemies:
            if other.id==e.link and other.hp>0: other.hp-=damage*.45; other.hurt=.12; break
    if players.has(owner): players[owner].damage_dealt+=damage; players[owner].hit_serial+=1
    effect("impact_"+weapon,e.pos,e.radius,.2,direction.angle())
    if effects.size()<60: effect("crit" if crit else "number",e.pos-Vector2(0,e.radius),damage,.65)

func hurt_player(p: Dictionary, raw_damage: float, source: Vector2=Vector2.INF):
    if p.down or p.invuln>0 or p.shield>0 or (time_stop>0 and p.id!=time_owner): return
    if p.gear.head=="first_guard" and p.first_guard: p.first_guard=false; p.invuln=.7; effect("heal",p.pos,50,.4); return
    var armor: float=p.armor+(3 if p.gear.body=="thorn_vest" else 0)+(4 if p.gear.head=="hive_helm" else 0)
    p.hp=maxf(0,p.hp-raw_damage*100/(100+armor*9)); p.hurt=.3; p.invuln=.7
    for other in players.values():
        if other.down and p.pos.distance_to(other.pos)<100: other.revive=0
    if p.gear.body=="thorn_vest" and source.is_finite() and source.distance_to(p.pos)<95: area_damage(p.pos,95,15,p.id,"thorns")
    if p.gear.body=="petal_mantle": p.hp=minf(p.max_hp,p.hp+8); p.move_time=2
    if p.gear.charm=="shock" and p.shock_cd<=0: area_damage(p.pos,155,38,p.id); effect("slam",p.pos,155,.5); p.shock_cd=6
    if p.hp<=0: p.down=true; p.down_time=0.0; p.moving=false; p.revive=0; p.actions.clear()

func hurt_core(damage: float):
    if time_stop>0: return
    var amount=damage*100/(100+core.armor*9)
    var absorbed=minf(core.shield,amount); core.shield-=absorbed
    core.hp=maxf(0,core.hp-(amount-absorbed)); core.hurt=.2
    if core.hp<=0: finish(false,"大甜莓被摧毁了")

func hurt_building(b: Dictionary, amount: float):
    if time_stop>0: return
    if b.pos.distance_to(core.pos)<260: amount*=1-minf(.6,core.guard)
    b.hp=maxf(0,b.hp-amount); b.hurt=.2

func explode(at: Vector2, radius: float, damage: float, owner: int, friendly_fire: bool):
    area_damage(at,radius,damage,owner,"bomb"); effect("slam",at,radius,.7)
    for e in enemies:
        if e.pos.distance_to(at)<radius: e.push=(e.pos-at).normalized()*550
    if friendly_fire:
        for p in players.values():
            if p.pos.distance_to(at)<radius and (time_stop<=0 or p.id==time_owner): hurt_player(p,damage*.3,at); p.pos=resolve_position(p.pos+(p.pos-at).normalized()*90,20)
        if core.pos.distance_to(at)<radius: hurt_core(damage*.45)
        for b in buildings:
            if b.pos.distance_to(at)<radius: hurt_building(b,damage*.7)
        for rock in rocks:
            if time_stop<=0 and rock.pos.distance_to(at)<radius: rock.hp-=damage

func use_skill(id: int) -> bool:
    if phase!="battle" or not players.has(id) or (time_stop>0 and time_owner!=id): return false
    var p: Dictionary=players[id]
    if p.down or p.skill_cd>0: return false
    p.skill_cd=maxf(4,12*(1-p.cooldown_bonus)*(1-p.skill_haste)); p.skill_time=.8
    var combo=linked and link_charge>=100
    var radius=(300 if combo else 210)*p.area
    effect("combo" if combo else "heal" if p.character=="yier" else "slam",p.pos,radius,.8)
    if combo: link_charge=0
    for other in players.values():
        if other.down or (time_stop>0 and other.id!=id): continue
        if other.pos.distance_to(p.pos)<radius:
            var healing=other.max_hp*(.3 if combo else .22 if p.character=="yier" else 0)*p.skill_power
            other.hp=minf(other.max_hp,other.hp+healing); p.healed+=healing
            other.shield=3 if combo or p.character=="bubu" else 1
    if time_stop<=0 and core.pos.distance_to(p.pos)<radius and p.character=="yier": core.hp=minf(core.max_hp,core.hp+45)
    area_damage(p.pos,radius,(85 if combo else 48 if p.character=="bubu" else 25)*p.damage*p.skill_power,id)
    return true

func dash_player(id: int) -> bool:
    if phase!="battle" or not players.has(id) or (time_stop>0 and time_owner!=id): return false
    var p: Dictionary=players[id]
    if p.down or p.gear.feet not in ["dash_boots","moon_boots"] or p.dash_cd>0: return false
    p.dash=.18; p.dodge_time=.45; p.invuln=.25; p.dash_cd=3 if p.gear.feet=="moon_boots" else 4; return true

func item_capacity(p: Dictionary) -> int:
    return maxi(p.items.size(),4 if p.gear.charm=="skill_stone" else 3)

func use_item(id: int, index: int) -> bool:
    if phase not in ["battle","camp","deploy"] or not players.has(id) or (time_stop>0 and time_owner!=id): return false
    var p: Dictionary=players[id]
    if p.down or index<0 or index>=p.items.size() or p.item_cd>0: return false
    var key: String=p.items[index]
    if key=="dice":
        if phase not in ["camp","deploy"] or p.ready: return false
        refresh_stock(p); p.bought=[]
    elif phase!="battle": return false
    elif key=="world":
        if time_stop>0: return false
        time_stop=5; time_owner=id
    elif key=="bomb": add_zone("bomb",resolve_position(p.pos+p.last_direction*200,15),220*p.area,.8,380*p.damage,id)
    elif key=="heal_seed": add_zone("heal",p.pos,170,8,0,id)
    elif key=="fence_kit":
        for n in [-1,0,1]: create_building(id,"fence",resolve_position(p.pos+p.last_direction*85+p.last_direction.orthogonal()*n*62,30),20)
    elif key=="decoy":
        if create_building(id,"scarecrow",resolve_position(p.pos+p.last_direction*80,30),5): buildings[-1].decoy=true
        else: return false
    elif key=="home": p.pos=resolve_position(core.pos+Vector2(70,60),20)
    elif key=="vacuum":
        for i in range(drops.size()-1,-1,-1):
            if drops[i].pos.distance_to(p.pos)<650: claim_drop(drops[i],p); drops.remove_at(i)
        add_zone("vacuum",p.pos,280,3,0,id)
    elif key=="mirror":
        if p.equipment.offhand.is_empty(): return false
        p.mirror=10
    elif key=="freeze":
        for e in enemies:
            if e.kind in DB.BOSS_KINDS: e.slow=4
            else: e.stun=4
    elif key=="rocket": p.rocket=2; p.invuln=2
    elif key=="banana": add_zone("banana",p.pos+p.last_direction*55,45,30,0,id)
    elif key=="nectar": p.hp=minf(p.max_hp,p.hp+p.max_hp*.35); p.invuln=1.0
    elif key=="thorn_orb":
        var center=p.pos+p.last_direction*190
        area_damage(center,155,95*p.damage,id,"thorn_orb")
        for e in enemies:
            if e.pos.distance_to(center)<155: e.stun=maxf(e.stun,.5 if e.kind in DB.BOSS_KINDS else 1.8)
        effect("slam",center,155,.5)
    elif key=="moonbell":
        for i in range(shots.size()-1,-1,-1):
            if shots[i].owner==0 and shots[i].pos.distance_to(p.pos)<320: shots.remove_at(i)
        for other in players.values():
            if other.pos.distance_to(p.pos)<320: other.shield=maxf(other.shield,4)
        effect("combo",p.pos,320,.6)
    elif key=="rescue_flower":
        var downed=players.values().filter(func(a):return a.down and a.pos.distance_to(p.pos)<380)
        if downed.is_empty(): p.hp=minf(p.max_hp,p.hp+p.max_hp*.5)
        else:
            revive(downed[0]); downed[0].hp=downed[0].max_hp*.6
        effect("heal",p.pos,220,.6)
    p.items.remove_at(index); p.ui_revision+=1; p.item_cd=.25; p.item_time=.5
    return true

func valid_site(at: Vector2, radius: float=30) -> bool:
    if not at.is_finite() or at.x<80 or at.y<80 or at.x>DB.ARENA.x-80 or at.y>DB.ARENA.y-80: return false
    for rock in rocks:
        if rock.hp>0 and rock.pos.distance_to(at)<rock.radius+radius: return false
    for b in buildings:
        if b.hp>0 and b.pos.distance_to(at)<radius+30: return false
    return true

func snap_site(at: Vector2) -> Vector2:
    return Vector2(floor(at.x/GRID)*GRID+GRID/2,floor(at.y/GRID)*GRID+GRID/2)

func site_state(id: int, at: Vector2) -> String:
    at=snap_site(at)
    if not players.has(id) or players[id].pos.distance_to(at)>240 or at.x<80 or at.y<80 or at.x>DB.ARENA.x-80 or at.y>DB.ARENA.y-80: return "invalid"
    if core.placed and core.pos.distance_to(at)<80: return "occupied"
    for rock in rocks:
        if rock.hp>0 and rock.pos.distance_to(at)<rock.radius+30: return "occupied"
    for b in buildings:
        if b.hp>0 and b.pos.distance_to(at)<60: return "occupied"
    return "valid"

func create_building(id: int, key: String, at: Vector2, ttl: float=0) -> bool:
    at=snap_site(at)
    if not C.BUILDINGS.has(key) or buildings.size()>=MAX_BUILDINGS or not valid_site(at): return false
    if core.placed and core.pos.distance_to(at)<80: return false
    var def: Dictionary=C.BUILDINGS[key]
    var hp: float=def.hp*(1.2 if players.has(id) and players[id].gear.charm=="root_charm" else 1.0)
    buildings.append({"id":next_id(),"kind":key,"pos":at,"hp":hp,"max_hp":hp,"owner":id,"timer":.3,"disabled":0.0,"hurt":0.0,"ttl":ttl})
    return true

func build(id: int, key: String, at: Vector2) -> bool:
    if phase not in ["deploy","camp","battle"] or not players.has(id) or (time_stop>0 and id!=time_owner): return false
    var p: Dictionary=players[id]
    if p.down or p.ready or p.inventory.get(key,0)<=0 or site_state(id,at)!="valid": return false
    if not create_building(id,key,at): return false
    p.inventory[key]-=1; p.ui_revision+=1; p.build_time=.5; effect("build_place",snap_site(at),55,.3); return true

func effect(kind: String, at: Vector2, radius: float, lifetime: float, angle: float=0):
    if effects.size()<90: effects.append({"id":next_id(),"kind":kind,"pos":at,"radius":radius,"ttl":lifetime,"duration":lifetime,"angle":angle})

func reward(amount: int, coins: int):
    xp+=amount; total_xp+=amount
    for p in players.values(): p.coins+=coins
    while xp>=DB.xp_needed(level):
        xp-=DB.xp_needed(level); level+=1
        for p in players.values(): p.pending+=1

func choose_random(pool: Array, count: int) -> Array:
    var copy=pool.duplicate(); var chosen: Array=[]
    while not copy.is_empty() and chosen.size()<count: chosen.append(copy.pop_at(rng.randi_range(0,copy.size()-1)))
    return chosen

func core_shop_open() -> bool:
    return special_supply_open()

func special_supply_open() -> bool:
    return phase=="camp" and wave==0 and round_no>1

func refresh_stock(p: Dictionary):
    p.stock=[]
    for pool in [DB.WEAPONS.keys(),C.GEAR.keys().filter(func(k):return C.GEAR[k].slot!="charm"),C.GEAR.keys().filter(func(k):return C.GEAR[k].slot=="charm"),C.ITEMS.keys(),C.BUILDINGS.keys()]:
        var eligible: Array=[]
        for key in pool:
            if int(shop_data(key).get("round",1))>round_no: continue
            var rarity: int=C.data(key).get("rarity",1)
            var chance=.09 if rarity==4 else .22
            if p.gear.charm=="lucky": chance*=2.5
            if rarity<3 or rng.randf()<chance: eligible.append(key)
        p.stock+=choose_random(eligible,3)
    if core_shop_open(): p.stock+=C.CORE_UPGRADES.keys()+C.SKILL_UPGRADES.keys()
    p.ui_revision+=1

func shop_data(key: String) -> Dictionary:
    return DB.WEAPONS[key] if DB.WEAPONS.has(key) else C.data(key)

func choose_upgrade(id: int, key: String) -> bool:
    if phase not in ["camp","deploy"] or not players.has(id): return false
    var p: Dictionary=players[id]
    if p.ready or p.pending<=0 or not key in p.offers: return false
    var u: Dictionary=DB.UPGRADES[key]; p[u.stat]+=u.value
    if key=="heart": p.hp=minf(p.max_hp,p.hp+25)
    p.speed=minf(p.speed,340); p.crit=minf(p.crit,.8); p.pending-=1
    p.offers=choose_random(DB.UPGRADES.keys(),3) if p.pending>0 else []
    p.ui_revision+=1; return true

func buy(id: int, key: String) -> bool:
    if phase not in ["camp","deploy"] or not players.has(id): return false
    if C.CORE_UPGRADES.has(key) and not core_shop_open(): return false
    var p: Dictionary=players[id]
    var data=shop_data(key)
    if p.ready or data.is_empty() or not key in p.stock or key in p.bought or p.coins<data.price: return false
    if DB.WEAPONS.has(key):
        if p.weapons.get(key,0)>=4: return false
        p.weapons[key]=p.weapons.get(key,0)+1
        if p.equipment.offhand.is_empty(): p.equipment.offhand=key
    elif C.GEAR.has(key):
        if key in p.owned: return false
        p.owned.append(key); equip_gear(id,C.GEAR[key].slot,key)
    elif C.ITEMS.has(key):
        if p.items.size()>=item_capacity(p): return false
        p.items.append(key)
    elif C.BUILDINGS.has(key): p.inventory[key]=p.inventory.get(key,0)+1
    elif C.CORE_UPGRADES.has(key): grow_core(key)
    p.coins-=data.price; p.bought.append(key); p.ui_revision+=1; return true

func grow_core(key: String):
    match key:
        "core_hp": core.max_hp+=150; core.hp+=150
        "core_regen": core.regen+=1.2
        "core_armor": core.armor+=3
        "core_aura": core.aura+=1.5
        "core_repair": core.repair+=2
        "core_shield": core.shield_max+=100; core.shield+=100
        "core_guard": core.guard=minf(.6,core.guard+.2)
        "core_attack": core.attack+=1
        "core_vine": core.vine+=1

func choose_core(id: int, key: String) -> bool:
    if not core_shop_open() or not players.has(id) or not C.CORE_UPGRADES.has(key): return false
    var p: Dictionary=players[id]
    if p.ready or p.core_tokens<=0: return false
    grow_core(key); p.core_tokens-=1; p.ui_revision+=1; return true

func choose_skill_growth(id: int, key: String) -> bool:
    if not special_supply_open() or not players.has(id) or not C.SKILL_UPGRADES.has(key): return false
    var p: Dictionary=players[id]
    if p.ready or p.skill_tokens<=0: return false
    if key=="skill_power": p.skill_power+=.25
    else: p.skill_haste=minf(.5,p.skill_haste+.18)
    p.skill_tokens-=1; p.ui_revision+=1; return true

func reroll(id: int) -> bool:
    if phase not in ["camp","deploy"] or not players.has(id): return false
    var p: Dictionary=players[id]
    if p.ready or p.coins<8: return false
    p.coins-=8; p.bought=[]; refresh_stock(p); return true

func ready_player(id: int):
    if phase!="camp" or not players.has(id): return
    var p: Dictionary=players[id]
    if p.pending>0 or p.core_tokens>0 or p.skill_tokens>0: return
    p.ready=not p.ready; p.ui_revision+=1
    if players.values().all(func(a):return a.ready): begin_wave()

func equip(id: int, slot: String, key: String) -> bool:
    if phase not in ["camp","deploy"] or not players.has(id) or slot not in ["hand","offhand"]: return false
    var p: Dictionary=players[id]
    if p.ready or (not key.is_empty() and not p.weapons.has(key)): return false
    p.equipment[slot]=key; p.ui_revision+=1; return true

func equip_gear(id: int, slot: String, key: String) -> bool:
    if phase not in ["camp","deploy"] or not players.has(id): return false
    var p: Dictionary=players[id]
    if p.ready or not p.gear.has(slot): return false
    if not key.is_empty() and (not key in p.owned or C.GEAR[key].slot!=slot): return false
    if slot=="charm" and key!="skill_stone" and p.items.size()>3: return false
    p.gear[slot]=key; p.ui_revision+=1; return true

func finish(won: bool, reason: String=""):
    phase="result"; result="守护成功" if won else (reason if not reason.is_empty() else "大甜莓被摧毁了")
    for p in players.values(): p.actions.clear()
    revision+=1

func snapshot() -> Dictionary:
    return {"players":players,"enemies":enemies,"shots":shots,"drops":drops,"effects":effects,"buildings":buildings,"zones":zones,"rocks":rocks,"core":core,"phase":phase,"round_no":round_no,"wave":wave,"clock":clock,"elapsed":elapsed,"world_time":world_time,"kills":kills,"level":level,"xp":xp,"total_xp":total_xp,"link_charge":link_charge,"linked":linked,"result":result,"revision":revision,"revive_clock":revive_clock,"time_stop":time_stop,"time_owner":time_owner,"intel":intel,"boss_defeated":boss_defeated,"outro_time":outro_time,"checkpoint_round":checkpoint_round,"notice":notice,"uid":uid,"rng_state":rng.state}

func restore(state: Dictionary):
    for key in snapshot():
        if key=="rng_state":
            if state.has(key): rng.state=state[key]
        elif state.has(key): set(key,state[key])
