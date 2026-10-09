extends SceneTree
const Arena=preload("res://scripts/arena_view.gd")
const Sim=preload("res://scripts/simulation.gd")

class FakeSession:
    extends Node
    var model
    func local_id() -> int: return 1

class FakeFeedback:
    extends Node
    func play(_key: String): pass

func _initialize():
    root.size=Vector2i(1280,720)
    var session=FakeSession.new(); session.model=Sim.new(); session.model.add_player(1,"bubu")
    session.model.phase="battle"; session.model.core.placed=true
    root.add_child(session)
    var feedback=FakeFeedback.new(); root.add_child(feedback)
    var view=Arena.new(); view.session=session; view.feedback=feedback
    root.add_child(view); view._ready()
    assert(view.fx_sheets.size()==6)
    var at: Vector2=session.model.players[1].pos
    for kind in ["windup_spoon","release_wand","impact_spoon","swing_spoon","boss_down"]:
        session.model.effect(kind,at,90,.5)
    capture.call_deferred()

func capture():
    await create_timer(.2).timeout
    await RenderingServer.frame_post_draw
    var image=root.get_texture().get_image()
    assert(image.get_used_rect().has_area())
    image.save_png("res://tests/output/v150_fx_render.png")
    print("V150_EFFECT_RENDER_PASS")
    quit()
