extends SceneTree
const Main=preload("res://scripts/main.gd")
var game: Node

func _initialize():
    root.size=Vector2i(1280,720)
    game=Main.new(); root.add_child.call_deferred(game)
    run.call_deferred()

func find_button(text: String) -> Button:
    for node in game.ui.layer.find_children("*","Button",true,false):
        if node.text.strip_edges().begins_with(text): return node
    return null

func touch(index: int, at: Vector2, pressed: bool):
    var event=InputEventScreenTouch.new(); event.index=index; event.position=at; event.pressed=pressed
    Input.parse_input_event(event)

func tap(text: String, index: int=0):
    var b=find_button(text)
    assert(b!=null,"Missing button: "+text)
    var at=b.get_global_rect().get_center()
    touch(index,at,true)
    await process_frame
    touch(index,at,false)
    await create_timer(0.25).timeout

func run():
    create_timer(35).timeout.connect(func(): quit(2))
    await create_timer(0.3).timeout
    DisplayServer.window_move_to_foreground()
    await create_timer(.15).timeout
    await tap("加入房间")
    assert(game.session.model.phase=="join","Touch cannot open room list")
    await tap("返回")
    await tap("角色外观")
    var outfit_button=game.ui.wardrobe_buttons.garden
    var outfit_at=outfit_button.get_global_rect().get_center()
    touch(0,outfit_at,true); await process_frame; touch(0,outfit_at,false)
    await create_timer(.1).timeout
    assert(game.ui.profile.outfit=="garden")
    await tap("查看侧面")
    assert(game.ui.profile.facing=="side")
    game.ui.wardrobe=false; game.ui.last_phase=""
    await create_timer(.2).timeout
    await tap("开始单人")
    assert(game.session.model.phase=="deploy")
    await tap("放下大甜莓")
    assert(game.session.model.phase=="battle","Touch cannot start game")
    touch(0,Vector2(140,590),true)
    var drag=InputEventScreenDrag.new(); drag.index=0; drag.position=Vector2(198,590); drag.relative=Vector2(58,0)
    Input.parse_input_event(drag)
    await process_frame
    assert(game.ui.touch.direction.x>0.8)
    await tap("甜心",1)
    assert(game.session.model.players[1].skill_cd>0,"Second finger cannot activate skill while moving")
    assert(game.ui.touch.direction.x>0.8,"Skill finger release stopped joystick")
    touch(0,Vector2(198,590),false)
    await process_frame
    assert(game.ui.touch.direction==Vector2.ZERO)
    await tap("暂停")
    assert(game.session.model.phase=="paused")
    await tap("继续守护")
    assert(game.session.model.phase=="battle")
    game.ui.build_button.pressed.emit()
    await create_timer(.08).timeout
    assert(game.ui.build_mode and game.arena.build_key=="fence")
    var site=game.session.model.snap_site(game.session.model.players[1].pos+Vector2(128,0))
    touch(0,site-game.arena.camera,true); await process_frame; touch(0,site-game.arena.camera,false)
    await process_frame
    assert(game.arena.build_target==site and game.session.model.site_state(1,site)=="valid")
    game.ui.place_build()
    assert(game.session.model.buildings[-1].pos==site)
    print("UI_TOUCH_GRID_BUILD_SNAP_PASS")
    var m=game.session.model
    m.add_player(2,"bubu"); m.round_no=2; m.enter_camp()
    await create_timer(.3).timeout
    var layer_id=game.ui.layer.get_instance_id()
    assert(not game.ui.category_buttons.has("核心"))
    for slot in game.ui.gear_buttons.values(): assert(slot.get_meta("picture").texture!=null)
    assert(game.ui.building_slots.size()==14)
    game.ui.building_slots.turret.pressed.emit()
    await create_timer(.1).timeout
    assert(game.ui.build_key=="turret" and game.ui.camp_open)
    var card=game.ui.upgrade_cards[0]
    var card_id=card.get_instance_id()
    var at=card.get_global_rect().get_center()
    touch(0,at,true); await process_frame; touch(0,at,false)
    await create_timer(.2).timeout
    assert(game.ui.layer.get_instance_id()==layer_id and game.ui.upgrade_cards[0].get_instance_id()==card_id)
    assert(game.ui.layer.modulate.a==1.0,"Local upgrade restarted a page fade")
    game.ui.shop_category="建筑"; game.ui.camp_signature=""
    var p=m.players[2]; p.coins=1000; p.stock=["fence"]
    assert(m.buy(2,"fence")); m.revision+=1
    await create_timer(.2).timeout
    assert(game.ui.layer.get_instance_id()==layer_id and game.ui.shop_category=="建筑" and game.ui.layer.modulate.a==1)
    p=m.players[1]; p.coins=1000; p.stock=["turret"]; p.ui_revision+=1
    await create_timer(.1).timeout
    var buy_button=game.ui.product_cards[0]
    var button_id=buy_button.get_instance_id()
    at=buy_button.get_global_rect().get_center()
    touch(0,at,true); await process_frame; touch(0,at,false)
    await create_timer(.2).timeout
    assert("turret" in p.bought)
    assert(game.ui.layer.get_instance_id()==layer_id and game.ui.product_cards[0].get_instance_id()==button_id)
    var detail=game.ui.gear_buttons.hand
    at=detail.get_global_rect().get_center()
    touch(0,at,true); await create_timer(.55).timeout
    assert(is_instance_valid(game.ui.detail_popup))
    touch(0,at,false); await create_timer(.1).timeout
    assert(not is_instance_valid(game.ui.detail_popup))
    print("UI_LONG_PRESS_DETAILS_RELEASE_PASS")
    print("UI_LOCAL_AND_REMOTE_SHOP_NO_REBUILD_NO_FLICKER_PASS")
    m.wave=0; m.enter_camp(); game.ui.last_phase=""
    await create_timer(.2).timeout
    assert(game.ui.category_buttons.has("核心"))
    assert(game.ui.category_buttons.has("技能"))
    game.ui.category_buttons["核心"].pressed.emit()
    await create_timer(.1).timeout
    assert(game.ui.product_cards[0].get_meta("key")=="core_hp")
    var core_hp=m.core.max_hp
    game.ui.product_cards[0].pressed.emit()
    await process_frame
    assert(m.core.max_hp==core_hp+150 and m.players[1].core_tokens==0)
    game.ui.reroll_button.pressed.emit(); await create_timer(.1).timeout
    assert(game.ui.product_cards[0].get_meta("key")=="core_aura")
    game.ui.category_buttons["技能"].pressed.emit(); await create_timer(.1).timeout
    assert(game.ui.product_cards[0].get_meta("key")=="skill_power")
    game.ui.product_cards[0].pressed.emit(); await process_frame
    assert(m.players[1].skill_tokens==0 and m.players[1].skill_power>1)
    print("UI_WARDROBE_ICON_SLOTS_CORE_TAB_FREE_PICK_PAGING_PASS")
    game.sound.shutdown()
    print("UI_TOUCH_MENU_MULTITOUCH_SKILL_PAUSE_PASS")
    quit()
