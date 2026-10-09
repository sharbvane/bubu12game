extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Bear=preload("res://characters/bear_visual.gd")
const Pose=preload("res://characters/pose.gd")
const Session=preload("res://multiplayer/session.gd")

func _initialize():
    var sim=Sim.new(45); sim.add_player(1,"yier")
    sim.begin_run()
    assert(not sim.equip(1,"head","ribbon")); assert(not sim.equip(1,"body","ribbon"))
    assert(not sim.equip(1,"hand","needle")); assert(not sim.equip(99,"head","ribbon"))
    assert(sim.place_core(1))
    assert(not sim.equip(1,"head","flower_hat"))
    var p: Dictionary=sim.players[1]
    var start: Vector2=p.pos
    for i in range(120):
        sim.set_input(1,Vector2.RIGHT if i%2==0 else Vector2.LEFT)
        sim.step(1.0/30)
        var pivot=Bear.facing_transform(p.face)*Vector2.ZERO
        assert(pivot==Vector2.ZERO)
        assert(p.pos.distance_to(start)<=p.speed/30+0.001)
    sim.enemies.clear(); sim.shots.clear(); p.actions.clear(); p.timers.clear()
    p.weapons={"wand":1}; sim.spawn_enemy("mushroom",p.pos+Vector2(100,50)); sim.enemies[0].age=1
    assert(sim.attack(p,"wand")); assert(sim.shots.is_empty())
    var action: Dictionary=p.actions.hand
    var enemy_hp: float=sim.enemies[0].hp
    sim.step(0.02); assert(sim.enemies[0].hp==enemy_hp and sim.shots.is_empty())
    sim.step(0.08); assert(p.actions.hand.released and not sim.shots.is_empty())
    var origin=Pose.muzzle(p,"hand",p.actions.hand)
    assert(origin.distance_to(p.pos)<100)
    # Handedness is a mirror at one pivot, never a world-position translation.
    var point=Vector2(23,-17)
    assert((Bear.facing_transform(-1)*point).is_equal_approx(Vector2(-23,-17)))
    var copy=Sim.new(); copy.restore(bytes_to_var(var_to_bytes(sim.snapshot())))
    assert(copy.players[1].equipment==p.equipment)
    assert(copy.players[1].actions==p.actions)
    var net=Session.new(); net.mode="client"
    net.model=sim
    net.apply_cosmetics(1,{"head":"ribbon","body":"overalls"}); assert(p.outfit=="plain")
    net.apply_cosmetics(1,{"outfit":"../../invalid"}); assert(p.outfit=="plain")
    for outfit in sim.DB.COSTUMES:
        net.apply_cosmetics(1,{"outfit":outfit}); assert(p.outfit==outfit)
    net.apply_cosmetics(1,{"outfit":"pajamas"})
    net.model=Sim.new()
    var raw=var_to_bytes(sim.snapshot()); var packet=raw.compress(FileAccess.COMPRESSION_ZSTD)
    var half=packet.size()/2
    net.receive_state_chunk(1,0,2,packet.slice(0,half),raw.size())
    assert(net.received_states==0)
    net.receive_state_chunk(1,1,2,packet.slice(half),raw.size())
    assert(net.received_states==1 and net.model.players[1].equipment==p.equipment)
    assert(net.model.players[1].outfit=="pajamas")
    net.receive_state_chunk(1,1,2,packet.slice(half),raw.size())
    assert(net.received_states==1)
    net.receive_state_chunk(2,0,2,packet.slice(0,half),raw.size())
    net.receive_state_chunk(3,0,2,packet.slice(0,half),raw.size())
    net.receive_state_chunk(2,1,2,packet.slice(half),raw.size())
    assert(net.received_states==1)
    net.receive_state_chunk(3,1,2,packet.slice(half),raw.size())
    assert(net.received_states==2)
    net.free()
    print("RIG_TURN_PIVOT_ATTACK_TIMING_EQUIPMENT_PASS")
    quit()
