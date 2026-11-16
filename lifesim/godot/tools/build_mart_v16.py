#!/usr/bin/env python3
"""Create original, reproducible fictional convenience store packaging and finishes."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import random, math
R=Path(__file__).resolve().parents[1]/'art'/'interiors_v16'
R.mkdir(parents=True,exist_ok=True)
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
CJK='/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc'
def font(size, cjk=False):
    preferred = CJK if cjk and Path(CJK).is_file() else FONT
    try:
        return ImageFont.truetype(preferred,size)
    except OSError:
        return ImageFont.load_default(size=size)
SKU=[
 ('ocha','AOI','緑茶',(46,99,75),(240,224,177),'TEA'),
 ('coffee','KAWA','珈琲',(73,53,42),(235,200,147),'COFFEE'),
 ('milk','SORA','牛乳',(85,126,158),(238,241,232),'MILK'),
 ('tea','MORI','紅茶',(153,73,69),(239,214,182),'BLACK TEA'),
 ('rice','HOSHI','お米',(112,102,75),(232,225,204),'RICE'),
 ('noodles','HARU','麺',(171,114,59),(239,216,163),'NOODLES'),
 ('juice','HIKARI','果汁',(184,127,70),(255,227,166),'JUICE'),
 ('cookies','KOMOREBI','焼菓子',(122,85,124),(242,216,191),'SNACKS'),
]
for ident,name,kanji,base,accent,detail in SKU:
    img=Image.new('RGB',(256,512),base); d=ImageDraw.Draw(img)
    d.rectangle((8,8,248,504),outline=accent,width=4)
    d.rectangle((15,17,241,104),fill=accent)
    d.text((128,42),name,fill=base,font=font(30),anchor='mm')
    d.text((128,162),kanji if Path(CJK).is_file() else detail,fill=accent,font=font(62 if Path(CJK).is_file() else 40,cjk=True),anchor='mm')
    d.ellipse((68,222,188,342),outline=accent,width=9)
    d.arc((89,243,168,318),-40,220,fill=accent,width=7)
    d.rectangle((10,384,246,497),fill=accent)
    d.text((128,416),detail,fill=base,font=font(24),anchor='mm')
    d.text((128,467),'AOKAWA  •  01',fill=base,font=font(15),anchor='mm')
    img.save(R/f'pack_{ident}.png',optimize=True)
rng=random.Random(1616)
for kind,base,accent in [
 ('floor',(147,152,146),(127,137,132)),
 ('wall',(177,174,165),(154,151,142)),
 ('oak',(149,130,108),(107,96,83)),
]:
    img=Image.new('RGB',(512,512),base); d=ImageDraw.Draw(img)
    if kind=='floor':
        for x in range(0,513,128): d.line((x,0,x,512),fill=(115,124,120),width=3)
        for y in range(0,513,128): d.line((0,y,512,y),fill=(115,124,120),width=3)
        for i in range(250):
            x,y=rng.randrange(512),rng.randrange(512); delta=rng.randrange(-8,8)
            d.point((x,y),fill=tuple(max(0,min(255,k+delta)) for k in base))
    elif kind=='wall':
        for i in range(420):
            x,y=rng.randrange(512),rng.randrange(512)
            d.line((x,y,x+rng.randrange(1,6),y),fill=accent,width=1)
    else:
        for y in range(0,512,7):
            delta=rng.randrange(-12,13)
            c=tuple(max(0,min(255,v+delta)) for v in base)
            d.line((0,y,512,y+rng.randrange(-4,5)),fill=c,width=rng.randrange(1,3))
    img.save(R/f'{kind}.png',optimize=True)
print('V16 ART BUILD PASS:',len(SKU),'fictional packaging textures and 3 surface textures')
