extends Node2D
var data: Dictionary={}
var texture: Texture2D
var core=false
var stages: Array=[]

func _ready():
    texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    if core:
        for i in range(5): stages.append(load("res://资产/精灵/core_%d.png" % i))

func _process(_dt: float): queue_redraw()

func _draw():
    if data.is_empty(): return
    var ratio: float=clampf(data.hp/data.max_hp,0,1)
    if core and not stages.is_empty(): texture=stages[mini(4,int((1-ratio)*5))]
    if texture==null: return
    var dimensions=Vector2(124,124) if core else Vector2(87,87)
    var color=Color(1,.66,.66) if data.get("hurt",0.0)>0 else Color.WHITE
    if data.get("disabled",0.0)>0: color=Color(.55,.44,.7)
    draw_texture_rect(texture,Rect2(Vector2(-dimensions.x/2,-dimensions.y+25),dimensions),false,color)
    draw_rect(Rect2(-34,26,68,5),Color("514638"))
    draw_rect(Rect2(-34,26,68*ratio,5),Color("ed9b9e") if core else Color("b8cc8d"))
    if core and data.shield>0: draw_arc(Vector2(0,-27),64,0,TAU,48,Color("ffe5a9"),2)
    if data.get("disabled",0.0)>0:
        draw_line(Vector2(-13,-30),Vector2(13,-5),Color("e8b7e9"),4)
        draw_line(Vector2(13,-30),Vector2(-13,-5),Color("e8b7e9"),4)
