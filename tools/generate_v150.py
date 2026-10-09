"""Generate v1.5 frame-by-frame atlases through the configured image25 skill."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import os
from pathlib import Path
import subprocess
import time
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL = ROOT / '资产' / '原画'
DEST = ORIGINAL / 'v150'
SKILL = Path(os.environ.get('IMAGE25_SCRIPT_PATH', Path.home() / '.codex' / 'skills' / 'image25' / 'scripts' / 'image25.ps1'))

HERO = {
    'idle': '1 settle neutral, 2 gentle inhale with shoulders rising, 3 lift one ear and blink, 4 lean in with a tiny paw gesture, 5 exhale and relax, 6 blink with other ear twitch, 7 smile and squeeze both tiny paws, 8 return exactly to frame 1. Distinct expressions and arm poses, no simple pixel shifts.',
    'move': 'A complete eight-step running gait: 1 left foot contact with right paw forward; 2 compression and lean; 3 airborne, both short feet lifted; 4 right foot contact with left paw forward; 5 compression opposite; 6 airborne opposite; 7 left foot recovering; 8 right foot recovering to loop. Both legs and short arms clearly change pose, ears bounce; body stays centered.',
    'melee': 'Eight consecutive unarmed short-arm melee swipe poses: 1 ready, 2 crouch and draw right paw back, 3 twist and wind up, 4 powerful forward swipe IMPACT with both paws visible, 5 follow-through across body, 6 stretched recovery, 7 lower paw, 8 return to ready. Hit at frame 4, pose and silhouette dramatically change.',
    'ranged': 'Eight consecutive unarmed magic casting poses: 1 ready, 2 raise short paw, 3 bring both paws together and aim, 4 forward RELEASE with bright tiny star at hands, 5 clear recoil lean backward, 6 magic spark fades, 7 lower paws, 8 recover ready. No permanent hand-held prop; real changing poses.',
    'hurt': 'Eight consecutive impact reaction poses: 1 normal, 2 startled eyes, 3 torso and tiny arms recoil backward, 4 strong stagger, 5 squint and brace, 6 regain balance, 7 breathe, 8 normal. No blood or injury; visible changes in silhouette.',
    'dodge': 'Eight consecutive dodge-roll poses: 1 crouch, 2 lean sideways, 3 tuck ears and head, 4 roll on side, 5 roll over back with short feet in air, 6 turn forward, 7 spring to feet, 8 ready. Clear rotational movement around a fixed center; no teleport or horizontal travel.',
    'down': 'Eight consecutive nonviolent defeat poses: 1 exhausted standing, 2 knees buckle, 3 body tips sideways, 4 tumbles onto side, 5 settles prone, 6 small weak paw twitch, 7 eyes shut, 8 resting down. Silhouette genuinely changes across frames.',
    'build': 'Eight consecutive garden building poses: 1 ready, 2 crouch, 3 kneel with both paws toward the ground, 4 plant a little seed into soil, 5 tap soil down, 6 tiny sprout appears, 7 stand back up, 8 return ready. Character keeps no permanent object.',
    'item': 'Eight consecutive use-item poses: 1 ready, 2 reach into pocket, 3 lift tiny berry medicine flask, 4 hold it up, 5 use it in a flash, 6 lower paw with happy expression, 7 pocket away, 8 return ready. One temporary prop only during middle frames.',
    'skill': 'Eight consecutive unique magical skill poses: 1 gather focus, 2 short paws forward, 3 magical berry aura grows, 4 full circular burst from character, 5 recoil from magic, 6 aura shrinks, 7 happy recovery, 8 ready.',
    'victory': 'Eight consecutive joyful victory poses: 1 notice success, 2 blink in surprise, 3 both tiny paws rise, 4 leap with feet clearly off ground, 5 hold jubilant pose, 6 land softly, 7 sway and smile, 8 return to celebration-ready.',
}
VIEWS = {
    'side_idle': 'Eight lively side-view idle poses looking RIGHT: inhale, ear perk, paw twitch, blink, weight shift, tiny happy nod, tail wiggle, return. Same side-view silhouette and fixed feet.',
    'side_move': 'Eight consecutive side-view running poses looking RIGHT, left/right short feet alternate, both tiny arms swing, two clear airborne poses, ears bob; same horizontal foot pivot, no translation.',
    'back_idle': 'Eight lively BACK-VIEW idle poses with no visible face: ear twitch, small shoulder breathing, tail sway, feet shift, both little arms lift and relax; stay centered.',
    'back_move': 'Eight consecutive BACK-VIEW running poses with no visible face: alternating short feet clearly stride, arms counter-swing, ears bounce and tail flicks; same fixed center.',
}
OUTFITS = ('casual','garden','adventure','pajamas','spring','magic')
ENEMY = {
    'sprout_move': '1 left tiny root contact, 2 crouch, 3 hop upward, 4 midair with leaves raised, 5 right root contact, 6 crouch other side, 7 little hop, 8 land. Eight distinct locomotion poses, centered in cell.',
    'sprout_attack': '1 stalk, 2 leaves pull back, 3 head recoils, 4 spring forward BITE, 5 stretched impact, 6 recoil, 7 wobble, 8 return. Distinct silhouettes.',
    'wasp_move': 'Eight-frame flying loop: wings beat down/up in wide arcs while striped body banks gently; frames 1-4 full wing upstroke, 5-8 full downstroke. Wing silhouettes strongly distinct, same body scale.',
    'mushroom_move': 'Eight heavy waddling steps: mushroom cap sways left/right, feet alternate contact, torso compresses then springs up. Stable recognizable cap and face.',
    'shade_move': 'Eight wispy ghost motion frames: dusk-purple body curls and untwists, little leaf arms extend, face and white eyes stable, trailing mist changes shape.',
    'crystal_crab_move': 'Eight sidestepping poses: left/right crystalline claws alternate, four legs clearly articulate, front shield remains recognizable.',
    'bee_move': 'Eight flying wingbeat poses: transparent wings clearly open, fold, and beat, striped round body bobs without shifting off pivot.',
    'acorn_attack': 'Eight consecutive acorn seed-casting poses: eyes focus, shell leans back, tiny arms gather seed, seed shoots from hand in frame 4, recoil and settle.',
    'root_brute_move': 'Eight heavy alternating root-legged stomps: branch arms counter-swing, roots lift and plant, recognizable bark face and crown stay stable.',
    'moth_move': 'Eight soft butterfly-like wingbeats: wings fully open and close over the cycle, warm violet face stays centered.',
    'crow_move': 'Eight brisk wingbeat poses: wings stretch high then sweep down, tiny feet tuck and extend, face and beak remain recognizable.',
    'termite_attack': 'Eight gnawing poses: head pulls back, jaw opens, lunges and bites in frame 4, shakes wood chips, recovers.',
    'wasp_attack': 'Eight consecutive stinger attack poses: wingbeats tighten, abdomen curls back, frame 4 stinger thrust, wing recoil, recover.',
    'mushroom_attack': 'Eight consecutive heavy cap-slam poses: squat, cap lifts back, frame 4 sudden downward cap strike with tiny spores, recoil and recover.',
    'shade_attack': 'Eight consecutive ghost swipe poses: dusk body winds up, leaf arms stretch, frame 4 violet arc swipe, mist trails fade and reforms.',
    'crystal_crab_attack': 'Eight consecutive crystal claw attack poses: both claws pull back, one snaps forward at frame 4 with little blue sparks, resets.',
}
BOSS = {
    'snail_move': 'Eight heavy crawl poses: giant moss-shell snail stretches forward, contracts, antennae sway, shell tilts slightly; very clear extended versus compressed body frames. Keep same shell markings and face.',
    'snail_attack': 'Eight attack poses: 1 track target, 2 draw antennae back, 3 shell compresses, 4 sudden body slam impact, 5 slime burst, 6 recoil, 7 recover, 8 ready.',
    'queen_wasp_move': 'Eight flying wingbeat poses for the same crowned honey queen. Wings dramatically change down/up orientation, abdomen bends, little legs tuck/extend, crown and face stay stable.',
    'queen_wasp_attack': 'Eight charge attack poses: 1 threat, 2 gather, 3 crouch in air, 4 lunge forward with stinger, 5 impact, 6 bank away, 7 recover, 8 poised.',
    'moon_treant_move': 'Eight imposing walking poses for the same ancient moonlit flowering tree: left/right root legs alternate, branch arms swing, flowers rustle, crescent face constant.',
    'moon_treant_attack': 'Eight area-attack poses for same treant: 1 still, 2 branches rise, 3 glowing roots charge, 4 branch smash and moonlit ground shock, 5 expanding glow, 6 recoil, 7 flowers settle, 8 ready.',
    'snail_down': 'Eight gentle defeated poses for the SAME moss-shell snail: impact, eye stalks droop, soft body folds toward ground, shell tilts but never detaches, flower petals fall, quiet still body at frame 8.',
    'queen_wasp_down': 'Eight gentle defeated poses for SAME crowned honey queen: wings weaken, body descends, crown tilts, wings fold, lands softly, final still on ground; do not lose distinctive crown.',
    'moon_treant_down': 'Eight gentle defeated poses for SAME ancient moonlit flowering tree: branches sag, root legs buckle, flowers shed, trunk falls to ground, moon glow fades, settles still at frame 8.',
}
FX = {
    'spoon_swing': ('held_spoon', 'A bright cream-and-honey CRESCENT SLASH around a small wooden spoon, eight sequential frames: start at lower left, grow and rotate through upper right, peak impact at frame 4, trail fragments and fade. Weapon remains consistent.'),
    'wand_fire': ('held_wand', 'A rose-gold berry magic shot launched by the same wand: tiny charging spark, magic ring, frame 4 bright projectile release, recoil flare, then glitter trail fades. Eight clearly progressing frames.'),
    'needle_fire': ('held_needle', 'A rapid tiny crystal needle firing effect: charge, thin electric streak, frame 4 needle blast, shock ring, three progressively fading trails. Eight progressing frames.'),
    'petal_spin': ('held_petal', 'A circular pink blossom and petal melee whirl: petals gather, arc rotates through eight distinct angular positions, bright frame 4 impact, trailing petals disperse.'),
    'berry_impact': ('berry', 'A cherry-red berry projectile impact: pellet arrives, compresses, frame 4 burst into seed-shaped sparks, then expanding ring and fragments fade. Eight consecutive frames.'),
    'boss_slam': ('star', 'A giant golden garden boss ground-slam shockwave: small ground flash, layered ring builds, frame 4 bright impact and pixel debris, ring expands and fades through frame 8.'),
}

def references():
    DEST.mkdir(parents=True, exist_ok=True)
    source = Image.open(ORIGINAL/'bear_refined.png').convert('RGBA')
    midpoint = source.width//2
    for name, crop in [('yier',source.crop((0,0,midpoint,source.height))),('bubu',source.crop((midpoint,0,source.width,source.height)))]:
        path=DEST/(name+'_master.png')
        if not path.exists(): crop.save(path)

def job_prompt(name: str, action: str) -> tuple[list[Path], str]:
    layout = ('TRUE FRAME-BY-FRAME PIXEL GAME SPRITE SHEET, EXACTLY TWO ROWS BY FOUR COLUMNS = EIGHT CELLS. '
              'Read timeline LEFT TO RIGHT across top row frames 1-4, then LEFT TO RIGHT across bottom row frames 5-8. '
              'Each cell contains exactly ONE full-body figure, centered on the SAME foot pivot and at the SAME size, with 9% safe gutters. '
              'Absolutely transparent background, no floor, shadows, grid lines, labels, numbers, extra characters or cut-off body parts. '
              'Each consecutive frame must have materially different articulated limb, head, body or wing POSES, creating genuine fluid motion rather than eight slight translations of one static icon. '
              'Crisp nearest-neighbor pixel art, limited warm garden palette, precise stepped pixels, dark brown outline, clear top-down 3/4 game angle. ')
    base, _, outfit = name.partition('_')
    if base in ('yier','bubu') and outfit in OUTFITS:
        view='side' if action.startswith('side_') else 'back' if action.startswith('back_') else 'front'
        refs=[ROOT/'资产'/'精灵'/(name+'_'+view+'.png'), ORIGINAL/('v130_'+outfit+'.png')]
        identity=('Yier, the white bear with dark ears and pink cheeks' if base=='yier' else 'Bubu, the warm brown bear with cream ears and yellow cheeks')
        progression=VIEWS.get(action,HERO.get(action,''))
        return refs, layout+f' Animate ONLY {identity} wearing the exact {outfit} costume shown in the first two references; same colors, hat, garment design, short arms and tiny feet in every frame. Preserve the '+view.upper()+' VIEW of the first reference. Action progression: '+progression
    if name in ('yier','bubu'):
        identity = ('Yier is the WHITE round teddy bear with DARK BROWN tiny round ears, symmetrical dark round eyes, small w-shaped mouth, pink cheeks, huge head, tiny body, extremely short hands and feet, dark brown neck bow. '
                    if name=='yier' else
                    'Bubu is the WARM BROWN round teddy bear with cream inner ears, symmetrical dark round eyes, small w-shaped mouth, yellow cheeks, huge head, tiny body, extremely short hands and feet. ')
        identity += 'Copy this exact approved character identity from the reference, not a new design; same face proportions and cheek placements in every frame. No costumes or hats.'
        if action in VIEWS:
            view='side' if action.startswith('side_') else 'back'
            return [ROOT/'资产'/'精灵'/(name+'_'+view+'.png'), DEST/(name+'_master.png')], layout+identity+' Preserve the '+view.upper()+' VIEW from the first reference in all eight frames. Action progression: '+VIEWS[action]
        return [DEST/(name+'_master.png'), ORIGINAL/'bear_refined.png'], layout+identity+' Action progression: '+HERO[action]
    if name == 'fx':
        reference, progression = FX[action]
        return [ROOT/'资产'/'精灵'/(reference+'.png')], layout.replace('full-body figure','effect sequence') + 'No creature or character. Same material and palette as reference. Action progression: ' + progression
    identity = f'Animate exactly the SAME {name.replace("_"," ")} creature shown in the reference, preserving body features, colors, eyes and outline, same warm garden pixel language. '
    progression = ENEMY.get(name+'_'+action,BOSS.get(name+'_'+action,''))
    reference = 'v120_garden.png' if name == 'snail' else 'v140_enemies.png' if name in ('wasp','shade','crystal_crab','queen_wasp','moon_treant') else 'v120_enemies.png'
    return [ROOT/'资产'/'精灵'/(name+'.png'), ORIGINAL/reference], layout+identity+' Action progression: '+progression

def jobs_for(group: str) -> list[tuple[str,str]]:
    pilot=[('yier','idle'),('yier','move'),('bubu','idle'),('bubu','move'),('bubu','melee'),('yier','ranged'),('sprout','move'),('sprout','attack')]
    if group=='pilot': return pilot
    if group=='heroes': return [(c,a) for c in ('yier','bubu') for a in HERO if (c,a) not in pilot]
    if group=='enemies': return [tuple(k.rsplit('_',1)) for k in ENEMY if tuple(k.rsplit('_',1)) not in pilot]
    if group=='bosses': return [tuple(k.rsplit('_',1)) for k in BOSS]
    if group=='boss_deaths': return [tuple(k.rsplit('_',1)) for k in BOSS if k.endswith('_down')]
    if group=='enemy_attacks': return [tuple(k.rsplit('_',1)) for k in ENEMY if k.endswith('_attack')]
    if group=='effects': return [('fx', key) for key in FX]
    if group=='views': return [(c,a) for c in ('yier','bubu') for a in VIEWS]
    if group=='outfits_front': return [(c+'_'+o,a) for c in ('yier','bubu') for o in OUTFITS for a in ('idle','move')]
    if group=='outfits_directional': return [(c+'_'+o,a) for c in ('yier','bubu') for o in OUTFITS for a in ('side_move','back_move')]
    return []

def generate(job: tuple[str,str]) -> tuple[str,str]:
    name,action=job
    output=DEST/(f'{name}_{action}.png')
    if output.exists() and output.stat().st_size>100_000: return output.name,'cached'
    refs,prompt=job_prompt(name,action)
    args=['pwsh','-NoProfile','-File',str(SKILL),'-Command','edit','-Image',*[str(p) for p in refs],'-Prompt',prompt,'-Size','1536x1024','-Quality','high','-Output',str(output)]
    for attempt in range(3):
        try:
            result=subprocess.run(args,capture_output=True,text=True,timeout=150)
            if result.returncode==0 and output.exists() and output.stat().st_size>100_000: return output.name,'generated'
            reason=result.stderr or result.stdout
        except subprocess.TimeoutExpired:
            reason='image25 request timed out'
        if attempt==2: return output.name,('FAILED: '+reason[-450:])
        time.sleep(10*(attempt+1))
    return output.name,'FAILED'

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('group',choices=['pilot','heroes','enemies','bosses','boss_deaths','enemy_attacks','effects','views','outfits_front','outfits_directional'])
    parser.add_argument('--workers',type=int,default=2)
    args=parser.parse_args()
    references()
    failed=[]
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        for future in as_completed([pool.submit(generate,job) for job in jobs_for(args.group)]):
            name,status=future.result()
            print(name,status,flush=True)
            if status.startswith('FAILED'): failed.append(name)
    if failed: raise SystemExit(f'{len(failed)} image25 requests failed: '+', '.join(failed))
