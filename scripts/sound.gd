extends Node
var music: AudioStreamPlayer
var channels: Array=[]
var streams: Dictionary={}
var muted=false
var last_hit=0
var last_played: Dictionary={}

func _ready():
    for key in ["click","hit","pickup","skill","level","hurt","swing","wand_fire","needle_fire","petal_fire","impact","boss_intro","boss_down","build_place","loot_chime"]: streams[key]=load("res://audio/"+key+".wav")
    for i in range(8):
        var player=AudioStreamPlayer.new(); add_child(player); channels.append(player)
    music=AudioStreamPlayer.new(); add_child(music)
    var stream=load("res://audio/garden_loop.wav") as AudioStreamWAV
    music.stream=stream; music.volume_db=-13
    music.finished.connect(music.play)
    if DisplayServer.get_name()!="headless": music.play()

func play(key: String):
    if muted or not streams.has(key): return
    if DisplayServer.get_name()=="headless": return
    var now=Time.get_ticks_msec()
    if now-int(last_played.get(key,-1000))<(70 if key=="impact" else 40): return
    last_played[key]=now
    if key=="hit" and Time.get_ticks_msec()-last_hit<100: return
    if key=="hit": last_hit=Time.get_ticks_msec()
    for p in channels:
        if not p.playing:
            p.stream=streams[key]; p.volume_db=-10; p.play(); return

func toggle():
    muted=not muted
    music.volume_db=-80 if muted else -13

func _exit_tree():
    shutdown()

func shutdown():
    music.stop()
    music.stream=null
    for p in channels: p.stop(); p.stream=null
