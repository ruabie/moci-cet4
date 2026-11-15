#!/usr/bin/env python3
"""Original CC0-free authored meshes. Build with Python standard library only.
No downloaded, model-extracted, or third-party content is used. The character
contains an actual glTF skin and named joints for Godot 4 Skeleton3D animation.
Reproducible assets, UTC independent, no outbound calls.
"""
import json, math, struct, pathlib
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parents[1]
class Gltf:
 def __init__(self):
  self.bin=bytearray();self.views=[];self.acc=[];self.materials=[];self.prims=defaultdict(lambda: {'p':[], 'n':[], 'idx':[], 'w':[], 'j':[]});self.nodes=[];self.skin=None
 def material(self,name,color,metal=0.0,rough=.84,emissive=None):
  item={'name':name,'pbrMetallicRoughness':{'baseColorFactor':list(color)+[1.0],'metallicFactor':metal,'roughnessFactor':rough},'doubleSided':True}
  if emissive: item['emissiveFactor']=list(emissive)
  self.materials.append(item);return len(self.materials)-1
 def buffer(self, data, fmt, component, kind, item_size, bound=False):
  while len(self.bin)%4:self.bin.append(0)
  start=len(self.bin)
  if data:
   self.bin.extend(struct.pack('<'+fmt*len(data),*data))
  view={'buffer':0,'byteOffset':start,'byteLength':len(self.bin)-start}
  self.views.append(view)
  ac={'bufferView':len(self.views)-1,'componentType':component,'count':len(data)//item_size,'type':kind}
  if bound and data:
   n=len(data)//item_size
   ac['min']=[min(data[k*item_size+i] for k in range(n)) for i in range(item_size)]
   ac['max']=[max(data[k*item_size+i] for k in range(n)) for i in range(item_size)]
  self.acc.append(ac);return len(self.acc)-1
 def add_mesh(self,material,vertices,triangles,bone=None,normals=None):
  p=self.prims[material];offset=len(p['p'])//3
  # glTF positions are world coordinates for mesh under a root identity transform.
  p['p'].extend(v for vertex in vertices for v in vertex)
  p['idx'].extend(offset+i for triangle in triangles for i in triangle)
  if normals is None:
   accumulated=[[0.0]*3 for _ in vertices]
   for i,j,k in triangles:
    a,b,c=vertices[i],vertices[j],vertices[k]
    ux,uy,uz=[b[t]-a[t] for t in range(3)]; vx,vy,vz=[c[t]-a[t] for t in range(3)]
    cross=(uy*vz-uz*vy,uz*vx-ux*vz,ux*vy-uy*vx)
    for q in (i,j,k):
     for t in range(3):accumulated[q][t]+=cross[t]
   normals=[]
   for v in accumulated:
    l=max(1e-7,math.sqrt(sum(t*t for t in v)));normals.append(tuple(t/l for t in v))
  p['n'].extend(a for normal in normals for a in normal)
  if self.skin is not None:
   bind=bone if bone is not None else 0
   for _ in vertices:p['j'].extend((bind,0,0,0));p['w'].extend((1,0,0,0))
 def box(self,mat,center,size,bone=None):
  x,y,z=center;a,b,c=[v*.5 for v in size]
  verts=[(x-a,y-b,z-c),(x+a,y-b,z-c),(x+a,y+b,z-c),(x-a,y+b,z-c),(x-a,y-b,z+c),(x+a,y-b,z+c),(x+a,y+b,z+c),(x-a,y+b,z+c)]
  faces=[(0,2,1),(0,3,2),(4,5,6),(4,6,7),(0,1,5),(0,5,4),(2,3,7),(2,7,6),(1,2,6),(1,6,5),(3,0,4),(3,4,7)]
  self.add_mesh(mat,verts,faces,bone)
 def sphere(self,mat,ctr,radii,bone=None,rings=10,sides=18,phi_start=0.0,phi_end=math.pi):
  vertices=[];faces=[];cx,cy,cz=ctr;rx,ry,rz=radii
  for ring in range(rings+1):
   p=phi_start+(phi_end-phi_start)*ring/rings
   for i in range(sides+1):
    t=2*math.pi*i/sides
    vertices.append((cx+rx*math.sin(p)*math.cos(t),cy+ry*math.cos(p),cz+rz*math.sin(p)*math.sin(t)))
  for r in range(rings):
   for s in range(sides):
    a=r*(sides+1)+s;b=a+sides+1
    faces.extend(((a,b,a+1),(a+1,b,b+1)))
  self.add_mesh(mat,vertices,faces,bone)
 def tapered(self,mat,p0,p1,r0,r1,bone=None,sides=18):
  # Tapered tube between arbitrary axis points, with ring caps.
  a=list(p0);b=list(p1);v=[b[i]-a[i] for i in range(3)];l=math.sqrt(sum(q*q for q in v));v=[q/l for q in v]
  seed=(1,0,0) if abs(v[0])<.8 else (0,0,1)
  x=(v[1]*seed[2]-v[2]*seed[1],v[2]*seed[0]-v[0]*seed[2],v[0]*seed[1]-v[1]*seed[0]);l2=math.sqrt(sum(q*q for q in x));x=[q/l2 for q in x]
  z=(v[1]*x[2]-v[2]*x[1],v[2]*x[0]-v[0]*x[2],v[0]*x[1]-v[1]*x[0])
  verts=[]
  for pos,rad in [(a,r0),(b,r1)]:
   if isinstance(rad,(int,float)):rad=(rad,rad)
   for j in range(sides):
    ang=j*2*math.pi/sides
    verts.append(tuple(pos[i]+x[i]*rad[0]*math.cos(ang)+z[i]*rad[1]*math.sin(ang) for i in range(3)))
  faces=[]
  for j in range(sides):
   k=(j+1)%sides;faces.extend(((j,k,sides+j),(k,sides+k,sides+j)))
  # End caps
  for j in range(1,sides-1):faces.extend(((0,j+1,j),(sides,sides+j,sides+j+1)))
  self.add_mesh(mat,verts,faces,bone)
 def save(self,name):
  if self.skin is None:
   keys=sorted(self.prims.keys());mesh_node=0;nodes=[{'name':'Geometry','mesh':0}];scenes=[{'nodes':[0]}]
  else:
   keys=sorted(self.prims.keys());nodes=self.nodes;scenes=[{'nodes':[0,1]}]
  prims=[]
  for mat in keys:
   p=self.prims[mat];attr={'POSITION':self.buffer(p['p'],'f',5126,'VEC3',3,True),'NORMAL':self.buffer(p['n'],'f',5126,'VEC3',3)}
   if self.skin is not None:
    attr['JOINTS_0']=self.buffer(p['j'],'H',5123,'VEC4',4)
    attr['WEIGHTS_0']=self.buffer(p['w'],'f',5126,'VEC4',4)
   prims.append({'attributes':attr,'indices':self.buffer(p['idx'],'I',5125,'SCALAR',1),'material':mat,'mode':4})
  doc={'asset':{'version':'2.0','generator':'SameTime City custom original procedural glTF 2026'},'scene':0,'scenes':scenes,'nodes':nodes,'meshes':[{'primitives':prims}],'materials':self.materials,'bufferViews':self.views,'accessors':self.acc,'buffers':[{'byteLength':len(self.bin)}]}
  if self.skin is not None:
   matrices=[]
   for pos in self.skin['world']:
    x,y,z=pos
    matrices.extend([1,0,0,0, 0,1,0,0, 0,0,1,0, -x,-y,-z,1])
   access=self.buffer(matrices,'f',5126,'MAT4',16)
   doc['bufferViews']=self.views;doc['accessors']=self.acc;doc['buffers']=[{'byteLength':len(self.bin)}]
   doc['skins']=[{'name':'CommuterRig','joints':self.skin['joints'],'skeleton':1,'inverseBindMatrices':access}]
  body=json.dumps(doc,ensure_ascii=False,separators=(',',':')).encode()
  body+=b' ' *((-len(body))%4);binary=bytes(self.bin)+b'\x00' *((-len(self.bin))%4)
  result=struct.pack('<4sII',b'glTF',2,12+8+len(body)+8+len(binary))
  result+=struct.pack('<I4s',len(body),b'JSON')+body+struct.pack('<I4s',len(binary),b'BIN\0')+binary
  out=ROOT/name;out.parent.mkdir(parents=True,exist_ok=True);out.write_bytes(result)
  print(name, len(result),'bytes',sum(len(self.prims[k]['p'])//3 for k in keys),'vertices')

def person():
 g=Gltf()
 # Each vertex is bound to a named bone. Root rest transforms are identity/translation.
 bone_defs=[
  ('Hips',None,(0,.92,0)), ('Spine','Hips',(0,.19,0)),('Chest','Spine',(0,.27,0)),
  ('Neck','Chest',(0,.21,0)),('Head','Neck',(0,.15,0)),
  ('LeftUpperArm','Chest',(-.30,.03,0)),('LeftForeArm','LeftUpperArm',(-.035,-.31,0)),('LeftHand','LeftForeArm',(0,-.26,0)),
  ('RightUpperArm','Chest',(.30,.03,0)),('RightForeArm','RightUpperArm',(.035,-.31,0)),('RightHand','RightForeArm',(0,-.26,0)),
  ('LeftThigh','Hips',(-.155,-.03,0)),('LeftShin','LeftThigh',(0,-.42,0)),('LeftFoot','LeftShin',(0,-.37,-.055)),
  ('RightThigh','Hips',(.155,-.03,0)),('RightShin','RightThigh',(0,-.42,0)),('RightFoot','RightShin',(0,-.37,-.055)),
 ]
 idx={name:i for i,(name,_,_) in enumerate(bone_defs)}
 world={};children=defaultdict(list)
 for name,parent,pos in bone_defs:
  world[name]=tuple(pos[j]+(world[parent][j] if parent else 0) for j in range(3))
  if parent:children[parent].append(name)
 g.nodes=[{'name':'CommuterMesh','mesh':0,'skin':0}]
 for name,parent,pos in bone_defs:
  node={'name':name,'translation':list(pos)}
  if children[name]:node['children']=[1+idx[x] for x in children[name]]
  g.nodes.append(node)
 g.skin={'joints':[1+i for i in range(len(bone_defs))],'world':[world[name] for name,_,_ in bone_defs]}
 def m(name,c,metal=0,rough=.83):return g.material(name,c,metal,rough)
 coat=m('warm_gray_suede',(0.27,.335,.34),0.02,.89)
 coat_high=m('jacket_lapel',(0.38,.435,.43),0.02,.91)
 coat_dark=m('jacket_stitch',(0.16,.22,.23),0.0,.88)
 trousers=m('indigo_trouser',(.13,.175,.22),0.0,.94)
 denim_light=m('denim_seam',(.22,.29,.34))
 skin=m('warm_skin',(.78,.59,.47),0,.72)
 hair=m('charcoal_hair',(.08,.084,.09),0,.91)
 shoes=m('cream_canvas',(.78,.77,.71),0,.90)
 rubber=m('dark_sole',(.21,.24,.24),0,.95)
 bag=m('canvas_sling',(.23,.26,.28),0,.94)
 metal=m('zips',(.66,.62,.52),.42,.52)
 eye=m('eyes',(.075,.07,.073),0,.72)
 blushing=m('muted_lip',(.57,.37,.34),0,.85)
 # torso segmented for natural volume and readable apparel silhouette
 g.sphere(coat,(0,1.37,0),(.32,.32,.195),idx['Chest'],rings=16,sides=24)
 g.tapered(coat,(0,1.1,0),(0,1.55,0),(.24,.16),(.30,.19),idx['Spine'])
 g.sphere(trousers,(0,.98,.0),(.26,.18,.175),idx['Hips'],rings=12,sides=20)
 g.sphere(coat_high,(-.116,1.52,-.155),(.104,.22,.042),idx['Chest'])
 g.sphere(coat_high,(.116,1.52,-.155),(.104,.22,.042),idx['Chest'])
 g.box(coat_dark,(0,1.31,-.202),(.013,.43,.012),idx['Chest'])
 for x in (-.15,.15):
  g.box(coat_dark,(x,1.18,-.189),(.09,.011,.012),idx['Spine'])
  g.sphere(metal,(x,1.41,-.204),(.012,.012,.012),idx['Chest'],rings=6,sides=10)
 g.sphere(bag,(0,1.38,.218),(.265,.30,.10),idx['Chest'],rings=12,sides=18)
 for x in [-.18,.18]:
  g.tapered(bag,(x,1.56,.12),(x*.73,1.30,.28),.026,.026,idx['Chest'],10)
 # neck, head and unique profile
 g.tapered(skin,(0,1.62,0),(0,1.75,0),(.086,.085),(.08,.075),idx['Neck'])
 g.sphere(skin,(0,1.87,-.025),(.203,.26,.195),idx['Head'],rings=20,sides=24)
 g.sphere(hair,(0,2.025,-.01),(.216,.138,.207),idx['Head'],rings=10,sides=24)
 g.sphere(hair,(0,1.993,-.123),(.20,.080,.10),idx['Head'],rings=8,sides=18)
 g.sphere(skin,(0,1.857,-.21),(.037,.054,.041),idx['Head'],rings=10,sides=12)
 for s in [-1,1]:
  g.sphere(skin,(s*.204,1.85,-.006),(.034,.067,.041),idx['Head'],rings=10,sides=14)
  g.sphere(eye,(s*.073,1.887,-.208),(.016,.012,.010),idx['Head'],rings=8,sides=10)
  g.sphere(hair,(s*.076,1.925,-.204),(.045,.010,.009),idx['Head'],rings=8,sides=10)
 g.sphere(blushing,(0,1.804,-.209),(.035,.009,.007),idx['Head'],rings=6,sides=10)
 # cuffed sleeves / hands: genuine glTF skin instead of separate GDScript pivot meshes
 for name,s in [('Left',-1),('Right',1)]:
  A=idx[name+'UpperArm'];B=idx[name+'ForeArm'];H=idx[name+'Hand'];T=idx[name+'Thigh'];S=idx[name+'Shin'];F=idx[name+'Foot'];x=s*.33
  g.tapered(coat,(x,1.48,0),(x+s*.018,1.17,0),(.116,.117),(.106,.10),A)
  g.sphere(coat_high,(x,1.47,0),(.135,.125,.131),A)
  g.tapered(coat,(x+s*.018,1.16,0),(x+s*.028,.92,-.01),(.098,.091),(.075,.075),B)
  g.tapered(coat_dark,(x+s*.028,.99,-.01),(x+s*.028,.93,-.01),(.084,.078),(.081,.078),B)
  g.sphere(skin,(x+s*.028,.878,-.012),(.077,.12,.064),H,rings=12,sides=16)
  hx=s*.155
  g.tapered(trousers,(hx,.88,0),(hx,.49,0),(.143,.139),(.122,.123),T)
  g.tapered(trousers,(hx,.49,0),(hx,.127,-.008),(.12,.119),(.087,.092),S)
  g.tapered(denim_light,(hx,.18,0),(hx,.12,0),(.089,.090),(.092,.092),S)
  g.sphere(shoes,(hx,.105,-.095),(.128,.098,.24),F,rings=12,sides=20)
  g.box(rubber,(hx,.047,-.113),(.254,.034,.44),F)
  for k in range(3): g.box(metal,(hx,.173-k*.024,-.209),(.11,.007,.013),F)
 # A slim shoulder messenger bag with folded flap is a distinctive readable detail
 g.box(bag,(.21,1.18,.235),(.25,.29,.102),idx['Spine'])
 g.box(coat_dark,(.21,1.27,.299),(.27,.018,.008),idx['Spine'])
 g.save('art/characters/commuter_rig.glb')

def shop():
 g=Gltf();
 facade=g.material('porcelain_facade',(0.67,.69,.66),rough=.85)
 dark=g.material('dark_bronze_frame',(.17,.235,.245),metal=.46,rough=.4)
 glass=g.material('smoked_glass',(.17,.28,.32),metal=.22,rough=.18)
 oak=g.material('warm_wood',(.47,.30,.22),rough=.83)
 bricks=g.material('sandstone_tiles',(.66,.56,.45),rough=.9)
 cream=g.material('enameled_beige',(.88,.83,.72),metal=.12,rough=.41)
 green=g.material('pine_green',(.20,.36,.31),rough=.86)
 night=g.material('light_panel',(.9,.83,.65),rough=.25,emissive=(.17,.11,.04))
 goods=g.material('goods_packages',(.65,.51,.35),rough=.87)
 # Base at x=0, road is +X; shop frontage spans 14.5m Z. 2m projection.
 g.box(facade,(.16,2.6,0),(.24,5.2,14.8))
 g.box(bricks,(.35,.32,0),(.65,.64,14.5))
 g.box(cream,(.30,4.7,0),(.55,.60,14.7))
 for i in range(16):
  z=-7.0+i*.93
  g.box(bricks,(.38,3.0,z),(.12,3.38,.04))
 # recessed mullioned storefront, doors and displays
 for i in range(6):
  z=-5.95 + i*2.38
  g.box(glass,(.74,2.25,z),(.10,3.15,2.18))
  g.box(dark,(.84,2.25,z+1.1),(.14,3.17,.085))
  g.box(dark,(.84,3.81,z),(.14,.072,2.25))
  g.box(dark,(.84,.74,z),(.14,.15,2.25))
  g.box(dark,(.83,2.17,z),(.14,.047,2.2))
 # sliding door in center bay, handles
 for z in [-.45,.45]:
  g.box(dark,(.98,2.2,z),(.12,3.2,.035))
  g.box(cream,(1.09,1.95,z+.15),(.07,.40,.035))
 # illuminated inner shelves and groceries behind shop window
 for side in (-1,1):
  for i in range(3):
   z=side*(2.6+i*1.25)
   g.box(oak,(.50,1.05,z),(.30,.08,.92))
   g.box(oak,(.50,1.70,z),(.30,.08,.92))
   for y in [1.15,1.80]:
    for b in [-.21,.04,.27]:g.box(goods,(.72,y,z+b),(.18,.22,.14))
 # canopy with contrasting ribs and scalloped edge
 g.box(green,(1.30,4.13,0),(2.36,.125,14.62))
 for k in range(19):
  z=-7.0+k*.78
  g.box(cream,(1.36,4.20,z),(2.24,.023,.15))
 g.box(dark,(2.50,3.95,0),(.15,.31,14.8))
 for z in [-6.8,-3.5,0,3.5,6.8]:
  g.box(dark,(1.63,4.03,z),(.05,.23,.06))
 # signboard above canopy, no text: Godot Label3D supplies localized lettering
 g.box(dark,(.7,5.08,0),(.27,.91,13.7))
 g.box(night,(.855,5.08,0),(.042,.69,13.2))
 # HVAC brackets, small fixtures, bollards and low plinth
 for z in [-6.5,6.5]:
  g.box(oak,(1.05,.4,z),(.48,.80,.68))
  g.box(green,(1.05,.94,z),(.70,.52,.75))
 g.save('art/architecture/storefront.glb')

def lobby():
 g=Gltf()
 concrete=g.material('offwhite_plaster',(.69,.66,.58),rough=.89)
 bronze=g.material('anodized_brass',(.40,.34,.27),metal=.59,rough=.40)
 dark=g.material('entry_slate',(.16,.20,.20),metal=.09,rough=.71)
 glass=g.material('blue_gray_glazing',(.24,.34,.36),metal=.16,rough=.18)
 wood=g.material('lobby_oak',(.45,.32,.23),rough=.78)
 white=g.material('soffit_diffuser',(.87,.80,.66),emissive=(.13,.09,.05),rough=.36)
 planter=g.material('planter_ceramic',(.49,.47,.42),rough=.93)
 green=g.material('foliage',(.23,.38,.30),rough=.86)
 # A readable residential lobby rather than copy-pasting a retail store.
 g.box(concrete,(.12,3.3,0),(.24,6.6,12.4))
 for z in [-5.94,5.94]:
  g.box(concrete,(.49,2.90,z),(.88,5.80,.35))
 for z in [-3.7,3.7]:
  g.box(concrete,(.43,2.91,z),(.78,5.82,.23))
 for z in [-2.45,2.45]:
  g.box(glass,(.81,2.54,z),(.12,3.95,2.20))
  for y in [.7,4.65]:g.box(bronze,(.90,y,z),(.15,.09,2.32))
 # A pair of tall wooden entry doors with narrow glass inserts.
 for s in [-1,1]:
  z=s*.71
  g.box(wood,(.96,2.40,z),(.16,3.75,1.31))
  g.box(glass,(1.065,2.67,z),(.05,2.75,.18))
  g.box(bronze,(1.11,2.13,z-s*.43),(.05,.41,.05))
 g.box(dark,(.6,.22,0),(.90,.44,11.6))
 g.box(bronze,(.93,4.93,0),(.17,.18,11.1))
 g.box(concrete,(.96,5.12,0),(.18,.39,11.3))
 g.box(dark,(1.25,5.40,0),(1.95,.12,11.1))
 for z in [-4.5,0,4.5]:g.box(white,(1.5,5.30,z),(.48,.06,.65))
 # Intercom, mailboxes and planter at the front edge.
 g.box(bronze,(.94,1.73,3.20),(.08,.75,.64))
 for y in [1.43,1.73,2.03]:
  for z in [2.98,3.24,3.50]:g.box(dark,(1.01,y,z),(.013,.16,.19))
 for z in [-5.15,5.15]:
  g.box(planter,(1.52,.40,z),(.65,.80,.72))
  g.sphere(green,(1.52,1.16,z),(.53,.70,.53),rings=8,sides=14)
 g.save('art/architecture/apartment_lobby.glb')

if __name__=='__main__':
 person();shop();lobby()