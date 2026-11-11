#!/usr/bin/env python3
"""Builds docs/Flick_Freight_GDD.pdf, the game design document.

The level tables are read from scripts/levels.gd, so rerun this after changing levels:
    python3 tools/make_gdd.py
Needs: reportlab, Pillow, DejaVu fonts (fonts-dejavu-core).
Keep RET and WO below in sync with RETIRED and WORLD_ORDER in scripts/levels.gd.
"""
import os, re, ast, json
R=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))+'/'
src=open(R+'scripts/levels.gd').read()
s=src.index('const DATA = [')+len('const DATA = ')
depth=0
for i,ch in enumerate(src[s:]):
    if ch=='[':depth+=1
    elif ch==']':
        depth-=1
        if depth==0: e=s+i+1;break
txt=src[s:e]
txt='\n'.join(re.sub(r'#.*$','',l) if '"' not in l.split('#')[0] or True else l for l in txt.split('\n'))
txt=txt.replace('true','True').replace('false','False')
data=ast.literal_eval(txt)
RET=[32,33,34,95]; WO=[0,1,2,3,4,5,7,8,6]
names=["TOWN","WOODS","DESERT","HARBOR","SNOW","FREIGHT YARD","SKY PORT","DOWNTOWN","CONSTRUCTION"]
order=[i for w in WO for a in (1,2) for i,d in enumerate(data) if d['world']==w and d.get('act',1)==a and i not in RET]
out=[]
for n,i in enumerate(order,1):
    d=data[i]
    trucks=d.get('trucks') or [d.get('truck',{})]
    veh=[t.get('vehicle','truck') for t in trucks]
    mov=[m['type'] for m in d.get('movers',[])]
    out.append(dict(n=n,id=i,world=names[d['world']],act=d.get('act',1),cargo=d['cargo'],goal=d.get('goal'),s2=d.get('s2'),need=d.get('need'),ts=d.get('throw_stars'),veh=veh,mov=mov,wind=d.get('wind',0),pads=len(d.get('pads',[])),blocks=len(d.get('blocks',[])),moving=any(t.get('amp',0) for t in trucks),ferry=any('ferry' in t for t in trucks),icy=any(t.get('icy') for t in trucks),intro=d.get('intro',{}).get('title'),introtext=d.get('intro',{}).get('text'),water='water' in d, hl='height_limit' in d))

from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.platypus import (BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer, Table,
    TableStyle, Image, PageBreak, KeepTogether, NextPageTemplate)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
pdfmetrics.registerFont(TTFont('Fredoka',R+'art/v2/font/fredoka.ttf'))
pdfmetrics.registerFont(TTFont('Sans','/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'))
pdfmetrics.registerFont(TTFont('SansB','/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'))
from reportlab.lib.fonts import addMapping
addMapping('Sans',0,0,'Sans');addMapping('Sans',1,0,'SansB');addMapping('Sans',0,1,'Sans');addMapping('Sans',1,1,'SansB')
INK=colors.HexColor('#1f2a3a'); MUTED=colors.HexColor('#5b6778'); ACC=colors.HexColor('#e8762c'); BLUE=colors.HexColor('#2f6db5')
LIGHT=colors.HexColor('#f3f5f8'); LINE=colors.HexColor('#d5dbe3')
H1=ParagraphStyle('h1',fontName='Fredoka',fontSize=20,leading=24,textColor=INK,spaceBefore=4,spaceAfter=8)
H2=ParagraphStyle('h2',fontName='Fredoka',fontSize=13.5,leading=17,textColor=BLUE,spaceBefore=10,spaceAfter=4)
B=ParagraphStyle('b',fontName='Sans',fontSize=9.6,leading=14,textColor=INK,spaceAfter=5)
BL=ParagraphStyle('bl',parent=B,leftIndent=12,bulletIndent=2,spaceAfter=2.5)
SM=ParagraphStyle('sm',parent=B,fontSize=8,leading=10.5,spaceAfter=0)
SMB=ParagraphStyle('smb',parent=SM,fontName='SansB')
CAP=ParagraphStyle('cap',parent=B,fontSize=8,leading=10,textColor=MUTED,alignment=1)
L=out
W=A4[0]-36*mm
def p(t,st=B): return Paragraph(t,st)
def bullets(items): return [Paragraph(i,BL,bulletText='•') for i in items]
def tbl(rows,cw,head=True,fs=SM):
    data=[[x if not isinstance(x,str) else Paragraph(x,SMB if (head and r==0) else fs) for x in row] for r,row in enumerate(rows)]
    t=Table(data,colWidths=cw,repeatRows=1 if head else 0)
    st=[('GRID',(0,0),(-1,-1),0.4,LINE),('VALIGN',(0,0),(-1,-1),'TOP'),
        ('TOPPADDING',(0,0),(-1,-1),3),('BOTTOMPADDING',(0,0),(-1,-1),3),('LEFTPADDING',(0,0),(-1,-1),4),('RIGHTPADDING',(0,0),(-1,-1),4)]
    if head: st.append(('BACKGROUND',(0,0),(-1,0),LIGHT))
    t.setStyle(TableStyle(st)); return t
def img(path,w,cap=None):
    from PIL import Image as PI
    a=PI.open(path); h=w*a.size[1]/a.size[0]
    out=[Image(path,w,h)]
    if cap: out.append(p(cap,CAP))
    return out

def deco(c,doc):
    c.saveState()
    c.setFont('Sans',7.5);c.setFillColor(MUTED)
    c.drawString(18*mm,10*mm,'Flick Freight · Game Design Document')
    c.drawRightString(A4[0]-18*mm,10*mm,str(doc.page))
    c.setStrokeColor(ACC);c.setLineWidth(1.2);c.line(18*mm,A4[1]-13*mm,A4[0]-18*mm,A4[1]-13*mm)
    c.restoreState()
def cover(c,doc):
    c.saveState()
    c.setFillColor(colors.HexColor('#1f2a3a'));c.rect(0,0,A4[0],A4[1],fill=1,stroke=0)
    iw=A4[0]; ih=iw*1080/1920
    c.drawImage(R+'marketing/covers/cover_landscape_1920x1080.png',0,A4[1]-ih,iw,ih)
    y=A4[1]-ih-28*mm
    c.setFillColor(colors.white);c.setFont('Fredoka',40);c.drawString(20*mm,y,'Flick Freight')
    c.setFillColor(ACC);c.setFont('Fredoka',18);c.drawString(20*mm,y-11*mm,'Game Design Document')
    c.setFillColor(colors.HexColor('#c9d2de'));c.setFont('Sans',10.5)
    for k,t in enumerate(['A physics loading game for the web: drag, aim, and throw cargo into the truck.',
                          '96 levels · 9 worlds · 1 to 3 stars per level',
                          'Engine: Godot 4.3 (web export) · Target portal: CrazyGames']):
        c.drawString(20*mm,y-24*mm-k*6.5*mm,t)
    c.setFont('Sans',8.5);c.setFillColor(colors.HexColor('#8e9aab'))
    c.drawString(20*mm,22*mm,'Version 1.0 · November 2026 · Written from the game\'s repository (scripts/levels.gd, README, docs/)')
    c.restoreState()

doc=BaseDocTemplate(R+'docs/Flick_Freight_GDD.pdf',pagesize=A4,leftMargin=18*mm,rightMargin=18*mm,topMargin=18*mm,bottomMargin=17*mm,
    title='Flick Freight – Game Design Document',author='Flick Freight team')
fr=Frame(doc.leftMargin,doc.bottomMargin,doc.width,doc.height,id='f')
doc.addPageTemplates([PageTemplate('cover',[fr],onPage=cover),PageTemplate('body',[fr],onPage=deco)])
s=[NextPageTemplate('body'),PageBreak()]

# --- contents
s+= [p('Contents',H1)]
toc=['1. Overview','2. Goal and core loop','3. Controls','4. Scoring and stars','5. Progression and unlocks',
     '6. Cargo types','7. Mechanics','8. Vehicles','9. Moving obstacles','10. The nine worlds',
     '11. Difficulty curve','12. Presentation: art, audio, UI','13. Platform and technology','14. Quality assurance','Appendix A. Full level list']
s+= bullets(toc)
s+= [Spacer(1,8), p('<b>About this document.</b> A Game Design Document (GDD) describes what a game is and how it plays: its goal, rules, mechanics, content and progression. It is the game industry\'s counterpart to a Product Requirements Document (PRD). Everything here reflects the game as it is built in the repository today, not a plan.',B)]
s+=[PageBreak()]

# 1
s+=[p('1. Overview',H1),
 p('<b>Flick Freight</b> is a casual 2D physics game. The player stands at a loading dock and throws cargo into a waiting vehicle with a slingshot-style drag. Each level gives a fixed queue of cargo and a vehicle to fill. Loading enough cargo passes the level; loading all of it earns three stars.'),
 p('The game is short-session and skill-based: no timers, no randomness. Every moving thing runs on the level clock, so a level plays out the same way on every restart and players can learn its rhythm.'),
 tbl([['Item','Value'],['Genre','Physics puzzle / skill-throw (casual)'],['Platform','Web (HTML5), desktop and mobile browsers; mouse or touch'],
      ['Engine','Godot 4.3, single-threaded web export'],['Session length','About 30–90 seconds per level'],
      ['Content','96 levels across 9 worlds; 9 cargo types, 11 vehicles, 8 moving obstacles'],
      ['Audience','All ages; casual web players (CrazyGames portal)'],['Monetization hooks','CrazyGames SDK v3 gameplay events (start/stop, happytime)']],[40*mm,W-40*mm]),
 Spacer(1,8)]+img(R+'docs/screens/plan2-phase-b/level_47.png',W*0.8,'Harbor: the dock on the left, a forklift patrolling the quay, a bounce pad and the truck on the right.')
s+=[PageBreak()]

# 2
s+=[p('2. Goal and core loop',H1),
 p('<b>Player goal:</b> load the vehicle with as much cargo as possible from the queue at the dock. The long-term goal is to unlock and finish all nine worlds and collect every star.'),
 p('<b>Core loop (one throw):</b>'),
 *bullets(['<b>Read</b> the scene: vehicle position and motion, obstacles, wind flag, the next cargo in the queue.',
           '<b>Aim:</b> press anywhere and drag back. A dotted arc previews the throw (in later levels the arc gets shorter, so players rely on feel).',
           '<b>Release</b> to throw. The cargo flies under real physics.',
           '<b>Result:</b> the cargo lands in the vehicle (delivered), misses, or breaks. The HUD counter updates.',
           '<b>Repeat</b> until the queue is empty, then the level is scored.']),
 p('<b>Level loop:</b> intro banner (when a new mechanic appears) → throws → stacks settle → results screen with stars → next level or retry.'),
 p('<b>Meta loop:</b> win levels → open the next level, Act II and the next world → collect stars shown on the menu and level select.'),
 p('<b>Loose cargo.</b> Delivered cargo is not glued down. Stacks can shift or topple, and anything that falls out stops counting. The game waits a moment for stacks to settle before scoring, so stacking well matters as much as aiming well.'),
 p('3. Controls',H1),
 tbl([['Input','Action'],['Press, drag back, release (mouse or touch)','Aim and throw; longer drag = more power'],['P','Pause'],['R','Restart level'],
      ['Home button (pause / results)','Back to main menu']],[70*mm,W-70*mm]),
 p('4. Scoring and stars',H1),
 p('Most levels score by how much cargo ends up in the vehicle:'),
 tbl([['Stars','Standard levels','Few-throws levels (helicopter, balloon)'],
      ['★','Load the pass goal','Load the required amount'],
      ['★★','Load the 2-star goal','…within a set number of throws'],
      ['★★★','Load every piece of cargo','…within fewer throws']],[20*mm,(W-20*mm)/2,(W-20*mm)/2]),
 Spacer(1,4),
 p('Example: level 1 has 4 boxes; 2 delivered = 1 star, 3 = 2 stars, all 4 = 3 stars. The courier motorcycle levels give 3 boxes for a tiny rack: 1 passes, 3 is "legendary". Total available: 288 stars (96 × 3).'),
]
s+=[PageBreak()]
# 5
s+=[p('5. Progression and unlocks',H1),
 *bullets(['Each world has an <b>Act I</b> and (for the first six worlds) an <b>Act II</b> of 5 harder levels that reuse the world\'s theme with new vehicles and moving obstacles.',
           'Levels in an act unlock one after another: win a level (any stars) to open the next.',
           'Act II opens once the world\'s Act I is complete.',
           'The next world opens once every level of the current world (Act I and Act II) has been won at least once.',
           'A won level never locks again. Progress (stars, mute, tutorial) is saved locally on the device.',
           'The main menu opens on the next unbeaten level; PLAY starts it, LEVELS opens level select (one page per world).']),
 p('World order: Town → Woods → Desert → Harbor → Snow → Freight Yard → Downtown → Construction → Sky Port (the finale).'),
 p('6. Cargo types',H1),
 tbl([['Cargo','Behaviour','First seen'],
      ['Box','Standard, light, stacks well','Town'],['Heavy crate','Needs a stronger pull; good as a stopper','Town'],
      ['Barrel','Tall, tips over; land it gently','Woods'],['Fragile','Each bump cracks it; the 3rd bump breaks it','Woods'],
      ['Ice block','Slides until something stops it','Snow'],['Tire','Bounces; drop it in softly','Snow'],
      ['Plank','Long, spins at a fixed rate in flight; counts at any angle; can form a shelf','Snow'],
      ['Gas canister','Pops on a hard landing and knocks nearby cargo out','Freight Yard'],
      ['Parcel','Flat; fits through the mail van\'s slot','Downtown']],[30*mm,W-60*mm,30*mm]),
 p('7. Mechanics',H1),
 p('New ideas are introduced one at a time, each with a short banner the first time it appears.'),
 tbl([['Mechanic','What it asks of the player'],
      ['Moving truck','Lead the throw: the vehicle drives back and forth'],
      ['Pillar / low beam','Lob high over a pillar, or keep throws under a beam'],
      ['Wind','Sideways push; the aim arc ignores it, so read the flag'],
      ['Tall tailgate','Drop cargo in steeply from above'],
      ['Bounce pad','Bank shots off a spring, including downward throws; never cracks fragile cargo'],
      ['Ferry / open water','The truck bobs on waves; cargo in the water splashes (miss)'],
      ['Icy truck bed','Everything slides on the bed'],
      ['Multiple vehicles','Fill several at once (flatcars, two helicopters, van + food truck)'],
      ['Few-throws scoring','Stars for efficiency instead of volume'],
      ['Moving obstacles','Time throws around cranes, trees, windmills and more (section 9)']],[45*mm,W-45*mm]),
]
s+=[PageBreak()]
# 8
s+=[p('8. Vehicles',H1),
 tbl([['Vehicle','World','Twist'],
      ['Truck','All early worlds','Open bed with a rear wall; can move, ride a ferry, or have an icy bed'],
      ['Courier motorcycle','Town','3 boxes on a tiny rack'],
      ['Garbage truck','Town, Downtown','Small hopper: throw high and steep'],
      ['Pickup','Woods','Short bed, low sides: soft throws stay, hard ones slide out'],
      ['Dump truck','Desert, Construction','Tilted bed; land heavy crates first as stoppers'],
      ['Flatbed','Freight Yard, Construction','No sides: stack neatly and keep balance'],
      ['Flatcars (train)','Freight Yard','Roll past once; fill each as it passes'],
      ['Mail van','Downtown','Parcels through a slot in the back door: throw flat'],
      ['Food truck','Downtown','In through the serving window, under the awning'],
      ['Helicopter','Sky Port','Net on a swinging cable; later bobs and drifts'],
      ['Hot-air balloon','Sky Port','Basket rises and sinks; throw under the balloon']],[34*mm,38*mm,W-72*mm]),
 p('9. Moving obstacles',H1),
 p('Obstacles move on the level clock, so they are identical on every restart. Warning lights and sounds tell the player what is coming.'),
 tbl([['Obstacle','World','Behaviour'],
      ['Gantry crane','Harbor','Swinging container; listen for the creak'],
      ['Forklift','Harbor, Construction','Patrols the quay and raises its pallet into the path'],
      ['Swaying tree','Woods','Treetop leans in the wind; throw over or past it'],
      ['Windmill','Desert','Thread throws between turning blades'],
      ['Tumbleweed','Desert','Bounces across the sand and can bat cargo away'],
      ['Ski lift','Snow','Chairs move along a cable; land and ride, or bank off them'],
      ['Conveyor','Freight Yard, Construction','Carries cargo toward the truck'],
      ['Tower crane','Construction','Beam swings and slides along the jib']],[34*mm,38*mm,W-72*mm]),
 Spacer(1,6),
]
row=[]
for f,c in [('c/level_52','Woods: pickup'),('c/level_61','Snow: ski lift'),('d/level_71','Sky Port: helicopter')]:
    row.append(img(R+'docs/screens/plan2-phase-'+f+'.png',W/3-4,c))
s.append(Table([row],colWidths=[W/3]*3,style=[('LEFTPADDING',(0,0),(-1,-1),2),('RIGHTPADDING',(0,0),(-1,-1),2)]))
s+=[PageBreak()]

# 10 worlds
worlds=[('TOWN','Tutorial world. Throwing, moving trucks, heavy crates.','Courier motorcycle and garbage truck.'),
 ('WOODS','Pillars, barrels, fragile cargo, low beams.','Swaying trees and the pickup.'),
 ('DESERT','Headwind and tailwind, tall tailgates.','Windmill, tumbleweed and the dump truck.'),
 ('HARBOR','Bounce pads, bank shots, trucks on ferries, open water.','Gantry crane and forklift.'),
 ('SNOW','Ice blocks, icy truck beds, bouncy tires, spinning planks.','Ski lift with ice cargo.'),
 ('FREIGHT YARD','Gas canisters; "Grand Finale" with one of everything.','Conveyor, flatbed, rolling flatcars.'),
 ('DOWNTOWN','Mail van slot, food truck window, garbage truck, wind.','(single act, 10 levels)'),
 ('CONSTRUCTION','Tower cranes over dump trucks and flatbeds, forklift, conveyor.','(single act, 9 levels)'),
 ('SKY PORT','Finale: helicopter nets and hot-air balloons, few-throws scoring.','(single act, 10 levels)')]
s+=[p('10. The nine worlds',H1),p('Each world has its own backdrop, music loop and lead vehicle. Level numbers are the ones players see.')]
rows=[['#','World','Levels','Act I focus','Act II focus','Boss level']]
for k,(w,a1,a2) in enumerate(worlds,1):
    ls=[o for o in L if o['world']==w]
    boss=[o for o in ls if o['intro'] and ('BOSS' in o['intro'] or o['intro'] in ('FINAL RUN','HARBOR RUN','GRAND FINALE','LAST DELIVERY'))]
    b='; '.join(f"{o['n']} {o['intro'].title()}" for o in boss) or '–'
    rows.append([str(k),'<b>'+w.title()+'</b>',f"{ls[0]['n']}–{ls[-1]['n']}<br/>({len(ls)})",a1,a2,b])
s.append(tbl(rows,[7*mm,24*mm,17*mm,50*mm,42*mm,W-140*mm]))
s+=[Spacer(1,8)]
# per-world new mechanics
for w,_,_ in worlds:
    ls=[o for o in L if o['world']==w]
    intros=[f"<b>{o['n']}</b> {o['intro'].title()}: {o['introtext']}" for o in ls if o['intro']]
    s.append(KeepTogether([p(w.title()+f" (levels {ls[0]['n']}–{ls[-1]['n']})",H2)]+[Paragraph(t,BL,bulletText='•') for t in intros]))

# 11
s+=[PageBreak(),p('11. Difficulty curve',H1),
 *bullets(['<b>One new idea at a time.</b> Each mechanic gets an intro level, then is combined with earlier ones, and each world ends on a boss level that uses everything.',
           '<b>Shrinking aim guide.</b> The dotted arc shows the whole path in level 1 and only 30–40% of it in late levels.',
           '<b>Act II as an optional-feeling remix.</b> Each early world\'s Act II adds a vehicle or moving obstacle, with gentle first levels (6 plain boxes) before the boss.',
           '<b>Fair repetition.</b> No randomness: failing teaches the timing for the next attempt.',
           '<b>Tuned by bot.</b> A QA bot plays every level with perfect aim and with simulated human aim error; levels the "human" bot cannot clear get looked at.',
           'Four levels were retired as not fun (Snow height-limit/truck-swap levels and one Construction level); they keep their IDs so saves stay valid.']),
 p('12. Presentation: art, audio, UI',H1),
 *bullets(['Side-view 2D, flat cartoon style. Kenney CC0 sprites plus code-drawn backdrops and vehicles; Fredoka font.',
           'Each world has its own music loop; sound effects for throws, hits on wood and metal, breaks, splashes, bounces, delivery and win/lose.',
           'HUD: level name, "LOADED x / y" counter with star marks, mute and pause. Banners introduce mechanics; pop-ups show SWISH!, MISS and similar feedback.',
           'Screens: main menu over a live level, level select with one page per world and lock messages, pause, results with stars.',
           'Readable at CrazyGames\' smallest frame (907×510).']),
 p('13. Platform and technology',H1),
 *bullets(['Godot 4.3, GDScript; single-threaded web export with a custom HTML shell.',
           'All level data lives in one file (scripts/levels.gd); a level is a dictionary of cargo, goals, vehicle, obstacles and intro text.',
           'Level IDs are permanent save keys; the displayed number follows play order.',
           'CrazyGames SDK v3: loading start/stop, gameplay start/stop on level start, pause, resume and end, and "happytime" when a world\'s last level is beaten.',
           'Target: 60 fps on the portal\'s minimum spec. Moving obstacles are kinematic bodies driven by the level clock.']),
 p('14. Quality assurance',H1),
 *bullets(['QA bot plays every level (analytic solver for early levels, search solver after) and fails the build if any level cannot be passed.',
           'Frozen-level hash check and a parity snapshot make sure older levels never change by accident.',
           'Replay check (new levels must replay identically 3 times), layout check (no vehicle drives through an obstacle), save-compatibility tests.',
           'All checks run in CI on every branch; GitHub Pages hosts a test build.']),
]
# appendix
s+=[PageBreak(),p('Appendix A. Full level list',H1),
 p('Cargo legend: b box, c heavy crate, r barrel, f fragile, i ice block, t tire, p plank, g gas canister, m parcel. Goals: ★ / ★★ / ★★★ = number delivered; for few-throws levels: load N, with ★★★ / ★★ throw limits.',SM),Spacer(1,4)]
VN={'truck':'Truck','moto':'Motorcycle','garbage':'Garbage truck','pickup':'Pickup','dump':'Dump truck','flatbed':'Flatbed','flatcar':'Flatcar','heli':'Helicopter','balloon':'Balloon','mailvan':'Mail van','foodtruck':'Food truck'}
MN={'crane':'crane','forklift':'forklift','tree':'tree','windmill':'windmill','tumbleweed':'tumbleweed','ski_lift':'ski lift','conveyor':'conveyor','tower_crane':'tower crane'}
rows=[['#','World','Act','Cargo','Stars','Vehicle','Features','New idea']]
for o in L:
    from collections import Counter
    vc=Counter(o['veh']); veh=', '.join((f"{n}× " if n>1 else '')+VN[v] for v,n in vc.items())
    feat=[]
    if o['moving']: feat.append('moving')
    if o['wind']: feat.append('wind '+('→' if o['wind']>0 else '←'))
    if o['blocks']: feat.append('static block')
    if o['pads']: feat.append('pad')
    if o['ferry']: feat.append('ferry')
    if o['icy']: feat.append('icy bed')
    feat+= sorted(set(MN[m] for m in o['mov']))
    if o['need']: st=f"load {o['need']}; ≤{o['ts'][0]} / ≤{o['ts'][1]} throws"
    else: st=f"{o['goal']} / {o['s2']} / {len(o['cargo'])}"
    rows.append([str(o['n']),o['world'].title(),'I' if o['act']==1 else 'II',o['cargo'],st,veh,', '.join(feat) or '–',(o['intro'] or '').title()])
s.append(tbl(rows,[8*mm,22*mm,9*mm,20*mm,28*mm,26*mm,34*mm,W-147*mm]))
doc.build(s)
