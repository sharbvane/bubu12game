extends Control
var direction = Vector2.ZERO
var finger = -1
var origin = Vector2.ZERO
var knob = Vector2.ZERO
var active = false
var mouse_drag = false

func _ready():
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func reset():
    finger=-1; mouse_drag=false; direction=Vector2.ZERO; queue_redraw()

func default_origin() -> Vector2:
    return Vector2(135,size.y-125)

func _input(event: InputEvent):
    if not active: return
    if event is InputEventMouse and event.device==-1: return
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x<size.x*0.43 and event.position.y>size.y*0.40 and finger==-1:
            finger=event.index; origin=event.position; knob=origin; get_viewport().set_input_as_handled()
        elif not event.pressed and event.index==finger: reset()
    elif event is InputEventScreenDrag and event.index==finger:
        knob=event.position; direction=(knob-origin).limit_length(66)/66.0; queue_redraw()
    elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
        if event.pressed and event.position.x<size.x*0.43 and event.position.y>size.y*0.40:
            mouse_drag=true; origin=event.position; knob=origin
        elif not event.pressed: reset()
    elif event is InputEventMouseMotion and mouse_drag:
        knob=event.position; direction=(knob-origin).limit_length(66)/66.0; queue_redraw()

func movement() -> Vector2:
    if not active: return Vector2.ZERO
    var keyboard=Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
    return keyboard.normalized() if keyboard.length_squared()>0 else direction

func _draw():
    if not active: return
    var at=origin if finger!=-1 or mouse_drag else default_origin()
    draw_circle(at,76,Color("293d3544"))
    draw_arc(at,76,0,TAU,64,Color("f7e7c477"),3,true)
    draw_circle(at+direction*55,30,Color("f7e7c455"))
    draw_arc(at+direction*55,30,0,TAU,32,Color("f7e7c4aa"),2,true)
