extends Node2D
var data: Dictionary={}
var texture: Texture2D
var defeat_texture: Texture2D
var sheets: Dictionary={}
var loaded_kind=""
var time=0.0

func _ready(): texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST

func _process(dt: float):
    if not data.is_empty() and data.kind!=loaded_kind:
        loaded_kind=data.kind; sheets.clear()
        for action in ["move","attack","down"]:
            var path="res://资产/动画/"+loaded_kind+"_"+action+".png"
            if ResourceLoader.exists(path): sheets[action]=load(path)
    var observed: float=data.get("age",0.0)
    time=minf(maxf(time,observed)+dt,observed+.08)
    queue_redraw()

func draw_frame(action: String, frame: int, size: float, tint: Color, offset: Vector2=Vector2.ZERO):
    var texture_size=192 if data.kind in ["boss","snail","queen_wasp","moon_treant"] else 96
    draw_texture_rect_region(sheets[action],Rect2(Vector2(-size/2,-size/2-10)+offset,Vector2(size,size)),Rect2(frame*texture_size,0,texture_size,texture_size),tint)

func _draw():
    if data.is_empty(): return
    var e=data
    var size=158.0 if e.kind in ["boss","snail","queen_wasp","moon_treant"] else 68.0 if e.kind in ["mushroom","root_brute","crystal_crab"] or e.get("elite",false) else 58.0
    draw_set_transform(Vector2(0,e.radius*0.6),0,Vector2(1,0.35))
    draw_circle(Vector2.ZERO,e.radius,Color("34483733"))
    draw_set_transform(Vector2.ZERO)
    if e.age<0.65: draw_arc(Vector2.ZERO,e.radius+8,0,TAU,24,Color("fff1c588"),2)
    var tint=Color(1,0.68,0.63) if e.hurt>0 else Color.WHITE
    if e.kind=="mole" and e.get("burrow",0.0)<3.5: tint.a=.35
    if e.age<0.65: tint.a=e.age/0.65
    var bob=sin(time*(12 if e.kind=="bee" else 7)+e.id)*2
    var recoil=Vector2(sin(time*55)*3,0) if e.hurt>0 else Vector2.ZERO
    if e.get("defeated",false):
        var t: float=e.get("defeat_time",0.0)
        tint.a=clampf((10-t)/2,0,1) if t>8 else 1.0
        if sheets.has("down"):
            draw_frame("down",clampi(int(t*10),0,7),size,tint,Vector2(0,16))
        else:
            var art=defeat_texture if defeat_texture!=null else texture
            var down_size=Vector2(size,size*.65) if defeat_texture==null else Vector2(size,size)
            draw_texture_rect(art,Rect2(Vector2(-down_size.x/2,-down_size.y/2+16+sin(t*3)*2),down_size),false,tint)
        return
    var visual_attack=maxf(0,e.get("attack_time",0.0)-maxf(0,time-e.age))
    var visual_warning=maxf(0,e.get("warning",0.0)-maxf(0,time-e.age))
    var action="attack" if (visual_attack>0 or visual_warning>0) and sheets.has("attack") else "move"
    if sheets.has(action):
        var frame=int(time*(13 if e.kind in ["bee","wasp","moth","queen_wasp"] else 9))%8
        if action=="attack":
            frame=clampi(int((1-visual_warning/(.65 if e.kind=="queen_wasp" else .9))*3),0,2) if visual_warning>0 else clampi(3+int((.55-minf(.55,visual_attack))/.55*5),3,7)
        draw_frame(action,frame,size,tint,recoil)
    else:
        draw_texture_rect(texture,Rect2(Vector2(-size/2,-size/2-10+bob)+recoil,Vector2(size,size)),false,tint)
    if e.get("elite",false): draw_arc(Vector2(0,-12),size*.46,0,TAU,32,Color("dfb869"),2)
    if e.get("bubble",0.0)>0: draw_circle(Vector2(0,-12),size*.55,Color(.7,.85,1,.3)); draw_arc(Vector2(0,-12),size*.55,0,TAU,32,Color("e4d8fc"),2)
    if e.get("stun",0.0)>0: draw_arc(Vector2(0,-size*.55),12,0,TAU,16,Color("f6d78f"),3)
    if e.get("honey",0)>0: draw_circle(Vector2(-19,5),5,Color("e5b24e"))
    if e.hp<e.max_hp and e.kind!="boss":
        draw_rect(Rect2(Vector2(-18,-size/2-6),Vector2(36,4)),Color("4e5246"))
        draw_rect(Rect2(Vector2(-18,-size/2-6),Vector2(36*maxf(0,e.hp)/e.max_hp,4)),Color("e1a77e"))
