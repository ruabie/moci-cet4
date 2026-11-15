#!/usr/bin/env python3
"""V0.8 authored cohesive streetscape -- self-contained glTF 2.0 PBR textures.

The original four continuous wall envelopes and real openings are preserved.
The improvements are physically recessed retail interiors, color/roughness varied
masonry/wood/metal tileable textures, coherent thresholds, and proper faceted normals.
No downloaded texture/model or proprietary content; stdlib-only deterministic build.
"""
import json
import math
import pathlib
import random
import struct
import zlib
from collections import defaultdict
from build_assets import Gltf, ROOT
import build_street_v07 as previous


def _png(w, h, kind):
    """Generate a tileable, original texture, deliberately restrained not noisy."""
    seed = {'masonry': 271, 'timber': 391, 'metal': 493,
            'floor': 581, 'stone': 613}.get(kind, 701)
    rng = random.Random(seed)
    pixels = bytearray()
    # Base colors are mostly neutral; baseColorFactor supplies building identity.
    for y in range(h):
        pixels.append(0)
        for x in range(w):
            noise = rng.randint(-7, 7)
            if kind == 'masonry':
                # Staggered 28px mortar courses; joints only ~1.5px wide.
                course = (y // 28)
                mortar = (y % 28 in (0, 1)) or ((x + (course % 2) * 49) % 98 in (0, 1))
                base = (181, 172, 157) if not mortar else (130, 127, 118)
                vignette = ((x // 98 + course * 5) % 8 - 3) * 2
                rgb = [c + noise + vignette for c in base]
            elif kind == 'timber':
                # Grain runs horizontally (along z); non-periodic narrow streaks.
                grain = math.sin(y * .12 + math.sin(x * .033)) * 7 + math.sin(y * .47) * 2
                rgb = [151 + grain + noise//3, 118 + grain*.76 + noise//3, 86 + grain*.58 + noise//3]
            elif kind == 'metal':
                streak = math.sin(x*.40)*2 + math.sin(x*.046)*5
                rgb = [111+streak+noise//3,118+streak+noise//3,117+streak+noise//3]
            elif kind == 'floor':
                grout = y % 48 in (0,1) or (x + (y//48%2)*32)%64 in (0,1)
                base=(138, 113, 91) if not grout else (81, 75, 66)
                rgb = [c+noise for c in base]
            else:  # stone
                seam = x % 64 in (0,1) or y % 64 in (0,1)
                base=(163,157,145) if not seam else (105,110,104)
                rgb = [c+noise for c in base]
            pixels.extend(max(0,min(255,int(c))) for c in rgb)
            pixels.append(255)
    def chunk(tag,data):
        return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
    return b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,6,0,0,0))+chunk(b'IDAT',zlib.compress(bytes(pixels),6))+chunk(b'IEND',b'')


class AuthoredPBR(Gltf):
    def __init__(self):
        super().__init__()
        self.texcoords = defaultdict(list)
        self.texture_bytes = {k:_png(256,256,k) for k in ('masonry','timber','metal','floor','stone')}
        self.mat_to_texture = {}
        self.variant = 'mart'
        self.building_depth = 20.0
        self.building_halfwidth = 8.5

    def material(self,name,color,metal=0.0,rough=.84,emissive=None):
        idx = super().material(name,color,metal,rough,emissive)
        key = None
        if 'continuous_masonry' in name or 'stone_reveal' in name: key='masonry'
        elif 'warm_wood' in name or 'interior_oak' in name: key='timber'
        elif 'metal_fascia' in name or 'anodized' in name or 'roof_zinc' in name or 'integrated_fascia' in name or 'window_joinery' in name or 'zinc_roof' in name: key='metal'
        elif 'floor' in name: key='floor'
        elif 'paver' in name: key='stone'
        if key is not None:
            self.mat_to_texture[idx]=key
            # Retain the per-building identity while using original surface textures.
            # The underlying source texture averages 0.45-0.72 linear channel values.
            reference={'masonry':.69,'timber':.56,'metal':.46,'floor':.54,'stone':.62}[key]
            self.materials[idx]['pbrMetallicRoughness']['baseColorFactor']=[
                min(1.0, float(c) / reference) for c in color]+[1.0]
        if 'interior_window' in name or 'recessed_glazing' in name:
            self.materials[idx]['alphaMode']='BLEND'
            self.materials[idx]['pbrMetallicRoughness']['baseColorFactor']=[.57,.70,.72,.27]
            self.materials[idx]['doubleSided']=True
            self.materials[idx]['pbrMetallicRoughness']['metallicFactor']=.03
            self.materials[idx]['pbrMetallicRoughness']['roughnessFactor']=.15
        return idx

    def add_mesh(self, material, vertices, triangles, bone=None, normals=None):
        # Every source call uses one coplanar face or a single original component.
        # Projected UVs are continuous in world coordinates; no per-panel UV seam.
        a,b,c=(vertices[i] for i in triangles[0])
        u=[b[i]-a[i] for i in range(3)]
        v=[c[i]-a[i] for i in range(3)]
        n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]]
        axis=max(range(3),key=lambda i:abs(n[i]))
        if axis==0: uv=[(q[2]/3,q[1]/3) for q in vertices]
        elif axis==1: uv=[(q[0]/3,q[2]/3) for q in vertices]
        else: uv=[(q[0]/3,q[1]/3) for q in vertices]
        self.texcoords[material].extend(c for pair in uv for c in pair)
        super().add_mesh(material,vertices,triangles,bone,normals)

    def box(self,mat,center,size,bone=None):
        # Six separate face quads give correct planar normals and continuous UVs.
        x,y,z=center; a,b,c=(q*.5 for q in size)
        p=[(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),
           (x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)]
        for idx in ((0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(0,1,5,4),(3,7,6,2)):
            pts=[p[i] for i in idx]
            self.add_mesh(mat,pts,[(0,1,2),(0,2,3)],bone)

    def beveled_box(self,mat,center,size,r=.045):
        """True chamfered box: face insets, 12 joined bevel strips, 8 corner facets."""
        x,y,z=center; a,b,c=(q*.5 for q in size)
        r=min(r,a*.34,b*.34,c*.34)
        outer=(a,b,c)
        inner=(a-r,b-r,c-r)
        for ax in range(3):
            for sign in (-1,1):
                coords=[]
                others=[i for i in range(3) if i!=ax]
                for s0,s1 in [(-1,-1),(1,-1),(1,1),(-1,1)]:
                    pp=[0.,0.,0.]
                    pp[ax]=sign*outer[ax]
                    pp[others[0]]=s0*inner[others[0]]
                    pp[others[1]]=s1*inner[others[1]]
                    coords.append(tuple(pp[i]+(x,y,z)[i] for i in range(3)))
                self.add_mesh(mat,coords,[(0,1,2),(0,2,3)])
        for ax in range(3):
            others=[i for i in range(3) if i!=ax]
            for s0 in (-1,1):
                for s1 in (-1,1):
                    p=[]
                    for t0,t1 in ((outer[others[0]],inner[others[1]]),(inner[others[0]],outer[others[1]])):
                        for endpoint in (-inner[ax],inner[ax]):
                            q=[0.,0.,0.];q[ax]=endpoint;q[others[0]]=s0*t0;q[others[1]]=s1*t1
                            p.append(tuple(q[i]+(x,y,z)[i] for i in range(3)))
                    self.add_mesh(mat,[p[0],p[1],p[3],p[2]],[(0,1,2),(0,2,3)])
        for sx in (-1,1):
            for sy in (-1,1):
                for sz in (-1,1):
                    q=[(sx*a,sy*(b-r),sz*(c-r)),(sx*(a-r),sy*b,sz*(c-r)),(sx*(a-r),sy*(b-r),sz*c)]
                    self.add_mesh(mat,[tuple(p[i]+(x,y,z)[i] for i in range(3)) for p in q],[(0,1,2)])

    def _interior(self):
        """Behind the actual windows: visible room volume, with no fake painted backdrop."""
        g=self; half=self.building_halfwidth;kind=self.variant
        timber=g.material(kind+'_room_floor',(1,1,1),rough=.8)
        self.mat_to_texture[timber]='floor'
        plaster=g.material(kind+'_room_plaster',(.65,.61,.55),rough=.96)
        stone=g.material(kind+'_ceramic_sill',(1,1,1),rough=.72)
        self.mat_to_texture[stone]='stone'
        copper=g.material(kind+'_copper_edge',(.56,.41,.28),metal=.75,rough=.36)
        textile=g.material(kind+'_upholstered_seats',(.24,.35,.31),rough=.91)
        charcoal=g.material(kind+'_coffee_machine',(.16,.17,.17),metal=.35,rough=.48)
        brass=g.material(kind+'_warm_pendant',(.72,.56,.34),metal=.64,rough=.40)
        lit=g.material(kind+'_interior_warm_light',(.94,.76,.49),rough=.48,emissive=(.75,.55,.26))
        chalk=g.material(kind+'_chalkboard',(.16,.20,.18),rough=.92)
        # Actual interior beyond glass, accessible visually from the street.
        g.box(timber,(-4.4,.14,0),(8.8,.25,2*half-1.1))
        g.box(plaster,(-7.7,1.93,0),(.30,3.76,2*half-.9))
        for zz in (-half+.58,half-.58):
            g.box(plaster,(-4.05,1.93,zz),(7.4,3.76,.24))
        g.box(plaster,(-3.7,3.81,0),(7.8,.17,2*half-.80))
        # Side display windows reveal seating. Counter and shelving use cafe wood, not random props.
        if kind in ('coffee','mart'):
            g.beveled_box(timber,(-4.20,1.03,-half+3.30),(1.14,1.08,6.2),.09)
            g.beveled_box(stone,(-4.12,1.62,-half+3.30),(1.37,.15,6.45),.06)
            for zpos in (-half+1.2,-half+3.05,-half+4.9):
                g.tapered(copper,(-3.07,.13,zpos),(-3.07,1.06,zpos),.040,.040,sides=9)
                g.beveled_box(textile,(-3.03,1.07,zpos),(.48,.13,.48),.055)
            g.beveled_box(charcoal,(-4.01,1.91,-half+1.60),(.58,.50,.55),.07)
            for row in (1.28,2.00,2.75):
                g.box(timber,(-7.34,row,-half+3.7),(.24,.08,5.2))
                for zi in range(5):
                    g.beveled_box(stone,(-7.18,row+.17,-half+1.58+zi*1.02),(.27,.30,.19),.035)
            for zi in (-4.55,0,4.45):
                g.tapered(copper,(-2.30,3.65,zi),(-2.30,3.00,zi),.027,.027,sides=10)
                g.sphere(brass,(-2.30,2.94,zi),(.32,.15,.32),rings=8,sides=12)
                g.sphere(lit,(-2.30,2.83,zi),(.16,.045,.16),rings=6,sides=12)
            g.beveled_box(chalk,(-7.46,2.39,half-3.2),(.08,1.18,2.55),.04)
        else:
            g.beveled_box(timber,(-4.72,1.10,-half+3.5),(1.30,1.4,4.2),.10)
            for zz in (-half+2.6,0,half-2.4):
                g.beveled_box(timber,(-3.20,.45,zz),(1.08,.52,1.32),.08)
                g.beveled_box(textile,(-3.20,.76,zz),(1.03,.17,1.22),.06)
            for zz in (-half+2.2,half-2.0):
                g.box(timber,(-7.31,1.65,zz),(.27,2.7,2.3))
        # Architectural tie-ins: door threshold, canopy fasteners and matching fixtures.
        for zz in (-half+1.4,half-1.4):
            g.beveled_box(stone,(.75,.14,zz),(1.30,.18,.80),.05)
            g.beveled_box(copper,(.56,3.55,zz),(.06,.44,.10),.026)
        for zz in (-half+3.25,0,half-3.25):
            g.beveled_box(copper,(.43,4.38,zz),(.15,.12,.12),.026)
        # Roof cap has a chamfered parapet rather than a sharp stacked cuboid.
        g.beveled_box(stone,(-self.building_depth*.5,self._height+.52,0),
                      (self.building_depth+.82,.18,2*half+.66),.075)

    def save(self,name):
        name=name.replace('v07_','v08_')
        kind=next((x for x in ('mart','coffee','apartment','living') if ('_'+x+'_') in name),None)
        self.variant=kind or 'mart'
        profile=previous.SPECS[self.variant]
        self.building_depth=profile[0]
        self.building_halfwidth=profile[2]/2
        self._height=profile[1]
        self._interior()
        primitives=[]
        for mat in sorted(self.prims):
            p=self.prims[mat]
            attr={
              'POSITION':self.buffer(p['p'],'f',5126,'VEC3',3,True),
              'NORMAL':self.buffer(p['n'],'f',5126,'VEC3',3),
              'TEXCOORD_0':self.buffer(self.texcoords[mat],'f',5126,'VEC2',2),
            }
            assert len(p['p'])//3==len(self.texcoords[mat])//2
            primitives.append({'attributes':attr,'indices':self.buffer(p['idx'],'I',5125,'SCALAR',1),'material':mat,'mode':4})
        # The PNG texture bytes live inside the single GLB, rather than next to it.
        images=[];textures=[];texmap={}
        for name_tex,data in self.texture_bytes.items():
            while len(self.bin)%4: self.bin.append(0)
            off=len(self.bin);self.bin.extend(data)
            self.views.append({'buffer':0,'byteOffset':off,'byteLength':len(data)})
            images.append({'name':name_tex+'_original_tile','mimeType':'image/png','bufferView':len(self.views)-1})
            textures.append({'source':len(images)-1,'sampler':0})
            texmap[name_tex]=len(textures)-1
        for material in self.materials:
            if 'recessed_glazing' in material['name']:
                material['alphaMode']='BLEND'
                material['pbrMetallicRoughness']['baseColorFactor'][3]=.28
        for idx,tex in self.mat_to_texture.items():
            self.materials[idx]['pbrMetallicRoughness']['baseColorTexture']={'index':texmap[tex]}
        doc={'asset':{'version':'2.0','generator':'SameTime City V0.8 authored integrated PBR'},
             'scene':0,'scenes':[{'nodes':[0]}],
             'nodes':[{'name':'ContinuousEnvelopeAndInterior','mesh':0}],
             'meshes':[{'primitives':primitives}],
             'materials':self.materials,'textures':textures,'images':images,
             'samplers':[{'magFilter':9729,'minFilter':9987,'wrapS':10497,'wrapT':10497}],
             'bufferViews':self.views,'accessors':self.acc,'buffers':[{'byteLength':len(self.bin)}]}
        content=json.dumps(doc,ensure_ascii=False,separators=(',',':')).encode('utf8')
        content+=b' ' * (-len(content)%4)
        binary=bytes(self.bin)+b'\x00'*(-len(self.bin)%4)
        out=struct.pack('<4sII',b'glTF',2,12+8+len(content)+8+len(binary))
        out+=struct.pack('<I4s',len(content),b'JSON')+content+struct.pack('<I4s',len(binary),b'BIN\0')+binary
        path=ROOT/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(out)
        print('V08',self.variant, 'faces',sum(len(p['idx'])//3 for p in self.prims.values()),
              'embedded PBR images',len(images),'size',len(out))


if __name__=='__main__':
    # All four variants remain separately authored with their own dimensions and openings.
    previous.Gltf=AuthoredPBR
    for kind, spec in previous.SPECS.items():
        previous.one(kind,spec)