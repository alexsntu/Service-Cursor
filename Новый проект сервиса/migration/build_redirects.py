import re,sys
from collections import Counter,defaultdict
P='/Users/a0000/Документы/Cursor/Service-Cursor/Новый проект сервиса/migration/'
cats={};prods={};pages={};have=set()
for l in open('objects.tsv',encoding='utf-8'):
    f=l.rstrip('\n').split('\t')
    if f[0]=='C': cats[int(f[1])]=dict(parent=int(f[2]),path=f[3],slug=f[4],name=f[5])
    elif f[0]=='P': prods[int(f[1])]=dict(parent=int(f[2]),path=f[3],slug=f[4],name=f[5],cat=int(f[6]))
    elif f[0]=='A': pages[int(f[1])]=dict(parent=int(f[2]),path=f[3],slug=f[4],name=f[5])
    elif f[0]=='R': have.add(f[1])
def caturl(cid): return '/'+'/'.join(cats[int(i)]['slug'] for i in cats[cid]['path'].split('/'))+'/'
url2obj={}
for cid in cats: url2obj[caturl(cid)]=('c',cid)
for aid,a in pages.items(): url2obj['/'+'/'.join(pages[int(i)]['slug'] for i in a['path'].split('/'))+'/']=('a',aid)
bycat=defaultdict(list)
for pid,p in prods.items(): bycat[p['cat']].append(pid)
ALIAS={'/catalog/remont-iphone/iphone-7/remont-iphone-7/':84,'/catalog/remont-iphone/16-/remont-iphone-167793/':51,'/catalog/remont-iphone/16-/remont-iphone-16-plus/':52,'/catalog/remont-iphone/16-/remont-iphone-16-pro/':54,'/catalog/remont-iphone/16-/remont-iphone-16-pro-max1782/':55,'/catalog/remont-iphone/remont-iphone-17/remont-iphone_17/':47}
ser16=[c for c,v in cats.items() if v['slug']=='phone-16']; 
if ser16: ALIAS['/catalog/remont-iphone/16-/']=ser16[0]
RULES=[(r'razgovorn',r'разговорного микрофона'),(r'mikrofon',None),(r'chistk|zaschitnoe|zashchitnoe|proverka|perenos|pereprosh|kontroller|mikroskh|antenn|modem|audiokodek|nand|rebolling|true-tone|wi-fi|bluetooth|nfc|bezzvuch|knopki-home|setk|khripit|hripit',None),
 (r'ne-vklyuch|materinsk',r'^Ремонт материнской платы'),
 (r'zadney-kamery|zadnej-kamery',r'Задняя камера|задней камеры'),
 (r'peredney-kamery|perednej-kamery|frontaln',r'Передняя камера|передней камеры'),
 (r'polifonich',r'полифонического'),
 (r'zamena-dinamika|sluhov|slukhov',r'слухового динамика'),
 (r'knopki-blokirovki|knopok-gromkosti|knopki-gromkosti',r'шлейфа кнопок'),
 (r'zaschity-ot-pyli|zashchity-ot-pyli|prokle',r'защиты от пыли'),
 (r'posle-vody|popala-zhidk|popadaniya-zhidk',r'после попадания жидкости'),
 (r'akkumul|batare',r'аккумулятора'),
 (r'zadnego-stekla|zadney-kryshki|zadnej-kryshki',r'заднего стекла'),
 (r'stekla-kamery|glazk',r'глазка камеры'),
 (r'face-id',r'^Ремонт Face ID'),
 (r'korpus',r'Замена корпуса'),
 (r'razem|razyem|zaryadk',r'разъ[её]ма зарядки'),
 (r'klaviatur',r'клавиатуры'),(r'tachpad|touchpad|trekpad',r'тачпада'),(r'tachbar|touchbar',r'тачбара'),
 (r'matric|matrits|displ|ekran',r'^Замена дисплея'),
 (r'stekl',r'^Замена стекла')]
def find_product(cid,slug):
    for rx,name in RULES:
        if re.search(rx,slug):
            if not name: return None
            c=[p for p in bycat.get(cid,[]) if re.search(name,prods[p]['name'],re.I)]
            c.sort(key=lambda p:(prods[p]['parent']!=0,p))
            return c[0] if c else None
    return None
plan=[l.rstrip('\n').split('\t') for l in open(P+'redirect-plan-draft-2026-10-06.tsv',encoding='utf-8')]
out=[];stat=Counter();nomap=[]
for src,tgt,up in plan:
    parts=src.strip('/').split('/'); obj=None
    # ближайший предок: сначала ручные соответствия мёртвых разделов, потом живой адрес
    for k in range(1,len(parts)):
        anc='/'+'/'.join(parts[:-k])+'/'
        if anc in ALIAS: obj=('c',ALIAS[anc]); break
        if anc==tgt: obj=url2obj.get(tgt); break
    if src in ALIAS: obj=('c',ALIAS[src])
    if not obj: nomap.append((src,tgt)); continue
    kind='раздел'
    if obj[0]=='c':
        pid=find_product(obj[1],parts[-1])
        if pid: obj=('p',pid); kind='та же услуга'
    s=src.rstrip('/')
    if s in have: stat['уже есть']+=1; continue
    stat[kind]+=1
    name=prods[obj[1]]['name'] if obj[0]=='p' else cats[obj[1]]['name'] if obj[0]=='c' else pages[obj[1]]['name']
    out.append((s,obj[0],obj[1],name))
print(dict(stat),'| без цели:',len(nomap)); [print('  NOMAP',x) for x in nomap[:15]]
open(P+'redirects-2026-10-06.tsv','w',encoding='utf-8').write('старый адрес\tтип\tid\tкуда ведёт\n'+'\n'.join('\t'.join(map(str,r)) for r in out)+'\n')
esc=lambda s:s.replace('\\','\\\\').replace("'","\\'")
with open('redirects.sql','w',encoding='utf-8') as f:
    for i in range(0,len(out),200):
        f.write("insert into cscart_seo_redirects (src,dest,type,object_id,company_id,lang_code) values "+','.join("('%s','','%s',%d,1,'ru')"%(esc(s),t,o) for s,t,o,_ in out[i:i+200])+';\n')
tc=Counter((t,n) for _,t,_,n in out); print('топ целей:'); [print('  ',v,k) for k,v in tc.most_common(8)]
import random; random.seed(3)
print('примеры «та же услуга»:'); [print('  ',s[-70:],'→',n) for s,t,o,n in random.sample([r for r in out if r[1]=='p'],10)]
print('длина src >255:',sum(len(r[0])>255 for r in out))
