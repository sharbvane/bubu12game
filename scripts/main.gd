extends Node
const Session=preload("res://multiplayer/session.gd")
const Arena=preload("res://scripts/arena_view.gd")
const Interface=preload("res://ui/interface.gd")
const Sound=preload("res://scripts/sound.gd")
var session: Node
var arena: Node2D
var ui: Control
var sound: Node
var test_mode=""
var test_seconds=0.0
var test_stage=0
var capture=""
var net_seen: Dictionary={}
var camp_layer_id=0

func _ready():
    session=Session.new(); session.name="Session"; add_child(session); session.model.phase="menu"
    sound=Sound.new(); add_child(sound)
    arena=Arena.new(); arena.session=session; arena.feedback=sound; add_child(arena)
    var canvas=CanvasLayer.new(); add_child(canvas)
    ui=Interface.new(); ui.game=self; ui.session=session; canvas.add_child(ui)
    for argument in OS.get_cmdline_user_args():
        if OS.has_feature("editor"):
            if argument.begins_with("--test="): test_mode=argument.trim_prefix("--test=")
            if argument.begins_with("--capture="): capture=argument.trim_prefix("--capture=")
    if test_mode=="host": session.host("yier"); session.apply_cosmetics(1,{"outfit":"casual"})
    elif test_mode=="client": session.cosmetics.bubu={"outfit":"garden"}; session.browse()
    elif test_mode=="preview": session.solo("yier")
    elif test_mode in ["camp","corecamp"]:
        session.solo("yier"); session.model.reward(50,65)
        if test_mode=="corecamp": session.model.round_no=2; session.model.wave=0
        else: session.model.wave=1
        session.model.enter_camp(); ui.camp_open=true
        if test_mode=="corecamp": ui.shop_category="核心"
    elif test_mode=="wardrobe": ui.wardrobe=true
    elif test_mode=="rooms": session.browse()
    elif test_mode=="combat":
        session.solo("bubu"); session.model.add_player(2,"yier"); session.model.core.carrier=1
        session.model.place_core(1)
        var center: Vector2=session.model.core.pos
        session.model.players[1].pos=center+Vector2(-130,110)
        session.model.players[2].pos=center+Vector2(130,105)
        for i in range(8): session.model.create_building(1,["fence","turret","mortar","frost","fountain","scarecrow","repair","spikes"][i],center+Vector2.from_angle(i*TAU/8)*200)
        session.model.spawn_enemy("snail",center+Vector2(260,-190))
        for i in range(12): session.model.spawn_enemy(["charger","crow","mole","healer"][i%4],center+Vector2.from_angle(i*TAU/12)*370)
    elif test_mode=="v140combat":
        session.solo("bubu"); session.model.core.carrier=1; session.model.place_core(1)
        session.model.round_no=3; session.model.wave=5; session.model.begin_wave()
        var p=session.model.players[1]; p.weapons.root_hammer=1; p.equipment.hand="root_hammer"
        for i in range(8): session.model.spawn_enemy(["shade","crystal_crab","spore_bat","root_brute"][i%4],p.pos+Vector2.from_angle(i*TAU/8)*280)
        p.inventory.root_tower=2; ui.build_key="root_tower"; ui.build_mode=true
        arena.build_target=session.model.snap_site(p.pos+Vector2(128,0))
    if not capture.is_empty(): capture_screen.call_deferred()

func capture_screen():
    await get_tree().create_timer(2.0).timeout
    await RenderingServer.frame_post_draw
    DirAccess.make_dir_recursive_absolute("res://tests/output")
    get_viewport().get_texture().get_image().save_png("res://tests/output/"+capture+".png")
    print("CAPTURE_OK ",capture)
    sound.shutdown()
    await get_tree().create_timer(0.08).timeout
    get_tree().quit()

func _physics_process(dt: float):
    session.tick(dt,ui.touch.movement() if ui.touch!=null else Vector2.ZERO)
    if not test_mode.is_empty(): test_tick(dt)

func _unhandled_key_input(event: InputEvent):
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode==KEY_SPACE: session.act("skill")
        elif event.physical_keycode==KEY_ESCAPE: session.act("pause")
        elif event.physical_keycode==KEY_SHIFT: session.act("dash")
        elif event.physical_keycode in [KEY_1,KEY_2,KEY_3,KEY_4]: session.act("item",str(event.physical_keycode-KEY_1))
        elif event.physical_keycode==KEY_E: session.act("place_core")
        elif event.physical_keycode==KEY_B: ui.place_build()

func _notification(what: int):
    if what==NOTIFICATION_APPLICATION_PAUSED and session!=null and session.model.phase=="battle": session.act("pause")

func test_tick(dt: float):
    test_seconds+=dt
    if test_mode=="host":
        if test_seconds>2.5 and session.model.phase=="lobby" and session.model.players.size()==2: session.act("start")
        if session.model.phase=="deploy" and test_seconds>3:
            var id=session.model.core.carrier
            session.model.place_core(id)
        if test_seconds>5 and test_stage==0 and session.model.phase=="battle":
            var remote=session.model.players.values().filter(func(p):return p.id!=1)[0]
            assert(remote.pos.distance_to(session.model.DB.ARENA/2)>50)
            print("NET_HOST_REMOTE_INPUT_CORE_DEPLOY_OK")
            session.model.clock=0; session.model.step(.01); remote.stock.append("magnet_cap"); test_stage=1
        if test_stage in [1,6] and session.model.phase=="camp":
            var p=session.model.players[1]
            if p.pending>0: session.act("upgrade",p.offers[0])
            elif p.core_tokens>0: session.act("core_growth","core_regen")
            elif p.skill_tokens>0: session.act("skill_growth","skill_power")
            elif not p.ready: session.act("ready")
            if p.ready and session.model.phase=="camp": net_seen["wait_partner"]=true
        if test_stage==1 and session.model.phase=="battle":
            assert(session.model.wave==2 and session.model.round_no==1)
            print("NET_ORDINARY_CAMP_BOTH_READY_NEXT_WAVE_OK")
            session.model.wave=6; session.model.clock=120
            session.model.spawn_enemy("snail",session.model.core.pos+Vector2(0,-420))
            session.model.enemies[-1].hp=0; session.model.cleanup_enemies()
            assert(session.model.phase=="boss_outro")
            session.model.outro_time=1.0; test_stage=6
        if session.model.round_no==2 and session.model.phase=="battle" and test_stage==6:
            var remote=session.model.players.values().filter(func(p):return p.id!=1)[0]
            assert(remote.gear.head=="magnet_cap")
            assert(session.model.buildings.size()>=1)
            assert(session.model.core.attack>0 and session.model.core.regen>1 and session.model.wave==1)
            assert(remote.outfit=="garden" and net_seen.has("wait_partner"))
            print("NET_CORE_BUILD_GEAR_UPGRADE_READY_SYNC_OK"); test_stage=2
            session.model.players[1].items=["world"]; session.model.players[1].item_cd=0
            assert(session.model.use_item(1,0))
        if test_seconds>12.5 and test_stage==2:
            for p in session.model.players.values(): p.down=true; p.hp=0
            session.model.revive_clock=1; test_stage=3
        if test_seconds>14 and test_stage==3 and session.model.players.values().all(func(p):return not p.down):
            print("NET_TIME_STOP_DOUBLE_DOWN_REVIVAL_OK"); test_stage=4
        if test_seconds>14.5 and test_stage==4:
            session.model.round_no=3; session.model.wave=5; session.model.begin_wave(); test_stage=7
        if test_seconds>15.6 and test_stage==7:
            var bosses=session.model.enemies.filter(func(e):return e.kind=="moon_treant")
            assert(bosses.size()==1)
            bosses[0].hp=0; session.model.cleanup_enemies(); session.model.outro_time=1.0; test_stage=8
        if test_seconds>18 and test_stage==8 and session.model.phase=="result":
            print("NET_ROUND3_BOSS_OUTRO_RESULT_OK"); test_stage=5
        if test_seconds>22:
            print("NET_HOST_OK"); get_tree().quit(0 if test_stage==5 else 2)
    elif test_mode=="client":
        if session.model.phase=="join":
            for id in session.discovery.rooms:
                if session.discovery.rooms[id].joinable: session.join_discovered(id,"bubu"); print("NET_AUTODISCOVERY_JOIN_OK"); break
        ui.touch.direction=Vector2(.7,.3)
        if session.model.time_stop>0: net_seen["freeze"]=true
        if session.model.phase=="boss_outro": net_seen["boss_outro"]=true
        if session.model.round_no==3 and session.model.enemies.any(func(e):return e.kind=="moon_treant" and e.hp>0): net_seen["round3_boss"]=true
        if session.model.round_no==3 and session.model.phase=="boss_outro": net_seen["round3_outro"]=true
        if session.model.players.size()==2 and session.model.players.values().all(func(p):return p.down): net_seen["down"]=true
        if net_seen.has("down") and session.model.players.values().all(func(p):return not p.down): net_seen["revived"]=true
        if session.model.players.has(session.local_id()):
            var p=session.model.players[session.local_id()]
            if session.model.phase=="camp":
                net_seen["core_camp" if session.model.core_shop_open() else "ordinary_camp"]=true
                assert(session.model.players[1].outfit=="casual" and p.outfit=="garden")
                if session.model.core_shop_open(): assert("core_attack" in p.stock)
                else: assert(p.core_tokens==0 and not "core_attack" in p.stock)
            if session.model.phase=="battle" and test_stage==0:
                session.build("turret",p.pos+Vector2(110,40)); session.act("item","0"); test_stage=1
            if session.model.phase=="camp" and fmod(test_seconds,.3)<dt:
                if p.pending>0: session.act("upgrade",p.offers[0])
                elif p.core_tokens>0: session.act("core_growth","core_attack")
                elif p.skill_tokens>0: session.act("skill_growth","skill_haste")
                elif p.gear.head!="magnet_cap":
                    if "magnet_cap" in p.stock: session.act("buy","magnet_cap")
                    elif "magnet_cap" in p.owned: session.act("gear","head:magnet_cap")
                    else: session.act("reroll")
                elif not p.ready: session.act("ready")
        if test_seconds>20.5:
            var success=session.received_states>90 and session.model.round_no==3 and session.model.phase=="result" and session.model.players.size()==2 and net_seen.has("freeze") and net_seen.has("down") and net_seen.has("revived") and net_seen.has("ordinary_camp") and net_seen.has("core_camp") and net_seen.has("boss_outro") and net_seen.has("round3_boss") and net_seen.has("round3_outro")
            print("NET_NEW_SYSTEM_STATES ",net_seen)
            print("NET_CLIENT_OK snapshots=",session.received_states," round=",session.model.round_no," result=",session.model.result)
            get_tree().quit(0 if success else 2)
