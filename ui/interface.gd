extends Control
const C=preload("res://scripts/garden_content.gd")
const Sim=preload("res://scripts/simulation.gd")
const DB=preload("res://scripts/catalog.gd")
const Touch=preload("res://ui/touch_controls.gd")
const Bear=preload("res://characters/bear_visual.gd")
const INK=Color("4e493c")
const CREAM=Color("fff3d9")
const MUTED=Color("8b9176")
var game: Node
var session: Node
var layer: Control
var touch: Control
var selected="yier"
var last_phase=""
var last_core_shop_open=false
var last_revision=-1
var health: ProgressBar
var exp_bar: ProgressBar
var boss_bar: ProgressBar
var hp_label: Label
var wave_label: Label
var detail_label: Label
var buff_label: Label
var skill_button: Button
var boss_label: Label
var hint_label: Label
var status_label: Label
var menu_error=""
var room_list: VBoxContainer
var room_cards: Dictionary={}
var discovery_revision=-1
var skill_progress: ProgressBar
var shown_level=1
var wardrobe=false
var wardrobe_bear: Node2D
var wardrobe_buttons: Dictionary={}
var result_bears: Dictionary={}
var ui_font: Font
var action_pending_until=0
var camp_open=false
var shop_category="武器"
var camp_signature=""
var upgrade_cards: Array=[]
var product_cards: Array=[]
var gear_buttons: Dictionary={}
var item_buttons: Array=[]
var camp_title: Label
var growth_label: Label
var inventory_label: Label
var ready_button: Button
var reroll_button: Button
var core_bar: ProgressBar
var core_label: Label
var item_hud: Array=[]
var build_button: Button
var build_place: Button
var build_key="fence"
var build_mode=false
var detail_popup: Control
var profile: Dictionary={}
var core_pick=0
var dash_button: Button
var building_slots: Dictionary={}
var category_buttons: Dictionary={}
const CATEGORY_ICONS={"武器":"ui_cat_weapon","装备":"ui_cat_gear","饰品":"ui_cat_charm","道具":"ui_cat_item","建筑":"ui_cat_build","核心":"ui_cat_core","技能":"ui_skill"}

func _ready():
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    ui_font=FontVariation.new()
    ui_font.base_font=load("res://assets/fonts/NotoSansSC.ttf")
    ui_font.variation_opentype={2003265652:560.0}
    var t=Theme.new(); t.default_font=ui_font; t.default_font_size=20
    t.set_color("font_color","Label",INK)
    t.set_color("font_color","Button",INK)
    t.set_color("font_disabled_color","Button",Color("9b9c86"))
    t.set_color("font_hover_color","Button",INK)
    t.set_stylebox("normal","Button",box(Color("f7e8c8")))
    t.set_stylebox("hover","Button",box(Color("fff4d9"),Color("bc9f6a")))
    t.set_stylebox("pressed","Button",box(Color("e4c6aa")))
    t.set_stylebox("disabled","Button",box(Color("d8d8be"),Color("aeb69a")))
    t.set_stylebox("focus","Button",box(Color.TRANSPARENT,Color("d88787"),2))
    t.set_stylebox("normal","LineEdit",box(CREAM))
    t.set_color("font_color","LineEdit",INK)
    theme=t
    touch=Touch.new(); add_child(touch)
    resized.connect(func(): last_phase=""; touch.reset())

func box(color: Color, border: Color=Color("b7bd98"), width: int=2) -> StyleBoxFlat:
    var s=StyleBoxFlat.new(); s.bg_color=color; s.border_color=border
    s.set_border_width_all(width); s.set_corner_radius_all(12)
    s.content_margin_left=16; s.content_margin_right=16
    s.content_margin_top=10; s.content_margin_bottom=10
    return s

func panel(parent: Node, at: Vector2, dimensions: Vector2, color: Color=CREAM) -> Panel:
    var p=Panel.new(); parent.add_child(p); p.position=at; p.size=dimensions
    p.add_theme_stylebox_override("panel",box(color)); p.mouse_filter=Control.MOUSE_FILTER_IGNORE
    return p

func label(parent: Node, value: String, at: Vector2, dimensions: Vector2, font_size: int=20, color: Color=INK) -> Label:
    var l=Label.new(); parent.add_child(l); l.position=at; l.size=dimensions; l.text=value
    l.add_theme_font_size_override("font_size",font_size); l.add_theme_color_override("font_color",color)
    l.mouse_filter=Control.MOUSE_FILTER_IGNORE
    return l

func button(parent: Node, value: String, at: Vector2, dimensions: Vector2, callback: Callable, accent: bool=false) -> Button:
    var b=Button.new(); parent.add_child(b); b.position=at; b.size=dimensions; b.text=value
    b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
    if accent:
        b.add_theme_stylebox_override("normal",box(Color("e9a6a0"),Color("bb8177")))
        b.add_theme_stylebox_override("hover",box(Color("f4b6aa"),Color("bb8177")))
    b.pressed.connect(func():
        if b.get_meta("long_consumed",false) or b.get_meta("blocked",false): return
        game.sound.play("click"); callback.call())
    b.pivot_offset=dimensions/2
    b.button_down.connect(func():
        if b.has_meta("motion"): b.get_meta("motion").kill()
        var motion=b.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
        motion.tween_property(b,"scale",Vector2(0.975,0.975),0.06)
        b.set_meta("motion",motion)
    )
    b.button_up.connect(func():
        if b.has_meta("motion"): b.get_meta("motion").kill()
        var motion=b.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        motion.tween_property(b,"scale",Vector2.ONE,0.13)
        b.set_meta("motion",motion)
    )
    return b

func icon(parent: Node, key: String, at: Vector2, dimensions: Vector2):
    if key in ["yier","bubu"]: key+="_portrait"
    var t=TextureRect.new(); parent.add_child(t); t.texture=load("res://资产/精灵/"+key+".png")
    t.position=at; t.size=dimensions; t.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; t.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    t.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; t.mouse_filter=Control.MOUSE_FILTER_IGNORE

func icon_slot(parent: Node, at: Vector2, dimensions: Vector2, callback: Callable) -> Button:
    var b=button(parent,"",at,dimensions,callback)
    enable_detail(b)
    var picture=TextureRect.new(); b.add_child(picture)
    picture.position=Vector2(9,3); picture.size=Vector2(dimensions.x-18,dimensions.y-24)
    picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST; picture.mouse_filter=Control.MOUSE_FILTER_IGNORE
    b.set_meta("picture",picture)
    var caption=label(b,"",Vector2(2,dimensions.y-24),Vector2(dimensions.x-4,23),13)
    caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    b.set_meta("caption",caption)
    var count=label(b,"",Vector2(dimensions.x-34,2),Vector2(30,21),14)
    count.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; b.set_meta("count",count)
    return b

func fill_slot(b: Button, key: String, placeholder: String, caption: String, count: String=""):
    b.set_meta("detail_key",key)
    var visual=placeholder if key.is_empty() else key
    if b.get_meta("visual","")!=visual:
        b.get_meta("picture").texture=load("res://资产/精灵/"+visual+".png"); b.set_meta("visual",visual)
    b.get_meta("picture").modulate.a=.45 if key.is_empty() else 1.0
    b.get_meta("caption").text=caption; b.get_meta("count").text=count
    b.tooltip_text=equipment_name(key) if not key.is_empty() else caption

func enable_detail(b: Button):
    b.button_down.connect(func():
        b.set_meta("long_consumed",false)
        b.set_meta("hold_active",true)
        await get_tree().create_timer(.45).timeout
        if not is_instance_valid(b) or not b.get_meta("hold_active",false): return
        var key: String=b.get_meta("detail_key",b.get_meta("key",""))
        if key.is_empty(): return
        b.set_meta("long_consumed",true)
        show_detail(key)
    )
    b.button_up.connect(func(): b.set_meta("hold_active",false))

func show_detail(key: String):
    if is_instance_valid(detail_popup): detail_popup.queue_free()
    var data: Dictionary=DB.UPGRADES.get(key,{}) if DB.UPGRADES.has(key) else DB.WEAPONS.get(key,{}) if DB.WEAPONS.has(key) else C.data(key)
    if data.is_empty(): return
    detail_popup=Control.new(); layer.add_child(detail_popup); detail_popup.size=size; detail_popup.z_index=200
    var shade=ColorRect.new(); detail_popup.add_child(shade); shade.size=size; shade.color=Color("25352899"); shade.mouse_filter=Control.MOUSE_FILTER_STOP
    shade.gui_input.connect(func(event):
        if event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed: hide_detail())
    var card=panel(detail_popup,(size-Vector2(680,300))/2,Vector2(680,300),Color("fff3da"))
    icon(card,DB.UPGRADES[key].icon if DB.UPGRADES.has(key) else data.get("icon",key),Vector2(25,26),Vector2(170,170))
    label(card,data.get("name",key),Vector2(205,25),Vector2(445,43),30)
    var quality=["常见","精良","稀有","传奇"][clampi(int(data.get("rarity",1))-1,0,3)]
    var category="属性" if DB.UPGRADES.has(key) else "武器" if DB.WEAPONS.has(key) else C.category(key)
    label(card,category+" · "+quality+(" · %d 草莓" % data.price if data.has("price") and data.price>0 else ""),Vector2(205,78),Vector2(420,34),18,Color("a37459"))
    var stats=""
    if DB.WEAPONS.has(key): stats="伤害 %d  ·  间隔 %.2f 秒  ·  距离 %d" % [data.damage,data.cooldown,data.range]
    elif C.BUILDINGS.has(key): stats="耐久 %d  ·  范围 %d  ·  间隔 %.1f 秒" % [data.hp,data.range,data.cooldown]
    elif C.GEAR.has(key): stats="部位："+str(data.slot)
    label(card,stats,Vector2(205,117),Vector2(445,36),17)
    var desc=label(card,data.get("desc",""),Vector2(205,154),Vector2(445,106),20); desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    label(card,"松开手指或点击空白处关闭",Vector2(25,265),Vector2(600,24),15,MUTED)

func hide_detail():
    if is_instance_valid(detail_popup): detail_popup.queue_free(); detail_popup=null

func _input(event: InputEvent):
    if detail_popup!=null and (event is InputEventScreenTouch and not event.pressed or event is InputEventMouseButton and not event.pressed): hide_detail()

func bar(parent: Node, at: Vector2, dimensions: Vector2, color: Color) -> ProgressBar:
    var b=ProgressBar.new(); parent.add_child(b); b.position=at; b.size=dimensions
    b.show_percentage=false; b.mouse_filter=Control.MOUSE_FILTER_IGNORE
    b.add_theme_stylebox_override("background",box(Color("4b5d4b"),Color("4b5d4b"),0))
    b.add_theme_stylebox_override("fill",box(color,color,0))
    for style in [b.get_theme_stylebox("background"),b.get_theme_stylebox("fill")]:
        style.content_margin_top=0; style.content_margin_bottom=0
        style.content_margin_left=0; style.content_margin_right=0
        style.set_corner_radius_all(4)
    b.size=dimensions
    return b

func rebuild():
    var changed=session.model.phase!=last_phase
    if layer!=null:
        var old=layer
        if changed:
            disable_controls(old)
            var fade=old.create_tween()
            fade.tween_property(old,"modulate:a",0.0,0.12)
            fade.tween_callback(old.queue_free)
        else: remove_child(old); old.queue_free()
    layer=Control.new(); add_child(layer); layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); layer.mouse_filter=Control.MOUSE_FILTER_IGNORE
    game.arena.build_key=""
    touch.active=session.model.phase in ["battle","boss_outro","deploy","camp"] and not camp_open; touch.visible=touch.active; touch.reset()
    var phase: String=session.model.phase
    if phase!="menu": wardrobe=false
    room_cards.clear(); result_bears.clear()
    match phase:
        "menu": build_menu()
        "join": build_join()
        "lobby": build_lobby()
        "battle", "boss_outro", "deploy":
            if camp_open: build_camp()
            else: build_hud()
        "paused": build_pause()
        "camp":
            if camp_open: build_camp()
            else: build_hud()
        "result": build_result()
    if wardrobe: build_wardrobe()
    layer.modulate.a=0.0
    var enter=layer.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    enter.tween_property(layer,"modulate:a",1.0,0.16 if changed else 0.08)
    if changed:
        layer.position.y=7
        enter.tween_property(layer,"position:y",0.0,0.18)
    last_phase=phase; last_core_shop_open=session.model.core_shop_open(); last_revision=session.model.revision

func disable_controls(node: Node):
    if node is Control: node.mouse_filter=Control.MOUSE_FILTER_IGNORE; node.focus_mode=Control.FOCUS_NONE
    for child in node.get_children(): disable_controls(child)

func _process(dt: float):
    var m=session.model
    if m.phase!=last_phase:
        if last_phase!="" and m.phase in ["battle","boss_outro","deploy"]: camp_open=false
        if m.phase=="camp" and last_phase not in ["","camp"]: camp_open=true
        rebuild()
    elif m.phase=="camp" and m.core_shop_open()!=last_core_shop_open: rebuild()
    elif m.phase=="lobby" and m.revision!=last_revision: rebuild()
    if m.phase in ["battle","boss_outro","deploy","camp"] and m.players.has(session.local_id()):
        if camp_open: refresh_camp()
        else: update_hud(dt)
    if m.phase=="lobby" and is_instance_valid(status_label): status_label.text=session.message
    if m.phase=="join":
        if discovery_revision!=session.discovery.revision: refresh_rooms()
        if is_instance_valid(status_label): status_label.text=session.message

func build_menu():
    var left=maxf(38,(size.x-1280)/2+48)
    var p=panel(layer,Vector2(left,42),Vector2(516,size.y-84),Color("f8efdcee"))
    label(p,"A LITTLE GARDEN, TWO BRAVE HEARTS",Vector2(28,19),Vector2(465,27),15,Color("7e8a69"))
    label(p,"一二布布",Vector2(28,54),Vector2(460,65),52)
    label(p,"甜 莓 守 护 战",Vector2(31,121),Vector2(450,40),28,Color("b77770"))
    label(p,"带上小小勇气，守住我们的草莓花园。",Vector2(30,174),Vector2(465,30),19,Color("7e8168"))
    for i in range(2):
        var key="yier" if i==0 else "bubu"
        var c: Dictionary=DB.CHARACTERS[key]
        var b=button(p,"",Vector2(28+i*238,220),Vector2(222,126),func(): selected=key; last_phase="",selected==key)
        icon(b,DB.costume_sprite(key,session.cosmetics.get(key,{}).get("outfit","plain")),Vector2(1,5),Vector2(84,100))
        label(b,c.name+("  ✓" if selected==key else ""),Vector2(85,14),Vector2(130,30),24)
        label(b,c.title,Vector2(85,53),Vector2(130,28),16)
        label(b,"远程 · 治疗" if i==0 else "近战 · 护盾",Vector2(85,84),Vector2(135,24),14)
    button(p,"开始单人冒险   →",Vector2(28,368),Vector2(460,57),func(): session.solo(selected),true)
    button(p,"创建房间",Vector2(28,438),Vector2(222,53),func():
        if session.host(selected)!=OK: menu_error=session.message; last_phase=""
    )
    button(p,"加入房间",Vector2(266,438),Vector2(222,53),func(): session.browse())
    if session.has_save():
        var saved=session.read_save()
        button(p,"继续 %d-0  ·  单人" % saved.round_no,Vector2(28,507),Vector2(222,52),func(): session.resume_solo(),true)
        button(p,"继续 %d-0  ·  开房" % saved.round_no,Vector2(266,507),Vector2(222,52),func():
            if session.host_saved()!=OK: menu_error=session.message; last_phase="")
    else: label(p,"核心防守 / 花园建造 / 双人合作",Vector2(28,510),Vector2(460,28),16,Color("7e8168"))
    if not menu_error.is_empty(): label(p,menu_error,Vector2(28,566),Vector2(460,38),15,Color("b15e58")).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    elif not session.has_save(): label(p,"移动即战斗。靠近彼此，会更强一点。",Vector2(28,550),Vector2(460,28),16,Color("7e8168"))
    button(layer,"角色外观",Vector2(size.x-160,78),Vector2(136,44),func(): wardrobe=true; last_phase="")
    button(layer,"声音："+("关" if game.sound.muted else "开"),Vector2(size.x-160,24),Vector2(136,44),func(): game.sound.toggle(); last_phase="")
    label(layer,"1.5.0  ·  花园逐帧冒险",Vector2(size.x-350,size.y-42),Vector2(325,28),16,CREAM)

func modal(title: String, subtitle: String, dimensions: Vector2=Vector2(760,540)) -> Panel:
    var shade=ColorRect.new(); layer.add_child(shade); shade.color=Color("213629a8"); shade.size=size; shade.mouse_filter=Control.MOUSE_FILTER_STOP
    var p=panel(layer,(size-dimensions)/2,dimensions)
    label(p,title,Vector2(32,23),Vector2(dimensions.x-64,54),36)
    label(p,subtitle,Vector2(33,85),Vector2(dimensions.x-66,68),19,Color("7e8168")).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    return p

func back_menu():
    wardrobe=false
    session.close(); session.model.phase="menu"; menu_error=""; last_phase=""

func build_join():
    var p=modal("找到另一只小熊","同一 Wi-Fi 下的小花园会自动出现在这里，点击房间即可加入。",Vector2(850,574))
    var scroll=ScrollContainer.new(); p.add_child(scroll); scroll.position=Vector2(34,155); scroll.size=Vector2(782,284)
    scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
    room_list=VBoxContainer.new(); scroll.add_child(room_list); room_list.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    room_list.add_theme_constant_override("separation",12)
    status_label=label(p,session.message,Vector2(34,442),Vector2(780,43),17,Color("7e8168"))
    status_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    button(p,"重新寻找",Vector2(34,504),Vector2(380,48),func(): session.discovery.pulse=1; session.message="正在刷新附近的小花园…")
    button(p,"返回",Vector2(435,504),Vector2(380,48),back_menu)
    discovery_revision=-1
    refresh_rooms()

func refresh_rooms():
    if not is_instance_valid(room_list): return
    discovery_revision=session.discovery.revision
    for key in room_cards.keys():
        if not session.discovery.rooms.has(key): room_cards[key].queue_free(); room_cards.erase(key)
    for key in session.discovery.rooms:
        var r: Dictionary=session.discovery.rooms[key]
        if not room_cards.has(key):
            var b=button(room_list,"",Vector2.ZERO,Vector2(758,84),func(): session.join_discovered(key,selected))
            b.custom_minimum_size=Vector2(758,84); b.alignment=HORIZONTAL_ALIGNMENT_LEFT
            b.modulate.a=0
            b.create_tween().tween_property(b,"modulate:a",1.0,0.18)
            room_cards[key]=b
        var b: Button=room_cards[key]
        b.text="%s   %d / 2\n%s" % [r.name,int(r.players),session.Discovery.status_label(r)]
        b.disabled=not r.joinable
    if room_cards.is_empty():
        session.message="暂未发现房间。请让伙伴创建房间，并确认双方连接同一个 Wi-Fi。"

func build_lobby():
    var m=session.model
    var p=modal("两只小熊的花园","一二负责治疗，布布负责保护。靠近彼此获得攻速与恢复加成。",Vector2(850,574))
    if session.mode=="host":
        label(p,"房间已公开 · 伙伴在房间列表中点击即可加入",Vector2(34,153),Vector2(780,58),22).autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    else: label(p,"已连接房主  ·  等待开始",Vector2(34,153),Vector2(780,48),24)
    var i=0
    for player in m.players.values():
        var c: Dictionary=DB.CHARACTERS[player.character]
        var card=panel(p,Vector2(34+i*396,226),Vector2(382,125),Color("e6e8ce"))
        icon(card,DB.costume_sprite(player.character,player.get("outfit","plain")),Vector2(12,3),Vector2(105,109))
        label(card,c.name+(" · 房主" if player.id==1 else " · 伙伴"),Vector2(129,21),Vector2(240,32),26)
        label(card,c.title,Vector2(130,70),Vector2(230,28),19)
        i+=1
    if i<2: label(p,"等待另一只小熊…",Vector2(469,264),Vector2(315,45),24,Color("929b7e"))
    status_label=label(p,session.message,Vector2(34,373),Vector2(780,44),19,Color("7e8168"))
    var b=button(p,"一起出发   →" if session.mode=="host" else "等待房主开始",Vector2(34,454),Vector2(538,60),func(): session.act("start"),true)
    b.disabled=session.mode!="host" or m.players.size()!=2
    button(p,"离开房间",Vector2(594,454),Vector2(222,60),back_menu)


func build_hud():
    var m=session.model
    var p=panel(layer,Vector2(24,19),Vector2(285,86),Color("faf0dce8"))
    hp_label=label(p,"",Vector2(14,8),Vector2(260,30),19)
    health=bar(p,Vector2(14,49),Vector2(257,17),Color("dd9292"))
    var player: Dictionary=m.players.get(session.local_id(),{})
    if not player.is_empty(): health.max_value=player.max_hp; health.value=player.hp
    var center=panel(layer,Vector2(size.x/2-205,16),Vector2(410,93),Color("faf0dce8"))
    wave_label=label(center,"",Vector2(12,4),Vector2(385,32),22)
    core_label=label(center,"",Vector2(12,36),Vector2(385,28),17)
    core_bar=bar(center,Vector2(12,70),Vector2(386,12),Color("db827d")); core_bar.max_value=m.core.max_hp; core_bar.value=m.core.hp
    button(layer,"暂停 Ⅱ",Vector2(size.x-145,20),Vector2(120,51),func(): session.act("pause"))
    detail_label=label(layer,"",Vector2(26,111),Vector2(610,28),17,CREAM)
    exp_bar=bar(layer,Vector2(26,145),Vector2(283,7),Color("e6d69b")); shown_level=m.level
    buff_label=label(layer,"",Vector2(size.x/2-300,115),Vector2(600,55),18,CREAM); buff_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    boss_bar=bar(layer,Vector2(size.x/2-210,205),Vector2(420,10),Color("df9877")); boss_bar.visible=false
    boss_label=label(layer,"",Vector2(size.x/2-270,173),Vector2(540,30),17,CREAM); boss_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    skill_button=button(layer,"",Vector2(size.x-186,size.y-158),Vector2(146,105),func(): session.act("skill"),true)
    skill_button.add_theme_font_size_override("font_size",17)
    icon(skill_button,"ui_skill",Vector2(49,2),Vector2(48,32))
    skill_progress=bar(skill_button,Vector2(13,91),Vector2(120,5),Color("fff0bd"))
    item_hud.clear()
    for i in range(4):
        var b=icon_slot(layer,Vector2(size.x-108,233+i*68),Vector2(91,61),func(): session.act("item",str(i)))
        b.set_meta("cooldown",bar(b,Vector2(6,57),Vector2(79,3),Color("d69191"))); item_hud.append(b)
    dash_button=button(layer,"冲刺",Vector2(size.x-295,size.y-130),Vector2(98,71),func(): session.act("dash"))
    build_button=icon_slot(layer,Vector2(size.x/2-110,size.y-143),Vector2(90,87),cycle_build)
    build_place=button(layer,"放置建筑",Vector2(size.x/2+59,size.y-108),Vector2(155,48),place_build,true)
    button(layer,"退出建造",Vector2(size.x/2+59,size.y-160),Vector2(155,44),func(): build_mode=false; game.arena.build_key="")
    if m.phase in ["camp","deploy"]:
        button(layer,"花园补给站",Vector2(26,174),Vector2(203,50),func(): camp_open=true; last_phase="")
        if m.phase=="deploy" and m.core.carrier==session.local_id(): button(layer,"放下大甜莓 · 开始",Vector2(size.x/2-159,232),Vector2(318,55),func(): session.act("place_core"),true)
        elif m.phase=="camp": button(layer,"返回补给 / 准备",Vector2(size.x/2-145,232),Vector2(290,55),func(): camp_open=true; last_phase="")
    hint_label=label(layer,"",Vector2(size.x/2-345,size.y-52),Vector2(690,43),16,CREAM); hint_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
    label(layer,"移动 / WASD",Vector2(61,size.y-36),Vector2(170,25),15,CREAM)

func update_hud(dt: float):
    var m=session.model
    var p: Dictionary=m.players[session.local_id()]
    health.max_value=p.max_hp; health.value=lerpf(health.value,p.hp,1-exp(-dt*14))
    hp_label.text="%s · %d / %d HP" % [DB.CHARACTERS[p.character].name,ceili(health.value),p.max_hp]
    wave_label.text="%d-%d   ·   %s" % [m.round_no,m.wave,"无限时准备" if m.wave==0 else "战利品 %02d 秒" % ceili(m.outro_time) if m.phase=="boss_outro" else "%02d:%02d" % [int(m.clock)/60,int(m.clock)%60]]
    core_bar.max_value=m.core.max_hp; core_bar.value=lerpf(core_bar.value,m.core.hp,1-exp(-dt*12))
    core_label.text="大甜莓  %d / %d  · 护盾 %d" % [m.core.hp,m.core.max_hp,m.core.shield]
    detail_label.text="Lv.%d  草莓 %d  击退 %d" % [m.level,p.coins,m.kills]
    exp_bar.value=lerpf(exp_bar.value,100.0*m.xp/DB.xp_needed(m.level),1-exp(-dt*12))
    buff_label.text="心意相连 · 攻速 +20%% · 合力 %d%%" % m.link_charge if m.linked else ""
    if p.down: buff_label.text="倒地了 · 伙伴靠近救援 5 秒：%.1f / 5" % p.revive
    if m.players.values().all(func(a):return a.down): buff_label.text="全员倒地 · %.1f 秒后复活\n大甜莓存活即可重返战场！" % m.revive_clock
    if m.time_stop>0: buff_label.text="世界 · 时间停止 %.1f 秒 · %s 行动" % [m.time_stop,DB.CHARACTERS[m.players[m.time_owner].character].name]
    skill_button.text="\n"+DB.CHARACTERS[p.character].skill+("\n%d 秒" % ceili(p.skill_cd) if p.skill_cd>0 else "\n准备就绪")
    skill_button.disabled=p.skill_cd>0 or p.down or m.phase!="battle" or (m.time_stop>0 and m.time_owner!=p.id)
    skill_progress.value=lerpf(skill_progress.value,(1-p.skill_cd/12)*100,1-exp(-dt*16))
    for i in range(4):
        item_hud[i].visible=i<m.item_capacity(p)
        var key: String=p.items[i] if i<p.items.size() else ""
        fill_slot(item_hud[i],key,"ui_slot_item",("%.1fs" % p.item_cd if p.item_cd>0 and not key.is_empty() else str(i+1)),"×1" if not key.is_empty() else "")
        item_hud[i].get_meta("cooldown").value=clampf(p.item_cd/.25*100,0,100)
        item_hud[i].set_meta("blocked",p.down or p.item_cd>0 or m.phase!="battle" or (m.time_stop>0 and m.time_owner!=p.id))
        item_hud[i].disabled=key.is_empty()
    dash_button.visible=p.gear.feet in ["dash_boots","moon_boots"]; dash_button.disabled=p.dash_cd>0 or p.down
    dash_button.text="冲刺" if p.dash_cd<=0 else "%.1f 秒" % p.dash_cd
    var keys=p.inventory.keys().filter(func(k):return p.inventory[k]>0)
    if not build_key in keys: build_key=keys[0] if not keys.is_empty() else ""
    game.arena.build_key=build_key if build_mode and not p.down and not p.ready else ""
    fill_slot(build_button,build_key,"ui_slot_build","换建筑 ›" if build_mode else "建造",str(p.inventory.get(build_key,0)))
    if build_place.get_meta("visual","?")!=build_key:
        build_place.icon=load("res://资产/精灵/"+(build_key if not build_key.is_empty() else "ui_slot_build")+".png")
        build_place.add_theme_constant_override("icon_max_width",30); build_place.expand_icon=true
        build_place.set_meta("visual",build_key)
    build_button.disabled=keys.is_empty() or p.down
    build_place.disabled=not build_mode or build_key.is_empty() or p.down or p.ready
    hint_label.text="点击网格选位置 · 绿色可建 · 橙色占用 · 红色超出范围" if build_mode else m.notice if m.phase!="battle" else "跟随莓果标记返回核心" if m.core.pos.distance_to(p.pos)>550 else "靠近大甜莓布防 · 道具用完即消耗"
    var bosses=m.enemies.filter(func(e):return e.kind in DB.BOSS_KINDS and not e.get("defeated",false))
    boss_bar.visible=not bosses.is_empty(); boss_label.visible=boss_bar.visible
    if not bosses.is_empty():
        boss_bar.max_value=bosses[0].max_hp; boss_bar.value=lerpf(boss_bar.value,bosses[0].hp,1-exp(-dt*12)); boss_label.text=DB.ENEMIES[bosses[0].kind].name

func build_pause():
    var p=modal("花园休息一下","联机时暂停对双方生效，任一玩家可继续。",Vector2(680,474))
    button(p,"继续守护",Vector2(34,164),Vector2(612,64),func(): session.act("pause"),true)
    button(p,"声音："+("关" if game.sound.muted else "开"),Vector2(34,249),Vector2(612,57),func(): game.sound.toggle(); last_phase="")
    button(p,"结束本局，返回主菜单",Vector2(34,331),Vector2(612,57),back_menu)
    label(p,"触屏：左侧拖动 · 右侧技能    键盘：WASD · 空格 · Esc",Vector2(34,411),Vector2(620,28),16)

func build_camp():
    var m=session.model
    if not m.players.has(session.local_id()): return
    camp_signature=""; upgrade_cards.clear(); product_cards.clear(); gear_buttons.clear(); item_buttons.clear(); building_slots.clear(); category_buttons.clear()
    if not m.core_shop_open() and shop_category in ["核心","技能"]: shop_category="武器"
    var margin=maxf(24,(size.x-1220)/2)
    var sheet=panel(layer,Vector2(margin,14),Vector2(1220,size.y-28),Color("f5efd9fa"))
    camp_title=label(sheet,"",Vector2(22,12),Vector2(970,40),28)
    button(sheet,"回到花园",Vector2(1034,12),Vector2(162,44),func(): camp_open=false; last_phase="")
    var brief_index=6+(m.round_no-2)*4+(m.wave%4) if m.round_no>1 else m.intel
    label(sheet,"情报 · "+C.INTEL[brief_index],Vector2(24,58),Vector2(1160,30),18,Color("9a6956"))
    growth_label=label(sheet,"",Vector2(24,94),Vector2(1140,32),19)
    for i in range(3):
        var b=make_shop_card(sheet,Vector2(24+i*394,133),Vector2(381,102))
        b.pressed.connect(func():
            if not b.get_meta("long_consumed",false) and not b.get_meta("blocked",false): send_action("upgrade",b.get_meta("key","")))
        upgrade_cards.append(b)
    var categories=["武器","装备","饰品","道具","建筑","核心","技能"]
    for i in range(categories.size()):
        var category: String=categories[i]
        if category in ["核心","技能"] and not m.core_shop_open(): continue
        var tab=button(sheet,category,Vector2(24+i*130,251),Vector2(120,40),func(): shop_category=category; camp_signature="")
        tab.icon=load("res://资产/精灵/"+CATEGORY_ICONS[category]+".png"); tab.expand_icon=true; tab.add_theme_constant_override("icon_max_width",27)
        category_buttons[category]=tab
    reroll_button=button(sheet,"刷新 · 8 草莓",Vector2(965,251),Vector2(240,40),func():
        if shop_category=="核心": core_pick=(core_pick+1)%3; camp_signature=""
        elif shop_category=="技能": pass
        else: send_action("reroll")
    )
    for i in range(3):
        var b=make_shop_card(sheet,Vector2(24+i*394,306),Vector2(381,134))
        b.pressed.connect(func():
            if b.get_meta("long_consumed",false) or b.get_meta("blocked",false): return
            var person=session.model.players[session.local_id()]
            send_action("skill_growth" if shop_category=="技能" else "core_growth" if shop_category=="核心" and person.core_tokens>0 else "buy",b.get_meta("key","")))
        product_cards.append(b)
    var names={"offhand":"左手","hand":"右手","head":"头部","body":"身体","feet":"鞋子","charm":"饰品"}
    var idx=0
    label(sheet,"随身装备 · 点击切换",Vector2(24,443),Vector2(680,25),15,MUTED)
    label(sheet,"主动道具 · 点击丢弃 / 骰子可使用",Vector2(810,443),Vector2(390,25),15,MUTED)
    for slot in names:
        var b=icon_slot(sheet,Vector2(24+idx*125,470),Vector2(113,85),func(): cycle_slot(slot))
        b.set_meta("slot_name",names[slot]); gear_buttons[slot]=b; idx+=1
    for i in range(4):
        var b=icon_slot(sheet,Vector2(810+i*98,470),Vector2(89,85),func(): supply_item(i))
        item_buttons.append(b)
    inventory_label=label(sheet,"建筑库存 · 点击图标，回到花园布置",Vector2(24,563),Vector2(770,24),15,MUTED)
    idx=0
    for key in C.BUILDINGS:
        var b=icon_slot(sheet,Vector2(24+idx*55,size.y-119),Vector2(51,64),func(): build_key=key; camp_signature="")
        building_slots[key]=b; idx+=1
    ready_button=button(sheet,"",Vector2(820,size.y-119),Vector2(384,59),func(): send_action("ready"),true)
    refresh_camp()

func make_shop_card(parent: Node, at: Vector2, dimensions: Vector2) -> Button:
    var b=button(parent,"",at,dimensions,func(): pass)
    enable_detail(b)
    var picture=TextureRect.new(); b.add_child(picture); picture.position=Vector2(8,9); picture.size=Vector2(94,dimensions.y-22); picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; picture.mouse_filter=Control.MOUSE_FILTER_IGNORE; picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
    b.set_meta("picture",picture)
    b.set_meta("title",label(b,"",Vector2(111,8),Vector2(260,29),20))
    var description=label(b,"",Vector2(111,39),Vector2(253,dimensions.y-48),16,Color("74775e")); description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
    b.set_meta("description",description)
    return b

func fill_card(b: Button, key: String, title: String, description: String, disabled: bool):
    b.set_meta("key",key); b.set_meta("detail_key",key); b.set_meta("blocked",disabled); b.disabled=key.is_empty()
    b.modulate.a=.65 if disabled else 1.0
    b.get_meta("title").text=title; b.get_meta("description").text=description
    var path="res://资产/精灵/"+key+".png"
    if DB.UPGRADES.has(key): path="res://资产/精灵/"+DB.UPGRADES[key].icon+".png"
    elif C.SKILL_UPGRADES.has(key): path="res://资产/精灵/"+C.SKILL_UPGRADES[key].icon+".png"
    b.get_meta("picture").texture=load(path) if ResourceLoader.exists(path) else null

func refresh_camp():
    var m=session.model
    var p: Dictionary=m.players[session.local_id()]
    # No layer replacement or fade: remote actions never mutate local controls.
    var signature=str([p.ui_revision,p.coins,p.pending,p.ready,p.core_tokens,p.skill_tokens,shop_category,core_pick,p.items,m.round_no,m.wave,m.players.values().map(func(a):return a.ready)])
    if signature==camp_signature: return
    camp_signature=signature
    camp_title.text="花园补给站 · %d-%d%s   草莓 %d   Lv.%d" % [m.round_no,m.wave," 特殊强化" if m.core_shop_open() else " 波后" if m.phase=="camp" else " 部署",p.coins,m.level]
    growth_label.text="属性成长 · 待选 %d 次   |   生命 %d  伤害 +%d%%  攻速 +%d%%  护甲 %d  建筑 +%d%%" % [p.pending,p.max_hp,(p.damage-1)*100,(p.attack_speed-1)*100,p.armor,(p.build_power-1)*100]
    for i in range(3):
        var key: String=p.offers[i] if i<p.offers.size() else ""
        var u: Dictionary=DB.UPGRADES.get(key,{})
        fill_card(upgrade_cards[i],key,u.get("name","本轮成长已领取"),u.get("desc","击退敌人升级，下一准备阶段领取成长。"),key.is_empty() or p.ready)
    var stock=p.stock.filter(func(k):return C.category(k)==shop_category)
    if shop_category=="核心": stock=C.CORE_UPGRADES.keys().slice(core_pick*3,core_pick*3+3)
    elif shop_category=="技能": stock=C.SKILL_UPGRADES.keys()
    for category in category_buttons:
        category_buttons[category].modulate=Color("f1bcb0") if category==shop_category else Color.WHITE
    if m.core_shop_open(): category_buttons["核心"].text="核心"+(" ●" if p.core_tokens>0 else "")
    if m.core_shop_open(): category_buttons["技能"].text="技能"+(" ●" if p.skill_tokens>0 else "")
    for i in range(3):
        var key: String=stock[i] if i<stock.size() else ""
        var d=m.shop_data(key)
        var desc: String=d.get("desc","刷新可寻找更多商品")
        var title: String=d.get("name","暂时缺货")
        var free_core=shop_category=="核心" and p.core_tokens>0
        var free_skill=shop_category=="技能" and p.skill_tokens>0
        if not d.is_empty():
            var quality=["常见","精良","稀有","传奇"][clampi(int(d.get("rarity",1))-1,0,3)]
            desc+=("\n免费选择 · 本回合 %d 次" % (p.skill_tokens if free_skill else p.core_tokens)) if free_core or free_skill else "\n%d 草莓  ·  %s / %s" % [d.price,quality,shop_category]
        if key in p.bought: title+=" ✓"
        var blocked=key.is_empty() or p.ready or (shop_category=="技能" and not free_skill) or (not free_core and not free_skill and (key in p.bought or p.coins<d.get("price",0)))
        if C.ITEMS.has(key) and p.items.size()>=m.item_capacity(p): blocked=true; desc="道具槽已满。点击下方现有道具可丢弃。"
        if C.GEAR.has(key) and key in p.owned: blocked=true
        if DB.WEAPONS.has(key) and p.weapons.get(key,0)>=4: blocked=true
        fill_card(product_cards[i],key,title,desc,blocked)
    for slot in gear_buttons:
        var key: String=p.equipment[slot] if slot in ["hand","offhand"] else p.gear[slot]
        fill_slot(gear_buttons[slot],key,"ui_slot_"+slot,gear_buttons[slot].get_meta("slot_name"),"Lv"+str(p.weapons[key]) if DB.WEAPONS.has(key) else "")
        gear_buttons[slot].set_meta("blocked",p.ready)
    for i in range(4):
        item_buttons[i].visible=i<m.item_capacity(p)
        fill_slot(item_buttons[i],p.items[i] if i<p.items.size() else "","ui_slot_item",str(i+1),"×1" if i<p.items.size() else "")
        item_buttons[i].set_meta("blocked",p.ready)
        item_buttons[i].disabled=i>=p.items.size()
    for key in building_slots:
        fill_slot(building_slots[key],key,"ui_slot_build","×"+str(p.inventory.get(key,0)))
        building_slots[key].add_theme_stylebox_override("normal",box(Color("f0c0aa") if key==build_key else Color("f7e8c8")))
        building_slots[key].set_meta("blocked",p.inventory.get(key,0)<=0 or p.ready)
    reroll_button.text="核心 %d / 3  ·  下一页 ›" % (core_pick+1) if shop_category=="核心" else "技能自由选择" if shop_category=="技能" else "刷新 · 8 草莓"
    reroll_button.disabled=shop_category=="技能" or shop_category!="核心" and (p.ready or p.coins<8)
    var next_wave="%d-%d" % [m.round_no,1 if m.wave==0 else m.wave+1]
    ready_button.text="放下大甜莓后开始" if m.phase=="deploy" else "已准备 · 点击取消" if p.ready else "先领取属性成长" if p.pending>0 else "到核心栏选择强化 ●" if p.core_tokens>0 else "到技能栏选择升级 ●" if p.skill_tokens>0 else "准备进入 "+next_wave+" →"
    if m.players.size()==2 and m.phase=="camp": ready_button.text+="  %d/2" % m.players.values().filter(func(a):return a.ready).size()
    ready_button.disabled=m.phase=="deploy" or p.pending>0 or p.core_tokens>0 or p.skill_tokens>0

func cycle_slot(slot: String):
    var p: Dictionary=session.model.players[session.local_id()]
    var options: Array=[""]
    var current: String
    if slot in ["hand","offhand"]: options+=p.weapons.keys(); current=p.equipment[slot]
    else: options+=p.owned.filter(func(k):return C.GEAR[k].slot==slot); current=p.gear[slot]
    send_action("equip" if slot in ["hand","offhand"] else "gear",slot+":"+options[(options.find(current)+1)%options.size()])

func supply_item(index: int):
    var p: Dictionary=session.model.players[session.local_id()]
    if index<p.items.size(): send_action("item" if p.items[index]=="dice" else "discard",str(index))

func send_action(action: String, key: String=""):
    if session.mode=="client" and Time.get_ticks_msec()<action_pending_until: return
    if session.mode=="client": action_pending_until=Time.get_ticks_msec()+180
    session.act(action,key)
    game.sound.play("level" if action=="upgrade" else "pickup")

func build_result():
    var m=session.model
    var won=m.result=="守护成功"
    var p=modal("花园守住啦！" if won else "先休息，再出发",m.result,Vector2(820,606))
    var index=0
    for player in m.players.values():
        var bear=Bear.new(); bear.data=player; bear.show_status=false; bear.won=won; p.add_child(bear)
        bear.position=Vector2(315+index*190,282); bear.scale=Vector2(1.65,1.65)
        result_bears[player.id]=bear; index+=1
    icon(p,"heart",Vector2(375,160),Vector2(45,45))
    label(p,"守护至 %d 回合     ·     击退 %d     ·     等级 %d" % [m.round_no,m.kills,m.level],Vector2(80,299),Vector2(680,41),25)
    label(p,"守护时长 %d 分 %02d 秒   ·   共获得 %d 经验" % [int(m.elapsed)/60,int(m.elapsed)%60,m.total_xp],Vector2(80,351),Vector2(680,38),21,Color("7e8168"))
    var stats=""
    for player in m.players.values(): stats+=DB.CHARACTERS[player.character].name+"  输出 "+str(int(player.damage_dealt))+"     "
    label(p,stats,Vector2(80,399),Vector2(680,38),20)
    button(p,"再来一局",Vector2(34,484),Vector2(362,65),func():
        if session.mode=="solo": session.solo(selected)
        else: back_menu()
    ,true)
    button(p,"返回主菜单",Vector2(419,484),Vector2(367,65),back_menu)

func equipment_name(key: String) -> String:
    if key.is_empty(): return "空槽"
    if DB.WEAPONS.has(key): return DB.WEAPONS[key].name
    return C.data(key).get("name",key)

func build_wardrobe():
    var preview=Sim.new(); preview.add_player(1,selected)
    profile=preview.players[1]
    profile.outfit=session.cosmetics.get(selected,{}).get("outfit","plain")
    if not DB.COSTUMES.has(profile.outfit): profile.outfit="plain"
    profile.equipment.hand=""; profile.equipment.offhand=""
    var p=modal("出发前，穿喜欢的衣服","整套新时装 · 仅改变外观，进入对局后固定。",Vector2(950,604))
    wardrobe_bear=Bear.new(); wardrobe_bear.data=profile; wardrobe_bear.show_status=false; p.add_child(wardrobe_bear)
    wardrobe_bear.position=Vector2(180,389); wardrobe_bear.scale=Vector2(2.6,2.6)
    wardrobe_buttons.clear()
    var i=0
    for key in DB.COSTUMES:
        var b=icon_slot(p,Vector2(332+(i%4)*144,151+(i/4)*161),Vector2(134,149),func():
            profile.outfit=key
            for k in wardrobe_buttons: wardrobe_buttons[k].add_theme_stylebox_override("normal",box(Color("f0c0aa") if k==key else Color("f7e8c8")))
        )
        fill_slot(b,DB.costume_sprite(selected,key),"",DB.COSTUMES[key])
        b.add_theme_stylebox_override("normal",box(Color("f0c0aa") if key==profile.outfit else Color("f7e8c8")))
        wardrobe_buttons[key]=b
        i+=1
    button(p,"查看侧面 / 背面",Vector2(65,425),Vector2(235,46),func(): profile.facing=["front","side","back"][( ["front","side","back"].find(profile.facing)+1)%3])
    button(p,"保存外观",Vector2(34,533),Vector2(882,49),func(): session.save_cosmetics(selected,{"outfit":profile.outfit}); wardrobe=false; last_phase="",true)

func cycle_build():
    var p: Dictionary=session.model.players[session.local_id()]
    var keys=p.inventory.keys().filter(func(k):return p.inventory[k]>0)
    if keys.is_empty(): return
    if not build_mode:
        build_mode=true
        game.arena.build_target=session.model.snap_site(p.pos+p.last_direction*105)
    else: build_key=keys[(keys.find(build_key)+1)%keys.size()]

func place_build():
    if build_key.is_empty() or not build_mode: return
    var p: Dictionary=session.model.players[session.local_id()]
    var target: Vector2=game.arena.build_target
    if not target.is_finite(): target=session.model.snap_site(p.pos+p.last_direction*105)
    if session.model.site_state(p.id,target)=="valid": session.build(build_key,target)
