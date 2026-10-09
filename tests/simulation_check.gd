extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
func _initialize():
    run.call_deferred()
func run():
    for setup in [[1,"yier"],[1,"bubu"],[2,"yier"]]:
        var count: int=setup[0]
        var s=Sim.new(231); s.add_player(1,setup[1])
        if count==2: s.add_player(2,"bubu")
        s.begin_run(); s.core.carrier=1
        var center: Vector2=s.players[1].pos
        for p in s.players.values():
            var key="needle" if p.character=="yier" else "wand"
            p.stock.append(key); assert(s.buy(p.id,key))
            for b in ["turret","fountain"]:
                p.stock.append(b); p.bought.erase(b)
                if p.coins>=s.C.BUILDINGS[b].price: s.buy(p.id,b)
        var angle=0.0
        for p in s.players.values():
            angle=0
            for key in p.inventory.keys():
                while p.inventory[key]>0:
                    var at=center+Vector2.from_angle(angle)*(155 if p.id==1 else 265)
                    p.pos=at-Vector2(0,60)
                    assert(s.build(p.id,key,at)); angle+=.7
        s.players[1].pos=center; assert(s.place_core(1))
        var peak=0
        var last_wave=0
        var camps: Array=[]
        for tick in range(9000):
            if s.phase=="camp":
                camps.append(s.wave)
                if s.wave==6: break
                for p in s.players.values():
                    assert(p.core_tokens==0)
                    while p.pending>0: assert(s.choose_upgrade(p.id,p.offers[0]))
                    s.ready_player(p.id)
            if s.phase!="battle": break
            if s.wave!=last_wave:
                last_wave=s.wave; print("DEFENSE_WAVE ",count,"/",s.wave," core=",s.core.hp)
            for p in s.players.values():
                if p.down: continue
                var targets=s.enemies.filter(func(e):return e.hp>0)
                var move=Vector2.ZERO
                if not targets.is_empty():
                    targets.sort_custom(func(a,b):return a.pos.distance_to(s.core.pos)<b.pos.distance_to(s.core.pos))
                    var target=targets[0]
                    var offset: Vector2=target.pos-p.pos
                    var range_target=90 if p.character=="bubu" else 170
                    if target.kind=="snail": range_target=160
                    if offset.length()>range_target: move=offset.normalized()
                    elif offset.length()<65: move=-offset.normalized()
                elif p.pos.distance_to(s.core.pos)>150: move=(s.core.pos-p.pos).normalized()
                s.set_input(p.id,move)
                if p.skill_cd<=0 and (not targets.is_empty() or p.hp<p.max_hp*.8): s.use_skill(p.id)
            s.step(1.0/30); peak=maxi(peak,s.enemies.size())
        print("FULL_DEFENSE players=",count," phase=",s.phase," round=",s.round_no," core=",s.core.hp," boss_defeated=",s.boss_defeated," kills=",s.kills," peak=",peak)
        assert(camps==[1,2,3,4,5,6],"Every wave must enter supply")
        assert(s.phase=="camp" and s.round_no==1 and s.wave==6 and s.core.hp>0,"First full defense did not survive")
        assert(s.boss_defeated,"First Boss was not defeated")
        for p in s.players.values():
            while p.pending>0: assert(s.choose_upgrade(p.id,p.offers[0]))
            assert(s.choose_core(p.id,"core_attack")); s.ready_player(p.id)
        assert(s.phase=="battle" and s.round_no==2 and s.wave==1 and s.clock==30)
    print("FULL_SOLO_AND_COOP_DEFENSE_LOOP_PASS")
    quit()
