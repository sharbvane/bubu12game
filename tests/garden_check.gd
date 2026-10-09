extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const C=preload("res://scripts/garden_content.gd")

func make(two: bool=false) -> RefCounted:
    var s=Sim.new(42); s.add_player(1,"yier")
    if two: s.add_player(2,"bubu")
    s.begin_run(); return s

func begin(s):
    s.core.carrier=1; assert(s.place_core(1)); s.spawn_clock=999

func advance(s, seconds: float):
    for i in range(ceili(seconds*30)): s.step(1.0/30)

func _initialize():
    run.call_deferred()

func run():
    var s=make(true)
    advance(s,90); assert(s.phase=="deploy" and s.wave==0 and s.enemies.is_empty())
    var holder: int=s.core.carrier
    assert(not s.place_core(2 if holder==1 else 1))
    s.set_input(holder,Vector2.RIGHT); s.step(.1)
    assert(s.place_core(holder)); assert(s.clock==30 and s.core.placed)
    for w in range(1,7):
        assert(s.wave==w and s.clock==s.DB.WAVE_SECONDS[w-1])
        s.enemies.clear(); s.boss_defeated=true; s.clock=.01; s.step(.02)
        assert(s.phase=="camp" and s.round_no==1 and s.wave==w)
        advance(s,3); assert(s.phase=="camp" and s.wave==w)
        assert(s.core_shop_open()==(w==6))
        for p in s.players.values():
            assert(p.core_tokens==(1 if w==6 else 0))
            assert(("core_hp" in p.stock)==(w==6))
            if w<6:
                p.stock.append("core_hp"); p.coins=999
                assert(not s.buy(p.id,"core_hp") and not s.choose_core(p.id,"core_hp"))
            while p.pending>0: assert(s.choose_upgrade(p.id,p.offers[0]))
            if w==6: assert(s.choose_core(p.id,"core_attack"))
        s.ready_player(1); assert(s.phase=="camp")
        s.ready_player(1); assert(not s.players[1].ready)
        s.ready_player(1); assert(s.phase=="camp")
        s.ready_player(2); assert(s.phase=="battle")
    assert(s.round_no==2 and s.wave==1 and s.clock==30)
    print("EVERY_WAVE_CAMP_BOTH_READY_CANCEL_BOSS_CORE_GATE_NEXT_ROUND_PASS")
    s=make(true); begin(s)
    var p=s.players[1]; var partner=s.players[2]
    partner.pos=p.pos+Vector2(45,0); partner.down=true; partner.hp=0
    advance(s,4.8); assert(partner.down and partner.revive>4.5)
    p.invuln=0; s.hurt_player(p,1); assert(partner.revive==0)
    advance(s,5.5); assert(not partner.down and partner.hp>0)
    p.down=true; partner.down=true; p.hp=0; partner.hp=0
    advance(s,9.5); assert(p.down and partner.down and s.phase=="battle")
    advance(s,.7); assert(not p.down and not partner.down)
    p.down=true; partner.down=true; s.hurt_core(100000)
    assert(s.phase=="result")
    print("RESCUE_5S_INTERRUPT_DOUBLE_DOWN_10S_CORE_FAILURE_PASS")
    s=make(true); begin(s); p=s.players[1]; partner=s.players[2]
    s.spawn_enemy("sprout",p.pos+Vector2(170,0)); s.enemies[0].age=1
    s.create_building(1,"turret",p.pos+Vector2(130,80))
    s.projectile(p.pos+Vector2(-300,0),Vector2(70,0),5,0,"acorn",10)
    p.items=["world"]; p.equipment.hand=""; assert(s.use_item(1,0)); assert(p.items.is_empty())
    var before=s.enemies[0].pos; var other_pos=partner.pos; var shot_pos=s.shots[0].pos; var core_hp=s.core.hp; var time=s.clock; var turret_timer=s.buildings[0].timer
    for i in range(120): s.set_input(1,Vector2.RIGHT); s.set_input(2,Vector2.RIGHT); s.step(1.0/30)
    assert(p.pos.x>other_pos.x and partner.pos==other_pos and s.enemies[0].pos==before)
    assert(s.shots[0].pos==shot_pos and s.clock==time and s.core.hp==core_hp and s.buildings[0].timer==turret_timer)
    advance(s,1.2); assert(s.time_stop==0 and s.clock<time)
    print("WORLD_5S_ONLY_OWNER_MOVE_ATTACK_ENTITY_FREEZE_PASS")
    s=make(); p=s.players[1]; p.coins=10000
    for key in C.BUILDINGS:
        p.stock.append(key); assert(s.buy(1,key))
    var i=0
    for key in C.BUILDINGS:
        var at=Vector2(950+(i%5)*75,600+(i/5)*90); p.pos=at-Vector2(0,90)
        assert(s.build(1,key,at)); i+=1
    assert(s.buildings.size()==10)
    assert(not s.build(1,"turret",Vector2.INF)); assert(not s.build(1,"turret",Vector2(100,100)))
    s.core.carrier=1; p.pos=Vector2(1080,850); assert(s.place_core(1)); s.spawn_clock=999
    s.spawn_enemy("sprout",s.buildings[1].pos+Vector2(70,0)); s.enemies[0].age=1; s.enemies[0].hp=1000
    advance(s,2); assert(s.enemies[0].hp<1000)
    print("ALL_BUILDINGS_PURCHASE_PLACE_COLLISION_ATTACK_PASS")
    # Every weapon executes a real attack; no UI-only weapons.
    for key in s.DB.WEAPONS:
        var w=make(); begin(w); var player=w.players[1]
        player.weapons={key:1}; player.equipment.hand=key
        w.spawn_enemy("mushroom",player.pos+Vector2(78,0)); var enemy=w.enemies[0]; enemy.hp=10000; enemy.age=1; enemy.speed=0
        advance(w,3)
        assert(enemy.hp<10000,"Weapon did not damage: "+key)
    print("ALL_13_WEAPON_REAL_DAMAGE_PASS")
    s=make(); p=s.players[1]; p.coins=10000
    for key in C.GEAR: p.stock.append(key); assert(s.buy(1,key))
    assert(s.equip_gear(1,"charm","skill_stone")); assert(s.item_capacity(p)==4)
    p.items.append("world"); assert(not s.equip_gear(1,"charm","purse")); p.items.pop_back()
    assert(not s.equip_gear(1,"body","magnet_cap"))
    assert(not s.equip(1,"head","ribbon"))
    p.stock.append("core_hp"); assert(not s.buy(1,"core_hp"))
    s.wave=6; s.enter_camp()
    for key in C.CORE_UPGRADES: assert(s.buy(1,key))
    assert(s.core.attack>0 and s.core.vine>0 and s.core.max_hp==1100 and s.core.guard>.1)
    s.phase="deploy"; s.wave=0; begin(s); assert(not s.equip(1,"hand","wand"))
    for key in C.ITEMS:
        s.buildings.clear(); s.zones.clear()
        p.items=[key]; p.item_cd=0; s.time_stop=0; p.equipment.offhand="wand"
        if key=="dice": s.phase="camp"
        assert(s.use_item(1,0),"Item rejected: "+key); assert(p.items.is_empty())
        s.phase="battle"; p.pos+=Vector2(8,5)
    var copy=Sim.new(); copy.restore(bytes_to_var(var_to_bytes(s.snapshot())))
    assert(copy.core==s.core and copy.buildings==s.buildings and copy.players[1].items==p.items and copy.time_stop==s.time_stop)
    print("GEAR_ITEMS_CORE_GROWTH_SNAPSHOT_PASS")
    # Tactical roles and Boss phase are behavioral checks, not just catalog entries.
    s=make(); begin(s); p=s.players[1]
    s.create_building(1,"turret",p.pos+Vector2(130,0))
    for key in ["termite","leech","crow","mole","charger","shield_bug","bomber","healer","mimic","moth","snail"]: s.spawn_enemy(key,p.pos+Vector2(160,160))
    assert(s.target_for(s.enemies[0]).has("owner")); assert(s.target_for(s.enemies[2])==s.core)
    var boss=s.enemies[-1]; boss.age=2; boss.hp=boss.max_hp*.3; boss.cooldown=0
    s.step_enemy(boss,.1); assert(boss.warning>0)
    for e in s.enemies: e.age=1; s.step_enemy(e,.1)
    print("TACTICAL_ENEMIES_SNAIL_BOSS_PHASE_PASS")
    print("ALL_GARDEN_SYSTEM_CHECKS_PASS")
    quit()
