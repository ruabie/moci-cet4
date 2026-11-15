#!/usr/bin/env python3
"""Original contiguous facades for LifeSim V0.7: real front apertures, no overlay walls.
Standalone standard-library builder, GLB written with the project's own Gltf class.
"""
import pathlib
import sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
from build_assets import Gltf

SPECS={
 "mart":(21.,10.,17.,(.46,.44,.38),(.15,.23,.21)),
 "coffee":(20.,13.,17.,(.39,.32,.27),(.29,.19,.15)),
 "apartment":(21.,18.,18.,(.47,.40,.34),(.32,.35,.31)),
 "living":(20.,12.,19.,(.40,.45,.40),(.30,.34,.26)),
}
def quad(g,mat,p):
 g.add_mesh(mat,p,[(0,1,2),(0,2,3)])
def front(g,mat,x,y0,y1,z0,z1):
 quad(g,mat,[(x,y0,z0),(x,y1,z0),(x,y1,z1),(x,y0,z1)])
def holes_for(kind,h,d):
 if kind=="mart":
  slots=[(.38,3.72,-7.1,-2.5),(.10,3.64,-1.28,1.24),(.38,3.72,2.48,7.1)]
 elif kind=="coffee":
  slots=[(.42,3.62,-7.13,-3.18),(.42,3.62,-2.25,2.25),(.10,3.57,3.12,7.08)]
 elif kind=="apartment":
  slots=[(.43,3.60,-7.1,-2.9),(.10,3.64,-1.2,1.2),(.43,3.60,2.9,7.1)]
 else:
  slots=[(.40,3.67,-7.9,-3.6),(.12,3.58,-2.48,.18),(.40,3.67,1.4,7.9)]
 count=4 if kind=="apartment" else 3 if kind=="coffee" else 4
 rows=[5.3,8.2,11.15,14.1] if h>=17 else [5.5,8.3] if h>=12 else [5.4]
 for y in rows:
  for k in range(count):
   step=d/(count+.20)
   z0=-d/2+step*(k+.55)
   z1=min(d/2-.7,z0+step*.66)
   if y+1.85 < h-.55: slots.append((y,y+1.75,z0,z1))
 return slots
def one(kind,spec):
 depth,h,d,wall_rgb,trim_rgb=spec
 g=Gltf()
 wall=g.material("continuous_masonry",wall_rgb,rough=.93)
 stone=g.material("stone_reveal",(.37,.36,.33),rough=.89)
 trim=g.material("integrated_fascia",trim_rgb,metal=.28,rough=.55)
 frame=g.material("window_joinery",(.13,.17,.17),metal=.5,rough=.47)
 roof=g.material("zinc_roof",(.22,.24,.24),metal=.34,rough=.68)
 timber=g.material("interior_oak",(.43,.33,.25),rough=.77)
 glazing=g.material("recessed_glazing",(.20,.31,.35),metal=.12,rough=.25)
 g.materials[glazing]["alphaMode"]="BLEND"
 g.materials[glazing]["pbrMetallicRoughness"]["baseColorFactor"][3]=.77
 warm=g.material("light_diffuser",(.93,.78,.58),emissive=(.18,.12,.07))
 paper=g.material("display_cards",(.89,.84,.75),rough=.94)
 green=g.material("planter_green",(.23,.34,.27),rough=.88)
 pots=g.material("terracotta",(.50,.37,.28),rough=.94)
 slots=holes_for(kind,h,d)
 ys=sorted(set([0.,h]+[s[0] for s in slots]+[s[1] for s in slots]))
 zs=sorted(set([-d/2,d/2]+[s[2] for s in slots]+[s[3] for s in slots]))
 # True openings: masonry faces are tiled as a single coplanar surface, never an opaque backer wall.
 for ya,yb in zip(ys,ys[1:]):
  for za,zb in zip(zs,zs[1:]):
   cy,cz=(ya+yb)*.5,(za+zb)*.5
   if any(y0<cy<y1 and z0<cz<z1 for y0,y1,z0,z1 in slots):continue
   front(g,wall,0,ya,yb,za,zb)
 for y0,y1,z0,z1 in slots:
  x=-.46
  quad(g,wall,[(0,y0,z0),(x,y0,z0),(x,y0,z1),(0,y0,z1)])
  quad(g,wall,[(0,y1,z1),(x,y1,z1),(x,y1,z0),(0,y1,z0)])
  quad(g,wall,[(0,y0,z0),(0,y1,z0),(x,y1,z0),(x,y0,z0)])
  quad(g,wall,[(0,y1,z1),(0,y0,z1),(x,y0,z1),(x,y1,z1)])
  ym,zm=(y0+y1)*.5,(z0+z1)*.5
  g.box(glazing,(-.39,ym,zm),(.07,y1-y0-.05,z1-z0-.06))
  for yy in (y0+.055,y1-.055):
   g.box(frame,(-.36,yy,zm),(.10,.085,z1-z0+.04))
  for zz in (z0+.05,z1-.05):
   g.box(frame,(-.36,ym,zz),(.10,y1-y0,.09))
  if y0>4.7:
   g.box(stone,(.06,y0-.11,zm),(.56,.16,z1-z0+.20))
   g.box(frame,(-.32,ym,zm),(.06,y1-y0-.10,.055))
  elif y0<.2:
   g.box(timber,(-.44,1.63,zm+.05),(.04,2.5,.10))
   g.box(frame,(-.23,1.67,zm+.38),(.08,.43,.055))
  else:
   g.box(frame,(-.32,ym,zm),(.05,.06,z1-z0-.14))
   for shelf_y in (1.05,1.83,2.5):
    g.box(timber,(-1.03,shelf_y,zm),(.53,.09,(z1-z0)*.6))
    for k in range(3):
     zz=z0+.45+(z1-z0-.9)*k/2.
     g.box(paper,(-1.00,shelf_y+.2,zz),(.18,.31,.23))
 # Building envelope extends inward from the street, with true visible corners.
 quad(g,wall,[(-depth,0,-d/2),(0,0,-d/2),(0,h,-d/2),(-depth,h,-d/2)])
 quad(g,wall,[(0,0,d/2),(-depth,0,d/2),(-depth,h,d/2),(0,h,d/2)])
 quad(g,wall,[(-depth,0,d/2),(-depth,0,-d/2),(-depth,h,-d/2),(-depth,h,d/2)])
 g.box(stone,(-.01,.18,0),(.52,.36,d+.1))
 for z in (-d/2+.16,d/2-.16): g.box(stone,(.01,h*.51,z),(.42,h-.74,.36))
 g.box(roof,(-depth/2,h+.1,0),(depth+.7,.20,d+.55))
 g.box(roof,(-depth/2,h+.48,0),(depth-.6,.6,d-.18))
 # Continuous, structural shop sign fascia and under-canopy light slot.
 g.box(trim,(.12,4.32,0),(.35,.77,d-.55))
 g.box(frame,(.19,3.89,0),(.24,.08,d-.75))
 g.box(frame,(.19,4.79,0),(.24,.07,d-.75))
 g.box(timber,(-.16,3.82,0),(.95,.13,d-.6))
 g.box(trim,(.16,3.96,0),(.92,.08,d-.6))
 for z in (-d/2+1.25,0,d/2-1.25):
  g.box(warm,(.3,3.73,z),(.35,.05,.47))
 for z in (-d/2+1.2,d/2-1.35):
  g.box(pots,(1.06,.36,z),(.73,.72,.67))
  g.sphere(green,(1.06,1.12,z),(.53,.68,.48),rings=9,sides=14)
 if kind=="coffee":
  g.box(timber,(.75,3.96,0),(1.3,.12,d-.74))
  g.box(paper,(1.24,1.45,5.95),(.04,1.56,.72))
 elif kind=="apartment":
  g.box(frame,(.25,1.62,2.0),(.12,.88,.42))
 else:
  g.box(trim,(.36,3.93,0),(1.15,.12,d-1.0))
 g.box(stone,(1.15,.09,0),(2.45,.18,d-1.2))
 g.box(frame,(2.43,.08,0),(.065,.07,d-1.25))
 dest="art/architecture/v07_%s_integrated.glb"%kind
 g.save(dest)
 print("V07",kind,"openings",len(slots))
if __name__=="__main__":
 for kind,spec in SPECS.items():one(kind,spec)
