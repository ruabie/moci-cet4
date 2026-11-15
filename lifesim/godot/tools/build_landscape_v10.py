#!/usr/bin/env python3
"""V0.10 original street vegetation assets.

No downloaded or extracted models. Regenerate deterministic glTF 2.0 meshes using
only Python standard-library code and the in-repository glTF mesh builder.
Tree forms use tapered branching and many individually shaped, double-sided
leaf blades. Leaf clusters are deliberately irregular, not sphere/box foliage.
"""
from __future__ import annotations
import math
import random
from pathlib import Path
from build_assets import Gltf

ROOT = Path(__file__).resolve().parents[1]


def unit(v):
    norm = math.sqrt(sum(t*t for t in v))
    return tuple(t/max(norm, 1e-8) for t in v)

def add(a,b):return tuple(a[i]+b[i] for i in range(3))
def mul(a,c):return tuple(x*c for x in a)

def leaf(g, material, p, width, length, yaw, pitch, faces):
    """Leaf silhouette with concave stem and pointed tip; bends across midrib."""
    right = (math.cos(yaw), 0.0, math.sin(yaw))
    axis = (math.sin(yaw)*math.sin(pitch), math.cos(pitch), -math.cos(yaw)*math.sin(pitch))
    n = unit((right[2]*axis[1]-right[1]*axis[2], right[0]*axis[2]-right[2]*axis[0], right[1]*axis[0]-right[0]*axis[1]))
    # Slightly warped leaf blade; width peaks at 0.48, narrowed at base and tip.
    coords = [(-0.02, 0.01), (-0.32, 0.28), (-0.53, 0.53), (-0.30, 0.83),
              (0.0, 1.06), (0.32, 0.83), (0.53, 0.53), (0.30, 0.28)]
    verts=[]
    for u,v in coords:
        bend=math.sin(v*math.pi)*0.045*length
        verts.append(tuple(p[i]+right[i]*u*width+axis[i]*v*length+n[i]*bend for i in range(3)))
    start=len(faces['vertices'])
    faces['vertices'].extend(verts)
    # A two-sided material supplies both faces, no duplicate mesh required.
    for i in range(1,7):faces['triangles'].append((start,start+i,start+i+1))


def tree(seed, name, height, spread, autumn=False):
    rng=random.Random(seed)
    g=Gltf()
    bark=g.material('aged_bark',(.26,.235,.195),rough=.99)
    bark_light=g.material('sunlit_bark',(.32,.30,.24),rough=.99)
    twig=g.material('fine_twigs',(.29,.275,.22),rough=.98)
    palette=([(0.24,.34,.20),(.36,.44,.22),(.27,.39,.23),(.42,.47,.25),(.19,.31,.18),(.40,.36,.21)]
        if not autumn else
        [(.44,.37,.15),(.59,.43,.16),(.31,.37,.19),(.64,.51,.21),(.34,.31,.15),(.53,.39,.19)])
    leaf_mat=[g.material('canopy_leaf_%02d'%i,c,rough=.92) for i,c in enumerate(palette)]
    faces=[{'vertices':[],'triangles':[]} for _ in palette]
    base=(0,0,0)
    # Root flare is sculptural rather than a straight rectangular trunk.
    for k in range(7):
        angle=k*math.tau/7.0
        q=(math.sin(angle)*.31,.0,math.cos(angle)*.31)
        g.tapered(bark_light,q,(0,.70,0),.11,.065,sides=6)
    top=(.10, height*.58, -.08)
    g.tapered(bark,base,top,.30,.14,sides=11)
    g.tapered(bark_light,top,(.22,height*.72,.02),.14,.078,sides=9)
    tips=[]
    # Twisting unequal primary limbs; the azimuth is deliberately non-periodic.
    for k in range(15):
        angle=(k*2.399963 + rng.uniform(-.23,.23)) % math.tau
        branch_y=height*(.37+.27*(k%5)/5.0)
        start=(.07,branch_y,0)
        reach=spread*(.44+.32*rng.random())
        high=height*(.72+.20*rng.random())
        mid=(math.cos(angle)*reach*.48, (branch_y+high)*.51,math.sin(angle)*reach*.48)
        end=(math.cos(angle)*reach,high,math.sin(angle)*reach)
        r0=.085+.055*rng.random()
        g.tapered(bark,start,mid,r0,.045,sides=7)
        g.tapered(twig,mid,end,.047,.011,sides=6)
        tips.append(end)
        for q in range(3):
            t=.35+.17*q
            source=tuple(mid[i]+(end[i]-mid[i])*t for i in range(3))
            sa=angle+rng.uniform(-1.0,1.0)
            reach2=spread*(.23+.17*rng.random())
            sub=(source[0]+math.cos(sa)*reach2,source[1]+height*(.09+.09*rng.random()),source[2]+math.sin(sa)*reach2)
            g.tapered(twig,source,sub,.021,.006,sides=5)
            tips.append(sub)
    # Distribute leaf clusters along branch tips, with irregular canopy envelope.
    clusters=[]
    for tip in tips:
        count=10+int(rng.random()*12)
        for _ in range(count):
            p=(tip[0]+rng.gauss(0,.27),tip[1]+rng.gauss(0,.31),tip[2]+rng.gauss(0,.27))
            if .8 < p[1] < height*1.10:
                clusters.append(p)
    for _ in range(470):
        a=rng.uniform(0,math.tau)
        radial=math.sqrt(rng.random())
        x=math.cos(a)*spread*radial
        z=math.sin(a)*spread*.82*radial
        y=height*(.66+.19*rng.random())+height*.12*(1.0-radial)
        clusters.append((x+rng.gauss(0,.11),y,z+rng.gauss(0,.11)))
    for p in clusters:
        pick=rng.randrange(len(palette))
        width=.13+rng.random()*.12
        length=.19+rng.random()*.20
        # Tilt leaves in multiple directions for silhouette depth at street level.
        leaf(g,leaf_mat[pick],p,width,length,rng.random()*math.tau,rng.uniform(.23,2.5),faces[pick])
    for j,f in enumerate(faces):
        if f['triangles']:
            g.add_mesh(leaf_mat[j],f['vertices'],f['triangles'])
    out='art/vegetation/'+name+'.glb'
    g.save(out)
    print('V10 TREE:',name,'leaf_blades',len(clusters),'height',height,'spread',spread)


def shrub():
    rng=random.Random(129071)
    g=Gltf()
    brown=g.material('thin_woody_stems',(.27,.31,.22),rough=.97)
    palette=[(.19,.35,.23),(.26,.43,.26),(.38,.50,.31),(.22,.39,.24)]
    leaf_mats=[g.material('small_shrub_leaves_%d'%i,c,rough=.92) for i,c in enumerate(palette)]
    faces=[{'vertices':[],'triangles':[]} for _ in palette]
    for k in range(44):
        a=rng.uniform(0,math.tau)
        r=.12+.20*rng.random()
        y=.6+.48*rng.random()
        tip=(math.cos(a)*(.32+.27*rng.random()),y,math.sin(a)*(.32+.27*rng.random()))
        g.tapered(brown,(math.cos(a)*r,0,math.sin(a)*r),tip,.013,.003,sides=5)
        for j in range(8):
            p=(tip[0]+rng.gauss(0,.17),tip[1]+rng.gauss(0,.14),tip[2]+rng.gauss(0,.17))
            choice=rng.randrange(len(palette))
            leaf(g,leaf_mats[choice],p,.10+rng.random()*.09,.16+rng.random()*.13,
                 rng.random()*math.tau,rng.uniform(.28,2.3),faces[choice])
    for j, f in enumerate(faces):
        g.add_mesh(leaf_mats[j],f['vertices'],f['triangles'])
    g.save('art/vegetation/street_shrub.glb')


def main():
    tree(48012,'zelkova_full',6.7,2.55)
    tree(76224,'katsura_warm',5.5,2.20,autumn=True)
    tree(99133,'zelkova_narrow',6.2,1.83)
    shrub()

if __name__=='__main__':main()