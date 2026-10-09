extends Node2D
const DB=preload("res://scripts/catalog.gd")
const C=preload("res://scripts/garden_content.gd")
const GardenObject=preload("res://scripts/garden_object.gd")
const Bear=preload("res://characters/bear_visual.gd")
const Enemy=preload("res://enemies/enemy_visual.gd")
var actors: Dictionary={}
var garden_nodes: Dictionary={}
var build_key=""
var build_target=Vector2.INF
var observed_effects: Dictionary={}
var shake=0.0
var last_vibration=0
var session: Node
var sprites: Dictionary={}
var fx_sheets: Dictionary={}
var camera=Vector2.ZERO
var rendered: Dictionary={}
var time=0.0
var font: Font
var menu: Texture2D
var feedback: Node
var last_kills=0
var last_hp=0.0

func _ready():
    texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    for key in ["yier","bubu","yier_sheet","bubu_sheet","sprout","bee","mushroom","acorn","boss","garden","rock","heart","berry","leaf","boot","star","shield","flower","milk","wand","spoon","petal","needle","coin"]:
        sprites[key]=load("res://资产/精灵/"+key+".png")
    for key in C.BUILDINGS.keys()+C.ITEMS.keys()+C.GEAR.keys()+C.ENEMIES.keys(): sprites[key]=load("res://资产/精灵/"+key+".png")
    for key in ["queen_wasp_down","moon_treant_down"]: sprites[key]=load("res://资产/精灵/"+key+".png")
    for i in range(5): sprites["core_"+str(i)]=load("res://资产/精灵/core_%d.png" % i)
    for key in ["spoon_swing","wand_fire","needle_fire","petal_spin","berry_impact","boss_slam"]:
        var path="res://资产/动画/fx_"+key+".png"
        if ResourceLoader.exists(path): fx_sheets[key]=load(path)
    menu=load("res://资产/精灵/menu.jpg")
    font=FontVariation.new()
    font.base_font=load("res://assets/fonts/NotoSansSC.ttf")
    font.variation_opentype={2003265652:600.0}

func _process(dt: float):
    var m=session.model
    time=m.world_time
    shake=maxf(0,shake-dt*14)
    if m.phase in ["battle","boss_outro","paused","camp","result","deploy"] and not m.players.is_empty():
        var p: Dictionary=m.players.get(session.local_id(),m.players.values()[0])
        var screen=get_viewport_rect().size
        var target: Vector2=p.pos-screen/2
        target=target.clamp(Vector2.ZERO,(DB.ARENA-screen).max(Vector2.ZERO))
        camera=camera.lerp(target,1-exp(-dt*7))
        var seen: Dictionary={}
        for entity in m.enemies+m.shots+m.drops+m.players.values():
            var key=str(entity.id)+("p" if entity.has("character") else "e")
            seen[key]=true
            rendered[key]=(rendered.get(key,entity.pos) as Vector2).lerp(entity.pos,1-exp(-dt*22))
        for key in rendered.keys():
            if not seen.has(key): rendered.erase(key)
        var present: Dictionary={}
        for actor in m.enemies+m.players.values():
            var player=actor.has("character")
            var key=str(actor.id)+("p" if player else "e")
            present[key]=true
            if not actors.has(key):
                var node=Bear.new() if player else Enemy.new()
                if not player:
                    node.texture=sprites[actor.kind]
                    if sprites.has(actor.kind+"_down"): node.defeat_texture=sprites[actor.kind+"_down"]
                add_child(node); actors[key]=node
            var node=actors[key]
            node.data=actor
            node.visible=true
            node.position=(entity_pos(actor,player)+(Vector2(0,22) if player else Vector2.ZERO)-camera).round()+shake_offset()
            node.z_index=int(actor.pos.y)
            if player:
                node.won=m.phase=="result" and m.result=="守护成功"
                node.frozen=m.phase=="paused" or (m.time_stop>0 and actor.id!=m.time_owner)
                node.is_local=actor.id==session.local_id()
        for key in actors.keys():
            if not present.has(key): actors[key].queue_free(); actors.erase(key)
        var existing: Dictionary={}
        for item in m.buildings+[m.core]:
            var is_core=item.has("placed")
            var key="core" if is_core else str(item.id)
            existing[key]=true
            if not garden_nodes.has(key):
                var node=GardenObject.new(); node.core=is_core
                if not is_core: node.texture=sprites[item.kind]
                add_child(node); garden_nodes[key]=node
            var node=garden_nodes[key]; node.data=item; node.visible=true
            node.position=(item.pos-camera+Vector2(0,-93 if is_core and not item.placed else 0)).round()
            node.z_index=int(item.pos.y)+1
        for key in garden_nodes.keys():
            if not existing.has(key): garden_nodes[key].queue_free(); garden_nodes.erase(key)
        var live_effects: Dictionary={}
        for e in m.effects:
            live_effects[e.id]={"age":minf(e.duration,observed_effects.get(e.id,{}).get("age",0.0)+dt)}
            if observed_effects.has(e.id): continue
            observed_effects[e.id]={"age":0.0}
            if e.pos.distance_to(p.pos)>650: continue
            if e.kind.begins_with("release_"):
                var weapon=e.kind.trim_prefix("release_")
                feedback.play("swing" if DB.WEAPONS.get(weapon,{}).get("kind","")=="melee" else weapon+"_fire" if weapon in ["wand","needle","petal"] else "wand_fire")
            elif e.kind.begins_with("impact_"):
                feedback.play("impact"); shake=maxf(shake,1.4 if e.kind=="impact_spoon" else 0.5)
            elif e.kind in ["combo","skill_cast"]:
                feedback.play("skill"); vibrate(45); shake=maxf(shake,2)
            elif e.kind=="boss_down":
                feedback.play("boss_down"); vibrate(180); shake=maxf(shake,7)
            elif e.kind=="boss_intro": feedback.play("boss_intro"); vibrate(90)
            elif e.kind=="build_place": feedback.play("build_place")
            elif e.kind=="pickup": feedback.play("loot_chime" if e.radius>28 else "pickup")
        observed_effects=live_effects
        if p.hp<last_hp and not p.down: feedback.play("hurt"); shake=2.8; vibrate(35)
        last_kills=m.kills; last_hp=p.hp
    else:
        for node in actors.values(): node.visible=false
        for node in garden_nodes.values(): node.visible=false
    queue_redraw()

func shake_offset() -> Vector2:
    return Vector2(sin(time*70),cos(time*59))*shake

func vibrate(milliseconds: int):
    if Time.get_ticks_msec()-last_vibration<180: return
    last_vibration=Time.get_ticks_msec()
    Input.vibrate_handheld(milliseconds,0.35)

func entity_pos(e: Dictionary, player: bool=false) -> Vector2:
    return rendered.get(str(e.id)+("p" if player else "e"),e.pos)

func sprite(key: String, at: Vector2, size: Vector2, tint: Color=Color.WHITE):
    draw_texture_rect(sprites[key],Rect2((at-size/2).round(),size),false,tint)

func animated_fx(key: String, e: Dictionary, size: float) -> bool:
    if not fx_sheets.has(key): return false
    var progress: float=observed_effects.get(e.id,{}).get("age",0.0)/e.duration
    var frame=clampi(int(progress*3),0,2) if e.kind.begins_with("windup_") else clampi(3+int(progress*5),3,7)
    draw_set_transform_matrix(Transform2D(0,-camera.round()+shake_offset())*Transform2D(e.angle,e.pos))
    draw_texture_rect_region(fx_sheets[key],Rect2(Vector2(-size/2,-size/2),Vector2(size,size)),Rect2(frame*128,0,128,128))
    draw_set_transform(-camera.round()+shake_offset())
    return true

func _unhandled_input(event: InputEvent):
    if build_key.is_empty() or session==null or not session.model.players.has(session.local_id()): return
    if event is InputEventScreenTouch and event.pressed:
        build_target=session.model.snap_site(event.position+camera); get_viewport().set_input_as_handled()
    elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
        build_target=session.model.snap_site(event.position+camera); get_viewport().set_input_as_handled()

func text(at: Vector2, value: String, color: Color, font_size: int=18):
    draw_string_outline(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,4,Color("453b36"))
    draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _draw():
    if session==null or menu==null: return
    var m=session.model
    var screen=get_viewport_rect().size
    if m.phase in ["menu","lobby","join"]:
        var scale=maxf(screen.x/menu.get_width(),screen.y/menu.get_height())
        var size=menu.get_size()*scale
        draw_texture_rect(menu,Rect2((screen-size)/2,size),false)
        draw_rect(Rect2(Vector2.ZERO,screen),Color("20362b33"))
        return
    draw_set_transform(-camera.round()+shake_offset())
    draw_texture_rect(sprites.garden,Rect2(Vector2.ZERO,DB.ARENA),false)
    for obstacle in m.rocks:
        if obstacle.hp>0: sprite("rock",obstacle.pos-Vector2(0,14),Vector2(92,92))
    for z in m.zones:
        var col=Color("e1bc8170") if z.kind in ["meteor","bomb"] else Color("b1d89b66")
        draw_circle(z.pos,z.radius,col)
        draw_arc(z.pos,z.radius,0,TAU,48,Color("f4dda8"),2)
        if z.kind=="meteor": sprite("star",z.pos-Vector2(0,z.ttl*120),Vector2(42,42))
        elif z.kind=="bomb": sprite("bomb",z.pos,Vector2(46,46))
        elif z.kind=="banana": sprite("banana",z.pos,Vector2(42,42))
        elif z.kind=="heal": sprite("heal_seed",z.pos,Vector2(38,38))
    for e in m.enemies:
        if e.link!=0:
            for other in m.enemies:
                if other.id==e.link: draw_line(e.pos,other.pos,Color("e697a3"),2); break
    if not build_key.is_empty() and m.players.has(session.local_id()) and m.phase in ["battle","camp","deploy"]:
        var p: Dictionary=m.players[session.local_id()]
        for x in range(-4,5):
            for y in range(-4,5):
                var cell=m.snap_site(p.pos+Vector2(x,y)*m.GRID)
                if cell.distance_to(p.pos)>260: continue
                var state=m.site_state(p.id,cell)
                var fill=Color("78cb8b40") if state=="valid" else Color("e4b57955") if state=="occupied" else Color("d46b6750")
                draw_rect(Rect2(cell-Vector2.ONE*m.GRID/2,Vector2.ONE*m.GRID),fill)
                draw_rect(Rect2(cell-Vector2.ONE*m.GRID/2,Vector2.ONE*m.GRID),fill.lightened(.2),false,1.2)
        var at: Vector2=m.snap_site(p.pos+p.last_direction*105) if not build_target.is_finite() else build_target
        var valid=m.site_state(p.id,at)=="valid"
        sprite(build_key,at-Vector2(0,18),Vector2(87,87),Color(1,1,1,.75) if valid else Color(1,.3,.3,.62))
        draw_arc(at,32,0,TAU,32,Color("b4d69d") if valid else Color("e99393"),3)
    if m.linked and m.players.size()==2:
        var ps=m.players.values()
        draw_line(ps[0].pos,ps[1].pos,Color("ffdfac88"),5)
        sprite("heart",(ps[0].pos+ps[1].pos)/2+Vector2(0,-20-sin(time*4)*4),Vector2(25,25))
    for d in m.drops:
        var at=entity_pos(d)+Vector2(0,sin(time*4+d.id)*2)
        sprite(d.get("item","berry"),at,Vector2(43,43) if d.has("item") else Vector2(23,23))
        if d.has("item"): text(at+Vector2(-50,-34),"Boss 战利品",Color("fff4c9"),16)
    # Telegraphs are below actors and remain visible before boss impact.
    for e in m.effects:
        if e.kind=="warning":
            draw_circle(e.pos,e.radius,Color("a8404344"))
            draw_arc(e.pos,e.radius,0,TAU,64,Color("f6a997"),4)
            draw_arc(e.pos,e.radius*(1-e.ttl/e.duration),0,TAU,64,Color("fff0c7"),3)
    for p in m.players.values():
        draw_ellipse_shadow(entity_pos(p,true)+Vector2(0,20),Vector2(29,9))
        if p.shield>0: draw_arc(p.pos,49,0,TAU,40,Color("f7d77dcc"),3)
    for s in m.shots:
        var at=entity_pos(s)
        if s.owner==0:
            draw_circle(at,10,Color("553e40")); draw_circle(at,7,Color("f29b79")); draw_circle(at-Vector2(2,2),3,Color("ffe2aa"))
        else: sprite("berry" if s.kind=="wand" else "star",at,Vector2(19,19))
    for e in m.effects:
        if e.kind in ["warning","skill_cast"]: continue
        var life: float=1-observed_effects.get(e.id,{}).get("age",0.0)/e.duration
        if e.kind.begins_with("windup_"):
            var weapon=e.kind.trim_prefix("windup_")
            var visual="spoon_swing" if weapon=="spoon" else "wand_fire" if weapon=="wand" else "needle_fire" if weapon=="needle" else "petal_spin"
            animated_fx(visual,e,60)
        elif e.kind.begins_with("impact_"):
            if animated_fx("berry_impact",e,maxf(55,e.radius*1.6)): continue
            var color=Color("c9b6f6") if e.kind in ["impact_prism_staff","impact_moonbell"] else Color("f5c2bc") if e.kind=="impact_wand" else Color("ffe3a0")
            color.a=life
            for k in range(6):
                var v=Vector2.from_angle(e.angle+k*TAU/6)
                draw_line(e.pos+v*(1-life)*10,e.pos+v*(1-life)*28,color,3)
        elif e.kind.begins_with("release_"):
            var weapon=e.kind.trim_prefix("release_")
            var visual="wand_fire" if weapon in ["wand","prism_staff","moonbell"] else "needle_fire" if weapon in ["needle","hive_bow"] else ""
            if not visual.is_empty() and animated_fx(visual,e,75): continue
            if e.kind not in ["release_spoon","release_petal"]:
                draw_line(e.pos,e.pos+Vector2.from_angle(e.angle)*life*22,Color(1,0.92,0.66,life),4)
        elif e.kind=="number" or e.kind=="crit":
            text(e.pos+Vector2(-10,-(1-life)*35),str(int(e.radius)),Color(1,0.83 if e.kind=="crit" else 1,0.48 if e.kind=="crit" else 0.92,life),24 if e.kind=="crit" else 17)
        elif e.kind=="poof":
            for k in range(5):
                var at: Vector2=e.pos+Vector2.from_angle(k*TAU/5)*(1-life)*30
                draw_rect(Rect2(at,Vector2(5,5)),Color(1,0.9,0.65,life))
        elif e.kind=="boss_down":
            animated_fx("boss_slam",e,e.radius*2.2)
            draw_arc(e.pos,e.radius*(1-life*.55),0,TAU,48,Color(1,.86,.48,life),9)
            for k in range(12):
                var at: Vector2=e.pos+Vector2.from_angle(k*TAU/12+time*.3)*(e.radius*(1-life*.7))
                sprite("flower",at,Vector2(25,25),Color(1,1,1,life))
        elif e.kind.begins_with("swing_"):
            var visual="petal_spin" if e.kind=="swing_petal" else "spoon_swing" if e.kind=="swing_spoon" else ""
            if not visual.is_empty() and animated_fx(visual,e,e.radius*1.6): continue
            draw_arc(e.pos,e.radius*(1-life*0.12),e.angle-1.45,e.angle+1.45,20,Color(1,0.84,0.50,life),14)
            draw_arc(e.pos,e.radius,e.angle-1.35,e.angle+1.35,20,Color(1,0.98,0.8,life),4)
        else:
            var col=Color("f5bdc4") if e.kind in ["heal","petal","combo"] else Color("ffd888")
            col.a=life*0.8
            draw_arc(e.pos,e.radius*(1-life*0.60),0,TAU,48,col,7)
            for k in range(8):
                sprite("heart" if e.kind in ["heal","combo"] else "petal" if e.kind=="petal" else "star",e.pos+Vector2.from_angle(k*TAU/8+time)*(e.radius*(1-life*0.7)),Vector2(23,23),Color(1,1,1,life))
    draw_set_transform(Vector2.ZERO)
    if m.core.placed:
        var local: Vector2=m.core.pos-camera
        if not Rect2(Vector2(75,120),screen-Vector2(150,250)).has_point(local):
            var at=local.clamp(Vector2(100,235),screen-Vector2(145,180))
            sprite("berry",at,Vector2(34,34)); text(at+Vector2(-42,33),"大甜莓",Color("fff1d4"),16)
    if m.time_stop>0:
        draw_rect(Rect2(Vector2.ZERO,screen),Color(.36,.23,.05,.12))
    var moths=m.enemies.filter(func(e):return e.kind=="moth" and e.hp>0)
    if not moths.is_empty() and m.players.has(session.local_id()):
        var p: Dictionary=m.players[session.local_id()]
        if moths.any(func(e):return e.pos.distance_to(p.pos)<330):
            var opacity=.13 if p.gear.charm=="lantern" else .32
            draw_rect(Rect2(Vector2.ZERO,screen),Color(.13,.10,.22,opacity))

func draw_ellipse_shadow(at: Vector2, radius: Vector2):
    var points=PackedVector2Array()
    for i in range(18): points.append(at+Vector2(cos(i*TAU/18)*radius.x,sin(i*TAU/18)*radius.y))
    draw_colored_polygon(points,Color("34483733"))
