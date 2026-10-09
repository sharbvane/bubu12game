"""Run model integration checks and real two-process ENet integration."""
from pathlib import Path
import os, shutil, subprocess, time, sys
ROOT=Path(__file__).resolve().parents[1]
GODOT=os.environ.get('GODOT_BIN') or shutil.which('godot') or shutil.which('godot4')
if not GODOT: raise SystemExit('Set GODOT_BIN to a Godot 4 console executable.')
OUT=ROOT/'tests/output'; OUT.mkdir(exist_ok=True)
BASE=[GODOT,'--headless','--path',str(ROOT)]

def good(result, log):
    if result or 'SCRIPT ERROR' in log or 'Invalid call' in log or '\nERROR:' in log:
        print(log[-8000:]); raise SystemExit('Check failed')

r=subprocess.run(BASE+['--script','tests/v140_check.gd'],capture_output=True,encoding='utf-8',timeout=60)
log=r.stdout+r.stderr; (OUT/'v140.log').write_text(log,encoding='utf-8'); good(r.returncode,log)
assert 'ALL_V140_SYSTEM_CHECKS_PASS' in log
print(log)
r=subprocess.run(BASE+['--script','tests/rig_check.gd'],capture_output=True,encoding='utf-8',timeout=30)
log=r.stdout+r.stderr; (OUT/'rig.log').write_text(log,encoding='utf-8'); good(r.returncode,log); print(log)
r=subprocess.run(BASE+['--script','tests/v150_animation_check.gd'],capture_output=True,encoding='utf-8',timeout=30)
log=r.stdout+r.stderr; (OUT/'v150_animation.log').write_text(log,encoding='utf-8'); good(r.returncode,log)
assert 'V150_FRAMES_DIRECTION_ATTACK_SYNC_PASS' in log
print(log)
with (OUT/'host.log').open('w',encoding='utf-8') as hf, (OUT/'client.log').open('w',encoding='utf-8') as cf, (OUT/'discovery.log').open('w',encoding='utf-8') as df:
    host=subprocess.Popen(BASE+['--','--test=host'],stdout=hf,stderr=subprocess.STDOUT)
    observer=subprocess.Popen(BASE+['--script','tests/discovery_check.gd'],stdout=df,stderr=subprocess.STDOUT)
    time.sleep(1.2)
    client=subprocess.Popen(BASE+['--','--test=client'],stdout=cf,stderr=subprocess.STDOUT)
    try:
        client.wait(timeout=30); host.wait(timeout=30); observer.wait(timeout=30)
    finally:
        for p in (host,client,observer):
            if p.poll() is None: p.kill()
for p,name in [(host,'host'),(client,'client'),(observer,'discovery')]:
    log=(OUT/(name+'.log')).read_text(encoding='utf-8'); good(p.returncode,log); print(log)
# Real display input routing is required: headless mode skips mouse emulation.
r=subprocess.run([GODOT,'--path',str(ROOT),'--script','tests/ui_check.gd'],capture_output=True,encoding='utf-8',timeout=40)
log=r.stdout+r.stderr; (OUT/'ui.log').write_text(log,encoding='utf-8'); good(r.returncode,log)
assert 'UI_TOUCH_MENU_MULTITOUCH_SKILL_PAUSE_PASS' in log
print(log)
r=subprocess.run([GODOT,'--path',str(ROOT),'--script','tests/v150_effect_render_check.gd'],capture_output=True,encoding='utf-8',timeout=30)
log=r.stdout+r.stderr; (OUT/'v150_fx.log').write_text(log,encoding='utf-8'); good(r.returncode,log)
assert 'V150_EFFECT_RENDER_PASS' in log
print(log)
print('ALL_CHECKS_PASS')
