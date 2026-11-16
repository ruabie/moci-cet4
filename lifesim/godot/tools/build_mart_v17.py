#!/usr/bin/env python3
"""Deterministic original PBR-lite color and normal textures, no external images."""
from pathlib import Path
from PIL import Image
import random, math
out=Path(__file__).resolve().parents[1]/'art'/'interiors_v17'
out.mkdir(parents=True,exist_ok=True)
N=512
for kind,rgb in [
 ('ivory_tile',(218,212,202)),
 ('warm_plaster',(227,221,211)),
 ('ash_wood',(176,146,116)),
]:
    random.seed('v17-'+kind)
    img=Image.new('RGB',(N,N))
    heights=[0]*(N*N)
    for y in range(N):
        for x in range(N):
            grain=0.
            if kind=='ivory_tile':
                grain=-27 if x%128<2 or y%128<2 else random.uniform(-2,2)
            elif kind=='warm_plaster':
                grain=2*math.sin(x/72+y/90)+random.uniform(-2.2,2.2)
            else:
                grain=6*math.sin(y*.09+math.sin(x*.013)) + 2*math.sin(y*.027)+random.uniform(-1,1)
            heights[y*N+x]=grain
            img.putpixel((x,y),tuple(max(0,min(255,int(c+grain))) for c in rgb))
    img.save(out/(kind+'_base.png'),optimize=True)
    normal=Image.new('RGB',(N,N))
    for y in range(N):
        for x in range(N):
            left=heights[y*N+max(0,x-1)]
            right=heights[y*N+min(N-1,x+1)]
            up=heights[max(0,y-1)*N+x]
            down=heights[min(N-1,y+1)*N+x]
            sx=max(-1,min(1,(left-right)*.045))
            sy=max(-1,min(1,(up-down)*.045))
            z=1/math.sqrt(1+sx*sx+sy*sy)
            normal.putpixel((x,y),(int((sx*z+1)*127.5),int((sy*z+1)*127.5),int((z+1)*127.5)))
    normal.save(out/(kind+'_normal.png'),optimize=True)
print('V17 ART BUILD PASS: 3 original color and 3 normal textures')
