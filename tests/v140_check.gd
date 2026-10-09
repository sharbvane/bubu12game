extends SceneTree
const Sim=preload("res://scripts/simulation.gd")
const Session=preload("res://multiplayer/session.gd")
const C=preload("res://scripts/garden_content.gd")

func _initialize(): run.call_deferred()

func make(two: bool=false):
    var s=Sim.new(140)
    s.add_player(1,"yier")
    if two: s.add_player(2,"bubu")
    s.begin_run(); s.core.carrier=1
    assert(s.place_core(1))
    s.spawn_clock=999
    return s

func run():
    var s=make(true)
    var p=s.players[1]
    var site=s.snap_site(p.pos+Vector2(125,0))
    assert(s.site_state(1,site)=="valid")
    assert(s.build(1,"fence",site))
    assert(s.buildings[-1].pos==site and s.site_state(1,site)=="occupied")
    assert(not s.build(1,"fence",p.pos+Vector2(400,0)))
    var saved: Dictionary={}
    var defeat_count=0
    for round_index in range(1,4):
        for wave_index in range(1,7):
            assert(s.phase=="battle" and s.round_no==round_index and s.wave==wave_index)
            if wave_index==6:
                assert(s.clock==120)
                var bosses=s.enemies.filter(func(e):return e.kind==s.DB.BOSS_KINDS[round_index-1])
                assert(bosses.size()==1)
                s.spawn_enemy("sprout",bosses[0].pos+Vector2(120,0))
                bosses[0].hp=0
                s.cleanup_enemies()
                assert(s.phase=="boss_outro" and s.outro_time==10 and s.enemies.size()==1)
                assert(s.enemies[0].defeated and s.drops.any(func(d):return d.has("item")))
                s.step(9.5); assert(s.phase=="boss_outro")
                s.step(.6)
                defeat_count+=1
            else:
                s.enemies.clear(); s.spawn_clock=999; s.clock=.01; s.step(.02)
            if round_index==3 and wave_index==6: break
            assert(s.phase=="camp")
            assert(s.core_shop_open()==(wave_index==6))
            assert(s.round_no==round_index+1 if wave_index==6 else s.round_no==round_index)
            assert(s.wave==0 if wave_index==6 else s.wave==wave_index)
            if wave_index==6:
                assert(s.checkpoint_round==round_index+1)
                if round_index==1: saved=s.snapshot().duplicate(true)
            for player in s.players.values():
                while player.pending>0: assert(s.choose_upgrade(player.id,player.offers[0]))
                if player.core_tokens>0: assert(s.choose_core(player.id,"core_attack"))
                if player.skill_tokens>0: assert(s.choose_skill_growth(player.id,"skill_power"))
            s.ready_player(1); assert(s.phase=="camp")
            s.ready_player(2); assert(s.phase=="battle")
    assert(defeat_count==3 and s.phase=="result" and s.result=="守护成功")
    assert(s.checkpoint_round==4 and not saved.is_empty())
    print("THREE_ROUND_BOSS_120S_OUTRO_10S_DROPS_SUPPLY_READY_PASS")

    for weapon in ["bee_blade","hive_bow","prism_staff","root_hammer"]:
        var w=make(); var user=w.players[1]
        user.equipment.hand=weapon; user.equipment.offhand=""; user.weapons={weapon:1}
        w.spawn_enemy("mushroom",user.pos+Vector2(90,0))
        var enemy=w.enemies[0]; enemy.age=1; enemy.hp=10000; enemy.max_hp=10000; enemy.speed=0
        for tick in range(135): w.step(1.0/30)
        assert(enemy.hp<10000,"New weapon did not hit: "+weapon)
    print("FOUR_NEW_WEAPONS_REAL_DAMAGE_PASS")

    for kind in ["wasp","thornling","hedgehog","seedcaster","shade","crystal_crab","spore_bat","root_brute","queen_wasp","moon_treant"]:
        var e=make(); e.spawn_enemy(kind,e.players[1].pos+Vector2(200,0))
        assert(not e.enemies.is_empty() and e.enemies[-1].kind==kind)
        e.enemies[-1].age=1; e.enemies[-1].cooldown=0
        e.step_enemy(e.enemies[-1],.1)
    for building in ["beehive","wall","moon_lantern","root_tower"]:
        var b=make(); var at=b.snap_site(b.players[1].pos+Vector2(130,0))
        b.players[1].inventory[building]=1
        assert(b.build(1,building,at))
        assert(b.buildings[-1].kind==building and b.players[1].inventory[building]==0)
    print("NEW_ENEMIES_AND_BUILDINGS_ACTIVE_PASS")

    var old_exists=FileAccess.file_exists(Session.SAVE_PATH)
    var old_bytes=FileAccess.get_file_as_bytes(Session.SAVE_PATH) if old_exists else PackedByteArray()
    var session=Session.new(); root.add_child(session)
    session.model.restore(saved); session.last_saved_round=0; session.save_checkpoint()
    assert(session.has_save())
    assert(session.resume_solo())
    assert(session.model.round_no==2 and session.model.wave==0 and session.model.phase=="camp")
    assert(session.model.players[1].equipment==saved.players[1].equipment)
    assert(session.model.players[1].inventory==saved.players[1].inventory)
    assert(session.model.core==saved.core)
    assert(session.host_saved()==OK and session.model.phase=="lobby" and not session.pending_guest.is_empty())
    session.close(); session.queue_free()
    if old_exists:
        var f=FileAccess.open(Session.SAVE_PATH,FileAccess.WRITE); f.store_buffer(old_bytes); f.close()
    else: DirAccess.remove_absolute(ProjectSettings.globalize_path(Session.SAVE_PATH))
    print("CHECKPOINT_FILE_RESTORE_SOLO_HOST_GUEST_STATE_PASS")
    print("ALL_V140_SYSTEM_CHECKS_PASS")
    quit()
