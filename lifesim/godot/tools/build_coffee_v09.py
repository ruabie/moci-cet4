#!/usr/bin/env python3
"""V0.9 single-asset café study. Original textures/geometry, Godot GLB, no runtime network.
Works with the existing V0.8 authored GLB pipeline; intentionally upgrades only the café.
"""
import json, math, pathlib, struct, zlib, sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parent))
import build_street_v07 as shell
from build_street_v08 import AuthoredPBR
from build_assets import ROOT

_original_holes=shell.holes_for
def holes(kind,h,d):
    if kind!='coffee': return _original_holes(kind,h,d)
    return [
      (.36,3.61,-7.24,-3.14),(.36,3.61,-2.28,2.15),(.10,3.57,3.04,7.12),
      (5.23,7.22,-6.85,-3.30),(5.23,7.46,-2.25,.90),(5.38,7.18,2.04,6.86),
      (8.42,10.16,-6.75,-4.10),(8.42,10.16,-2.78,.28),(8.42,10.16,2.,6.70)]

def png(w,h,normal=False):
    raw=bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            if normal:
                dx=math.sin(x*.57+y*.21)*5+math.cos(y*.71-x*.43)*4
                dy=math.sin(y*.53-x*.19)*5+math.cos(x*.66+y*.27)*4
                nx,ny=dx/255.,dy/255.
                rgb=(int(128+nx*127),int(128+ny*127),int(255*math.sqrt(max(0,1-nx*nx-ny*ny))))
            else:
                grain=((x*9719+y*7919+x*y*37)^(x*17+y*71))&15
                broad=8*math.sin(x*.019+y*.007)+4*math.cos(y*.038-x*.012)
                rain=-11*max(0,math.sin(x*.024))**16*(.2+.8*y/h)
                rgb=tuple(max(0,min(255,int(k+broad+(grain-7)*.42+rain))) for k in (182,180,172))
            raw.extend((*rgb,255))
    def ch(tag,data):
        return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+ch(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+ch(b'IDAT',zlib.compress(bytes(raw),6))+ch(b'IEND',b'')

class CuratedCafe(AuthoredPBR):
    def __init__(self):
        super().__init__()
        self.texture_bytes['masonry']=png(512,512)
        self.texture_bytes['masonry_normal']=png(256,256,True)

    def _interior(self):
        super()._interior()
        if self.variant!='coffee': return
        g=self
        oak=g.material('v09_satin_timber_louvers',(.62,.41,.25),rough=.73)
        iron=g.material('v09_matte_anodized_black',(.16,.19,.19),metal=.60,rough=.47)
        brass=g.material('v09_brushed_brass',(.59,.45,.28),metal=.70,rough=.44)
        stone=g.material('v09_stucco_cream',(.86,.82,.74),rough=.97)
        cloth=g.material('v09_woven_awnings',(.68,.62,.51),rough=.97)
        cushion=g.material('v09_olive_cushions',(.31,.38,.29),rough=.90)
        ceramic=g.material('v09_handmade_ceramic',(.87,.81,.67),rough=.72)
        espresso=g.material('v09_espresso_machine',(.18,.19,.18),metal=.52,rough=.35)
        glass=g.material('v09_pastry_display_glass',(.65,.73,.71),metal=.04,rough=.16)
        g.materials[glass]['alphaMode']='BLEND'
        g.materials[glass]['pbrMetallicRoughness']['baseColorFactor'][3]=.22
        red=g.material('v09_wine_red_sign',(.34,.17,.15),rough=.74)
        warm=g.material('v09_lamp_cream',(.90,.72,.46),rough=.57,emissive=(.4,.25,.11))
        foliage=g.material('v09_leaves_olive',(.25,.41,.27),rough=.91)
        clay=g.material('v09_clay_planters',(.41,.34,.26),rough=.92)
        # The upper timber screen is restricted to one window bay: intentionally asymmetric.
        for i in range(18):
            g.beveled_box(oak,(.34,8.40,-6.88+i*.205),(.15,6.12,.085),.018)
        for y in [5.29,8.26,11.23]:
            g.beveled_box(iron,(.34,y,-5.07),(.12,.11,3.95),.021)
        # One real balcony at second-floor threshold, tied to the main envelope.
        g.beveled_box(stone,(.78,7.49,4.52),(1.55,.20,6.55),.065)
        for i in range(13):
            z=1.55+i*.49
            g.tapered(iron,(1.43,7.58,z),(1.43,8.46,z),.024,.024,sides=8)
        g.beveled_box(iron,(1.43,8.47,4.51),(.067,.068,6.56),.027)
        # Low-pitch standing seam cap, coherent silhouette instead of stacked cube roof.
        for zz in [-7.85+i*.97 for i in range(17)]:
            g.tapered(iron,(-19.4,13.68,zz),(.48,13.78,zz),.015,.015,sides=6)
        g.add_mesh(iron,[(-19.5,13.51,-8.15),(-19.5,14.16,-8.15),
                         (.55,13.88,-8.15),(.55,13.51,-8.15)],[(0,1,2),(0,2,3)])
        # Single joined storefront awning, not repeated copies of boxed-out signs.
        g.beveled_box(iron,(1.10,3.83,-4.10),(2.11,.12,7.65),.037)
        g.beveled_box(cloth,(1.18,3.95,-4.10),(2.11,.064,7.61),.020)
        for zz in (-7.62,-.56):
            g.tapered(iron,(.23,3.71,zz),(2.09,3.78,zz),.026,.026,sides=8)
        for zz in (-7.3,-3.85,-.65):
            g.sphere(warm,(1.64,3.65,zz),(.14,.09,.14),rings=8,sides=12)
        # Custom display & pastry showcase behind glass, with real depth and tableware.
        g.beveled_box(oak,(-2.1,.91,-1.1),(1.1,1.27,3.5),.08)
        g.beveled_box(ceramic,(-1.99,1.58,-1.1),(1.36,.13,3.76),.055)
        g.beveled_box(glass,(-1.83,1.97,-1.1),(.64,.63,3.30),.035)
        for z in [-2.23,-1.57,-.86,-.24]:
            g.sphere(ceramic,(-1.74,1.78,z),(.24,.09,.16),rings=7,sides=12)
        g.beveled_box(espresso,(-2.56,1.84,-.48),(.72,.57,.64),.085)
        g.beveled_box(brass,(-2.20,2.11,-.48),(.20,.26,.43),.035)
        for z in [-1.28,-1.04,-.80]:
            g.tapered(ceramic,(-2.15,1.72,z),(-2.15,1.94,z),.075,.082,sides=12)
        # Circular tabletops and joinery: no randomly stamped cubic chairs.
        for z,x in [(4.18,-1.48),(6.15,-2.34)]:
            g.tapered(brass,(x,.17,z),(x,.78,z),.049,.046,sides=16)
            g.tapered(oak,(x,.81,z),(x,.84,z),.48,.48,sides=28)
            for sign in (-1.,1.):
                zz=z+sign*.93
                g.tapered(brass,(x,.17,zz),(x,.52,zz),.037,.037,sides=10)
                g.tapered(cushion,(x,.54,zz),(x,.61,zz),.32,.32,sides=18)
                g.beveled_box(oak,(x-.19,1.01,zz+sign*.25),(.09,.81,.42),.039)
        g.beveled_box(red,(.46,4.38,4.31),(.12,.54,3.73),.038)
        g.beveled_box(brass,(.55,4.38,4.31),(.07,.41,3.43),.025)
        for z,x in [(7.32,.90),(-7.43,.86)]:
            g.beveled_box(clay,(x,.44,z),(.76,.69,.65),.065)
            for i in range(4):
                g.sphere(foliage,(x+math.sin(i*2.6)*.24,1.07+i*.12,z+math.cos(i*2.2)*.22),
                         (.30,.38,.29),rings=8,sides=13)

    def save(self,path):
        # Preserve all V0.8 models for screenshot A/B and regression tests.
        original=ROOT/path.replace('v07_','v08_')
        old=original.read_bytes() if original.exists() else None
        super().save(path)
        assert self.variant=='coffee'
        dest=ROOT/path.replace('v07_','v09_')
        data=original.read_bytes()
        size=struct.unpack_from('<I',data,12)[0]
        obj=json.loads(data[20:20+size]);start=20+size
        blen=struct.unpack_from('<I',data,start)[0]
        binary=data[start+8:start+8+blen]
        normal=next(i for i,a in enumerate(obj['images']) if a['name']=='masonry_normal_original_tile')
        assert obj['textures'][normal]['source']==normal
        for material in obj['materials']:
            if material['name'] in ('continuous_masonry','stone_reveal'):
                material['normalTexture']={'index':normal,'scale':.48}
                material['pbrMetallicRoughness']['roughnessFactor']=.96
        obj['asset']['generator']='Same Time City V0.9 original curated cafe / alpha'
        out=json.dumps(obj,ensure_ascii=False,separators=(',',':')).encode()
        out+=b' '*(-len(out)%4)
        dest.write_bytes(struct.pack('<4sII',b'glTF',2,12+8+len(out)+8+len(binary))+
                         struct.pack('<I4s',len(out),b'JSON')+out+
                         struct.pack('<I4s',len(binary),b'BIN\x00')+binary)
        if old is None: original.unlink()
        else: original.write_bytes(old)
        tris=sum(len(p['idx'])//3 for p in self.prims.values())
        print('V09 HERO ASSET',dest.name,tris,'triangles',dest.stat().st_size,'bytes')

if __name__=='__main__':
    shell.Gltf=CuratedCafe
    shell.holes_for=holes
    shell.one('coffee',shell.SPECS['coffee'])
