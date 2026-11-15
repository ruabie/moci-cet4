#!/usr/bin/env python3
"""Generate subtle original, repeatable surface textures for V0.12 interiors.

No external model downloads or unlicensed stock images; stable seed allows CI
reproduction. These are color textures, not claimed to be scanned PBR materials.
"""
from pathlib import Path
from random import Random
import math, hashlib, zlib, struct

root=Path(__file__).resolve().parents[1] / 'art' / 'interiors_v12'
root.mkdir(parents=True,exist_ok=True)
W=512
rng=Random(12012)

def constrain(v):return max(0,min(255,int(v)))
def grain(color, delta):return tuple(constrain(c+rng.gauss(0,delta)) for c in color)

def wood():
    px=[[None]*W for _ in range(W)]
    base=[(124,91,65),(133,99,73),(116,83,62),(145,108,79),(129,94,69),(137,102,73),(119,86,64),(142,106,77)]
    for y in range(W):
      for x in range(W):
        plank=(y//64)%8
        line=abs(math.sin(x*.062 + y*.013)) * 2.5 +math.sin(x*.016 +y*.21)*2
        color=base[plank]
        if y%64<2 or x%256<2: color=tuple(max(0,c-17) for c in color)
        px[y][x]=grain(tuple(constrain(c+line) for c in color), 2.3)
    return px

def ceramic():
    px=[[None]*W for _ in range(W)]; pal=[(170,171,166),(164,166,164),(175,173,169),(162,166,162)]
    for y in range(W):
      for x in range(W):
        cell=((y//128)*2+(x//128))%4
        grout=x%128<3 or y%128<3
        base=(105,110,108) if grout else pal[cell]
        speck=((x*117+y*313)%997)<9
        px[y][x]=grain(tuple(constrain(v+(7 if speck else 0)) for v in base),2.4)
    return px

def plaster():
    px=[[None]*W for _ in range(W)]
    for y in range(W):
      for x in range(W):
        shade=2*math.sin(x*.026+y*.008)+2*math.sin(y*.034)+math.sin(x*.11+y*.11)
        px[y][x]=grain(tuple(constrain(c+shade) for c in (207,199,186)),2.5)
    return px

def acoustic():
    px=[[None]*W for _ in range(W)]
    for y in range(W):
      for x in range(W):
        gap=x%48 in (0,1,2)
        seam=y%256 in (0,1)
        c=(39,51,52) if gap else ((77,88,84) if seam else (87,98,90))
        px[y][x]=grain(c,2)
    return px

def png_rgb(rows):
    # PNG encoder in stdlib; CI needs no pip/Blender or separate web requests.
    def chunk(tag,data):
        return struct.pack('!I',len(data))+tag+data+struct.pack('!I',zlib.crc32(tag+data)&0xffffffff)
    payload=b''.join(b'\x00'+bytes(c for rgb in row for c in rgb) for row in rows)
    header=struct.pack('!IIBBBBB',W,W,8,2,0,0,0)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',header)+chunk(b'IDAT',zlib.compress(payload,level=8))+chunk(b'IEND',b'')

for name,fn in [('timber_floor',wood),('porcelain_floor',ceramic),('lime_plaster',plaster),('ribbed_panels',acoustic)]:
    out=root/(name+'.png')
    out.write_bytes(png_rgb(fn()))
    print('V12 TEXTURE:',out.name,out.stat().st_size,hashlib.sha256(out.read_bytes()).hexdigest()[:16])