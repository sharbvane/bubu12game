extends SceneTree
const Bear=preload("res://characters/bear_visual.gd")
const Enemy=preload("res://enemies/enemy_visual.gd")
const Pose=preload("res://characters/pose.gd")
const Sim=preload("res://scripts/simulation.gd")

func _initialize():
    var sim=Sim.new(); sim.add_player(1,"yier")
    var p: Dictionary=sim.players[1]
    var bear=Bear.new(); bear.data=p; root.add_child(bear); bear._ready()
    for character in ["yier","bubu"]:
        for state in ["idle","move","melee","ranged","hurt","dodge","down","build","item","skill","victory","side_idle","side_move","back_idle","back_move"]:
            var key=character+"_"+state
            assert(bear.animation_sheets.has(key),"Missing animation "+key)
            assert(bear.animation_sheets[key].get_size()==Vector2(1024,128),"Wrong frame layout "+key)
        for outfit in ["casual","garden","adventure","pajamas","spring","magic"]:
            for state in ["idle","move","side_move","back_move"]:
                var key=character+"_"+outfit+"_"+state
                assert(bear.animation_sheets.has(key),"Missing costume animation "+key)
                assert(bear.animation_sheets[key].get_size()==Vector2(1024,128),"Wrong costume frame layout "+key)
    p.actions.hand={"seq":1,"weapon":"spoon","time":0.0,"duration":.3,"hit_at":.12,"direction":Vector2.RIGHT}
    bear.visual_actions=p.actions.duplicate(true)
    assert(Pose.animation_state(p)=="melee" and bear.frame_for("melee")==0)
    bear.visual_actions.hand.time=.12
    assert(bear.frame_for("melee")==3,"Hit and sprite impact must coincide")
    bear.visual_actions.hand.time=.29
    assert(bear.frame_for("melee")==7)
    p.actions.clear(); p.dodge_time=.45
    assert(Pose.animation_state(p)=="dodge" and bear.frame_for("dodge")==0)
    p.dodge_time=0; p.build_time=.5
    assert(Pose.animation_state(p)=="build")
    p.build_time=0; p.item_time=.5
    assert(Pose.animation_state(p)=="item")
    p.item_time=0; p.down=true; p.down_time=.9
    assert(Pose.animation_state(p)=="down" and bear.frame_for("down")==7)
    var enemy=Enemy.new(); sim.spawn_enemy("sprout",Vector2(400,400)); enemy.data=sim.enemies[-1]
    root.add_child(enemy); enemy._process(0)
    assert(enemy.sheets.has("move") and enemy.sheets.has("attack"))
    assert(enemy.sheets.move.get_size()==Vector2(768,96))
    for key in ["wasp_move","wasp_attack","mushroom_move","mushroom_attack","shade_move","shade_attack","crystal_crab_move","crystal_crab_attack","bee_move","root_brute_move","moth_move","crow_move","termite_attack","acorn_attack"]:
        assert(load("res://资产/动画/"+key+".png").get_size()==Vector2(768,96),"Wrong enemy frame layout "+key)
    for boss in ["snail","queen_wasp","moon_treant"]:
        for state in ["move","attack","down"]:
            var key=boss+"_"+state
            assert(load("res://资产/动画/"+key+".png").get_size()==Vector2(1536,192),"Wrong boss frame layout "+key)
    for kind in ["spoon_swing","wand_fire","needle_fire","petal_spin","berry_impact","boss_slam"]:
        var fx=load("res://资产/动画/fx_"+kind+".png")
        assert(fx!=null and fx.get_size()==Vector2(1024,128),"Missing FX "+kind)
    for key in ["dodge_time","build_time","item_time","down_time"]: p.erase(key)
    p.down=false; sim.step_player(p,.016)
    assert(p.has("dodge_time") and p.has("build_time") and p.has("item_time"),"Older v1.4 saves must load")
    print("V150_FRAMES_DIRECTION_ATTACK_SYNC_PASS")
    quit()
