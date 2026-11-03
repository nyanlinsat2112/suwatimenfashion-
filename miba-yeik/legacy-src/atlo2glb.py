import sys,re,json,struct
import numpy as np
src,dst=sys.argv[1],sys.argv[2]
d=open(src,'rb').read();xml=d[d.find(b'<?xml'):].decode('utf8','replace')
def cdata(tag):
    i=xml.find('<'+tag+'><![CDATA[');j=xml.find(']]>',i);return xml[i+len(tag)+11:j].strip().split('\n')
P=cdata('Points');n=int(P[0]);pts=np.array([[float(v) for v in l.split()] for l in P[1:n+1]],dtype=np.float64)
polys={}
for l in cdata('Polygons')[1:]:
    t=l.split();m=int(t[1]);k=int(t[2]);idx=[int(t[i]) for i in range(len(t)) if i>2 and t[i-1]!='M' and t[i-2]!='M' and t[i] not in('I','M') and re.fullmatch(r'\d+',t[i]) and (t[i-3]=='M')]
    if len(idx)!=k: idx=[int(x) for x in re.findall(r'M \S+ \S+ (\d+)',l)]
    for a in range(1,len(idx)-1): polys.setdefault(m,[]).append((idx[0],idx[a],idx[a+1]))
names=[re.search(r'<Name en="([^"]*)"',p).group(1) for p in re.findall(r'<Property\b.*?</Property>',xml,re.S)]
# axes: find long horizontal axis
ext=pts.max(0)-pts.min(0);print('extent',ext)
up=int(np.argmin([abs(ext[i]-min(ext)) if False else 0 for i in range(3)]))
# Artlantis: Z up
L=0 if ext[0]>ext[1] else 1; Wd=1-L
v=np.stack([pts[:,L],pts[:,2],pts[:,Wd]],1)*0.01
# front = side with headlights (Phare*)
hl=[i for i,nm in enumerate(names[:27]) if nm.startswith('Phare') and nm!='Phare_orange']
hv=[v[i] for m in hl for f in polys.get(m,[]) for i in f]
c=(v.max(0)+v.min(0))/2
if hv and np.mean(np.array(hv)[:,0])<c[0]: v[:,0]*=-1; v[:,2]*=-1
c=(v.max(0)+v.min(0))/2; v[:,0]-=c[0]; v[:,2]-=c[2]; v[:,1]-=v[:,1].min()
print('size m',v.max(0)-v.min(0))
def mat(nm):
    M=lambda col,met=0.,rough=.5,**k:dict(name=nm,pbrMetallicRoughness=dict(baseColorFactor=list(col)+[k.pop('a',1.)],metallicFactor=met,roughnessFactor=rough),doubleSided=True,**k)
    if nm=='Body':return M((.93,.93,.91),.25,.22,extensions={'KHR_materials_clearcoat':{'clearcoatFactor':1,'clearcoatRoughnessFactor':.05}})
    if nm in('Chrome','Metal','Feux_chrome','Phare','Phare_2','Miroir','Toyota'):return M((.92,.92,.94),1,.08)
    if nm=='Jante':return M((.75,.76,.78),.9,.28)
    if nm=='Pneu':return M((.04,.04,.045),0,.9)
    if nm in('Frein','Disk'):return M((.35,.35,.35),.7,.4)
    if nm=='Vitre':return M((.03,.045,.06),0,.04,a=.74,alphaMode='BLEND')
    if nm=='Vitre_ar':return M((.02,.03,.04),0,.04,a=.88,alphaMode='BLEND')
    if nm=='Phare_vitre':return M((.9,.93,.97),0,.03,a=.22,alphaMode='BLEND')
    if nm=='Vitre_noir':return M((.02,.02,.025),.2,.15)
    if nm in('Feux_rouge','Feux_stop'):return M((.55,.03,.04),0,.3,emissiveFactor=[.35,0,0])
    if nm=='Feux_blanc':return M((.9,.9,.9),0,.3,emissiveFactor=[.25,.25,.25])
    if nm=='Phare_orange':return M((.9,.45,.05),0,.3,a=.85,alphaMode='BLEND')
    if nm in('Siege','Interieur_beige'):return M((.62,.58,.52),0,.8)
    if nm=='Interieur_sol':return M((.4,.38,.35),0,.9)
    if nm=='Interieur_noir':return M((.12,.12,.12),0,.8)
    return M((.05,.05,.055),0,.7)
bin_=bytearray();views=[];accs=[];prims=[];mats=[]
def add(arr,target,comp,typ,mm=False):
    b=arr.tobytes();off=len(bin_);bin_.extend(b);bin_.extend(b'\0'*((4-len(b)%4)%4))
    views.append(dict(buffer=0,byteOffset=off,byteLength=len(b),target=target))
    a=dict(bufferView=len(views)-1,componentType=comp,count=len(arr),type=typ)
    if mm:a['min']=arr.min(0).tolist();a['max']=arr.max(0).tolist()
    accs.append(a);return len(accs)-1
for m,fs in sorted(polys.items()):
    f=np.array(fs,dtype=np.int64);u,inv=np.unique(f.ravel(),return_inverse=True);pv=v[u].astype(np.float32);fi=inv.reshape(-1,3)
    a,b,c2=pv[fi[:,0]],pv[fi[:,1]],pv[fi[:,2]];fn=np.cross(b-a,c2-a)
    nrm=np.zeros_like(pv);
    for k in range(3):np.add.at(nrm,fi[:,k],fn)
    ln=np.linalg.norm(nrm,axis=1,keepdims=True);ln[ln==0]=1;nrm=(nrm/ln).astype(np.float32)
    pa=add(pv,34962,5126,'VEC3',True);na=add(nrm,34962,5126,'VEC3')
    ia=add(fi.astype(np.uint32).ravel(),34963,5125,'SCALAR')
    mats.append(mat(names[m]));prims.append(dict(attributes=dict(POSITION=pa,NORMAL=na),indices=ia,material=len(mats)-1))
g=dict(asset=dict(version='2.0',generator='miba-atlo2glb'),extensionsUsed=['KHR_materials_clearcoat'],scene=0,scenes=[dict(nodes=[0])],nodes=[dict(name='Alphard',mesh=0)],
 meshes=[dict(name='Alphard',primitives=prims)],materials=mats,accessors=accs,bufferViews=views,buffers=[dict(byteLength=len(bin_))])
js=json.dumps(g,separators=(',',':')).encode();js+=b' '*((4-len(js)%4)%4)
out=struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(bin_))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(bin_),0x004E4942)+bytes(bin_)
open(dst,'wb').write(out);print('glb',len(out),'prims',len(prims),'tris',sum(len(x) for x in polys.values()))
