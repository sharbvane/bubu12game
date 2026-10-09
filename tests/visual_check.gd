extends SceneTree
const Bear=preload("res://characters/bear_visual.gd")
const Sim=preload("res://scripts/simulation.gd")
var root_node: Node2D
var bears: Array=[]
var elapsed=0.0

func _initialize():
    root.size=Vector2i(1280,720)
    root_node=Node2D.new(); root.add_child(root_node)
    var bg=ColorRect.new(); bg.size=Vector2(1280,720); bg.color=Color("f6efd9"); root_node.add_child(bg)
    var font=FontVariation.new(); font.base_font=load("res://assets/fonts/NotoSansSC.ttf"); font.variation_opentype={2003265652:560.0}
    var states=["待机","移动","近战","远程","受击","倒地","技能","胜利"]
    for c in range(2):
        for i in range(8):
            var sim=Sim.new(); sim.add_player(1,"yier" if c==0 else "bubu")
            var p: Dictionary=sim.players[1]
            p.outfit="plain"
            p.moving=i==1; p.hurt=0.2 if i==4 else 0.0; p.down=i==5; p.down_time=.7 if i==5 else 0.0; p.skill_time=0.5 if i==6 else 0.0
            if i in [2,3]:
                var w="spoon" if i==2 else "wand"
                p.equipment.hand=w
                p.actions.hand={"seq":1,"weapon":w,"time":0.0,"duration":0.8,"hit_at":0.3,"direction":Vector2.RIGHT}
            var bear=Bear.new(); bear.data=p; bear.show_status=false; bear.won=i==7
            root_node.add_child(bear); bear.position=Vector2(85+i*157,270+c*325); bear.scale=Vector2(1.5,1.5)
            bears.append(bear)
            var label=Label.new(); root_node.add_child(label); label.position=Vector2(48+i*157,295+c*325); label.text=states[i]
            label.add_theme_font_override("font",font); label.add_theme_font_size_override("font_size",21); label.add_theme_color_override("font_color",Color("524b3b"))
    capture.call_deferred()

func _process(dt: float) -> bool:
    elapsed+=dt
    for bear in bears:
        bear.data.anim_clock=elapsed
        for action in bear.data.actions.values():
            action.time=fmod(elapsed,action.duration)
            action.seq=int(elapsed/action.duration)+1
    return false

func capture():
    await create_timer(1.9).timeout
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png("res://tests/output/v150_animation_gallery.png")
    # Real renderer anchor regression. Compare opaque pixel spans with no gear.
    var viewport=SubViewport.new(); viewport.size=Vector2i(192,192); viewport.transparent_bg=true
    viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var sim=Sim.new(); sim.add_player(1,"yier")
    sim.players[1].equipment.hand=""
    var actor=Bear.new(); actor.data=sim.players[1]; actor.show_status=false; actor.frozen=true
    viewport.add_child(actor); actor.position=Vector2(96,130)
    await process_frame; await RenderingServer.frame_post_draw
    var right=viewport.get_texture().get_image(); var right_bounds=right.get_used_rect()
    actor.data.face=-1; actor.queue_redraw()
    await process_frame; await RenderingServer.frame_post_draw
    var left=viewport.get_texture().get_image(); var left_bounds=left.get_used_rect()
    assert(absf(right_bounds.get_center().x-left_bounds.get_center().x)<=2,"Facing changes shifted the rendered body")
    assert(right_bounds.position.y==left_bounds.position.y)
    right.save_png("res://tests/output/turn_right.png"); left.save_png("res://tests/output/turn_left.png")
    for character in sim.DB.CHARACTERS:
        for outfit in sim.DB.COSTUMES:
            actor.data.character=character; actor.data.outfit=outfit
            for view in ["front","side","back"]:
                actor.data.facing=view; actor.data.face=1; actor.queue_redraw()
                await process_frame; await RenderingServer.frame_post_draw
                var positive=viewport.get_texture().get_image().get_used_rect()
                actor.data.face=-1; actor.queue_redraw()
                await process_frame; await RenderingServer.frame_post_draw
                var negative=viewport.get_texture().get_image().get_used_rect()
                assert(positive.has_area())
                assert(absf(positive.get_center().x-negative.get_center().x)<=2,"Outfit shifted on turn: "+outfit)
                assert(positive.position.y==negative.position.y and absf(positive.size.x-negative.size.x)<=2 and absf(positive.size.y-negative.size.y)<=1,"Turn pivot changed: "+character+"/"+outfit+"/"+view)
    actor.data.moving=true; actor.data.face=1
    for character in ["yier","bubu"]:
        actor.data.character=character
        for outfit in ["plain","casual"]:
            actor.data.outfit=outfit
            for view in ["front","side","back"]:
                actor.data.facing=view; actor.visual_clock=0; actor._process(0)
                await process_frame; await RenderingServer.frame_post_draw
                var first=viewport.get_texture().get_image()
                actor.visual_clock=.28; actor._process(0)
                await process_frame; await RenderingServer.frame_post_draw
                var second=viewport.get_texture().get_image()
                var before=first.get_data(); var after=second.get_data(); var changed=0
                for j in range(0,before.size(),4):
                    if before[j]!=after[j] or before[j+1]!=after[j+1] or before[j+2]!=after[j+2] or before[j+3]!=after[j+3]: changed+=1
                assert(changed>50,"Sprite frames not changing: "+character+"/"+outfit+"/"+view)
                assert(absf(first.get_used_rect().get_center().x-second.get_used_rect().get_center().x)<=3,"Animation shifted foot pivot")
    print("VISUAL_ALL_OUTFITS_42_VIEWS_MIRROR_ANCHOR_PASS ",right_bounds," / ",left_bounds)
    print("V150_RENDERED_FRAMES_CHANGE_WITH_FIXED_PIVOT_PASS")
    quit()
