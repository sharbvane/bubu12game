extends Node2D
const Pose=preload("res://characters/pose.gd")
const DB=preload("res://scripts/catalog.gd")
const C=preload("res://scripts/garden_content.gd")
var data: Dictionary={}
var tex: Dictionary={}
var animation_sheets: Dictionary={}
var animation="idle"
var won=false
var frozen=false
var visual_clock=0.0
var down_blend=0.0
var font: Font
var show_status=true
var is_local=false
var root_transform=Transform2D.IDENTITY
var visual_actions: Dictionary={}

func _ready():
    texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    for character in DB.CHARACTERS:
        for outfit in DB.COSTUMES:
            for view in ["front","side","back"]:
                var key=DB.costume_sprite(character,outfit,view)
                tex[key]=load("res://资产/精灵/"+key+".png")
        tex[character+"_paw"]=load("res://资产/精灵/"+character+"_paw.png")
    for key in DB.WEAPONS: tex[key]=load("res://资产/精灵/held_"+key+".png")
    for key in C.GEAR: tex[key]=load("res://资产/精灵/"+key+".png")
    for character in DB.CHARACTERS:
        for state in ["idle","move","melee","ranged","hurt","dodge","down","build","item","skill","victory","side_idle","side_move","back_idle","back_move"]:
            var key=character+"_"+state
            var path="res://资产/动画/"+key+".png"
            if ResourceLoader.exists(path): animation_sheets[key]=load(path)
        for outfit in DB.COSTUMES:
            if outfit=="plain": continue
            for state in ["idle","move","side_move","back_move"]:
                var key=character+"_"+outfit+"_"+state
                var path="res://资产/动画/"+key+".png"
                if ResourceLoader.exists(path): animation_sheets[key]=load(path)
    font=load("res://assets/fonts/NotoSansSC.ttf")

func _process(dt: float):
    if data.is_empty(): return
    if not frozen: visual_clock+=dt
    animation=Pose.animation_state(data,won)
    down_blend=move_toward(down_blend,1 if data.down else 0,dt*4 if not frozen else 0)
    for slot in ["hand","offhand"]:
        if data.actions.has(slot):
            var a: Dictionary=data.actions[slot]
            var previous: Dictionary=visual_actions.get(slot,{})
            visual_actions[slot]=a.duplicate()
            if previous.get("seq",-1)==a.seq: visual_actions[slot].time=minf(a.duration,maxf(a.time,previous.time+(0 if frozen else dt)))
        else: visual_actions.erase(slot)
    queue_redraw()

static func facing_transform(face: int) -> Transform2D:
    return Transform2D(Vector2(face,0),Vector2(0,1),Vector2.ZERO)

func part(key: String, at: Vector2, dimensions: Vector2, angle: float=0, tint: Color=Color.WHITE):
    if not tex.has(key): return
    draw_set_transform_matrix(root_transform*Transform2D(angle,at.round()))
    draw_texture_rect(tex[key],Rect2(-dimensions/2,dimensions),false,tint)

func frame_for(state: String) -> int:
    if state in ["melee","ranged"]:
        for action in visual_actions.values():
            if (DB.WEAPONS[action.weapon].kind=="melee")==(state=="melee"):
                var hit=maxf(.001,action.hit_at)
                var progress=3.0*minf(1,action.time/hit) if action.time<hit else 3.0+4.99*clampf((action.time-hit)/maxf(.001,action.duration-hit),0,1)
                return clampi(int(progress),0,7)
    if state=="hurt": return clampi(int((.3-data.hurt)/.3*8),0,7)
    if state=="down": return clampi(int(data.get("down_time",0.0)*10),0,7)
    for timed in ["dodge","build","item","skill"]:
        if state==timed:
            var duration=.8 if state=="skill" else .45 if state=="dodge" else .5
            var remaining: float=data.get(state+"_time",0.0)
            return clampi(int((1-remaining/duration)*8),0,7)
    return int(visual_clock*(12 if state=="move" else 8 if state=="victory" else 5))%8

func body_sheet(state: String, view: String) -> String:
    var outfit=data.get("outfit","plain")
    if outfit!="plain":
        var costume_key=data.character+"_"+outfit+"_"+(view+"_" if view!="front" and state=="move" else "")+state
        return costume_key if animation_sheets.has(costume_key) and (view=="front" or state=="move") else ""
    var directed=data.character+"_"+view+"_"+state
    if state in ["idle","move"] and animation_sheets.has(directed): return directed
    return data.character+"_"+state if view!="back" else ""

func draw_body(state: String, view: String, tint: Color):
    var key=body_sheet(state,view)
    if animation_sheets.has(key):
        draw_set_transform_matrix(root_transform)
        draw_texture_rect_region(animation_sheets[key],Rect2(-48,-90,96,96),Rect2(frame_for(state)*128,0,128,128),tint)
    else:
        part(DB.costume_sprite(data.character,data.get("outfit","plain"),view),Vector2(0,-42),Vector2(96,96),0,tint)

func _draw():
    if data.is_empty() or tex.is_empty(): return
    var moving=animation=="move"
    var bob=sin(visual_clock*(11 if moving else 2.5))*(1.3 if moving else .45)
    var tilt=sin(visual_clock*11)*.025 if moving else 0.0
    if animation=="victory": bob=-absf(sin(visual_clock*6))*7; tilt=sin(visual_clock*6)*.04
    if animation=="rescue": bob=sin(visual_clock*5)*1.2; tilt=.06
    if animation=="skill": bob=-sin(data.skill_time/.8*PI)*5
    if animation=="hurt": tilt=sin(visual_clock*40)*.04
    root_transform=facing_transform(data.face)*Transform2D(tilt+down_blend*1.35,Vector2(0,bob-down_blend*7))
    var tint=Color(1,.73,.73) if animation=="hurt" else Color.WHITE
    var view: String=data.get("facing","front")
    if data.down or won or data.get("rescuing",false): view="front"
    var animated=animation_sheets.has(body_sheet(animation,view))
    if animated:
        root_transform=facing_transform(data.face)
    for slot in ["offhand","hand"]:
        if behind(slot): draw_hand(slot,tint)
    # The whole approved 96px silhouette is kept intact. No separate long arms/legs.
    draw_body(animation,view,tint)
    if data.has("gear"):
        if not data.gear.head.is_empty(): part(data.gear.head,Vector2(0,-67),Vector2(48,25))
        if not data.gear.body.is_empty(): part(data.gear.body,Vector2(0,-16),Vector2(27,23))
        if not data.gear.feet.is_empty(): part(data.gear.feet,Vector2(0,-3),Vector2(23,13))
        if not data.gear.charm.is_empty(): part(data.gear.charm,Vector2(cos(visual_clock*1.8)*43,-34+sin(visual_clock*1.8)*12),Vector2(22,22))
    for slot in ["offhand","hand"]:
        if not behind(slot): draw_hand(slot,tint)
    draw_set_transform_matrix(Transform2D.IDENTITY)
    if show_status:
        draw_rect(Rect2(-25,9,50,5),Color("4e5246"))
        draw_rect(Rect2(-25,9,50*data.hp/data.max_hp,5),Color("f0b1b6"))
        var title=DB.CHARACTERS[data.character].name+(" · 你" if is_local else "")
        draw_string_outline(font,Vector2(-26,-92),title,HORIZONTAL_ALIGNMENT_LEFT,-1,15,3,Color("453b36"))
        draw_string(font,Vector2(-26,-92),title,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff3db"))
        if data.down:
            draw_string(font,Vector2(-62,-30),"靠近救援 %.1f / 5" % data.revive,HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("fff3db"))
            draw_rect(Rect2(-40,18,80,7),Color("423c38")); draw_rect(Rect2(-40,18,80*data.revive/5,7),Color("e9cb8e"))
        if data.get("rescuing",false): draw_arc(Vector2(0,-25),43,0,TAU,32,Color("e9c4b6"),2)

func behind(slot: String) -> bool:
    return visual_actions.has(slot) and visual_actions[slot].direction.y<-.35

func draw_hand(slot: String, tint: Color):
    if data.down: return
    var key: String=data.equipment.get(slot,"")
    if key.is_empty(): return
    var pose=Pose.hand_pose(data,slot,visual_actions.get(slot,{}))
    if animation in ["skill","rescue","victory"]: pose.position.y-=3
    draw_set_transform_matrix(root_transform*Transform2D(pose.angle,pose.position.round()))
    draw_texture_rect(tex[key],Rect2(Vector2(-7,-13),Vector2(42,27)),false,tint)
    part(data.character+"_paw",pose.position,Vector2(7,7),0,tint)
