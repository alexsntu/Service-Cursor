import re
from collections import defaultdict
R=[l.rstrip('\n').split('\t') for l in open('meta.tsv',encoding='utf-8')]
C={r[1]:r for r in R if r[0]=='C'}; P={r[1]:r for r in R if r[0]=='P'}; A={r[1]:r for r in R if r[0]=='A'}
upd={}   # (kind,id) -> [title,desc]
def cur(k,i): r={'C':C,'P':P,'A':A}[k][i]; return upd.setdefault((k,i),[r[5].strip(),r[6].strip()])
def setm(k,i,t=None,d=None):
    c=cur(k,i)
    if t is not None: c[0]=t
    if d is not None: c[1]=d
def model(name,prefix): return name[len(prefix):].strip()
log=defaultdict(int)
# --- A. Замена кнопок громкости (пустые и скопированные со «шлейфа») ---
for i,r in P.items():
    n=r[4].strip()
    if r[3]!='0': continue
    if n.startswith('Замена кнопок громкости iPhone'):
        m=model(n,'Замена кнопок громкости')
        setm('P',i,f'Замена кнопок громкости {m} в Москве | iRepair',
             f'Замена кнопок громкости {m} (Айфон) в Москве в сервисном центре iRepair — диагностика бесплатно, гарантия на работу и запчасть. Вернём регулировку звука, если кнопки залипают, проваливаются или не реагируют на нажатие. Курьер по Москве.'); log['кнопки громкости']+=1
    elif n.startswith('Восстановление функции Face ID iPhone'):
        m=model(n,'Восстановление функции Face ID')
        setm('P',i,f'Восстановление Face ID {m} в Москве | iRepair',
             f'Восстановление функции Face ID на {m} (Айфон) в Москве в сервисном центре iRepair — диагностика бесплатно. Вернём разблокировку по лицу после падения, попадания влаги или неудачного ремонта: работаем с датчиками TrueDepth на уровне компонентов. Курьер по Москве.'); log['восстановление Face ID']+=1
# --- B. iPhone 17e без мета ---
for i,svc,txt in (('625','Замена шлейфа кнопок громкости и блокировки','Починим боковые кнопки, если они залипают, не нажимаются или не срабатывает блокировка экрана.'),
                  ('669','Замена слухового динамика','Вернём громкость разговора, если собеседника плохо слышно, динамик хрипит или молчит.'),
                  ('713','Замена полифонического динамика','Вернём звук звонка и музыки, если динамик хрипит, играет тихо или молчит.')):
    setm('P',i,f'{svc} iPhone 17e в Москве | iRepair',f'{svc} iPhone 17e (Айфон 17е) в Москве в сервисном центре iRepair — диагностика бесплатно, гарантия на работу и запчасть. {txt} Курьер по Москве.'); log['17e']+=1
# --- C. Пары, где мета одна на две модели: добавить отличие ---
def sub(i,a,b):
    t,d=cur('P',i); setm('P',i,t.replace(a,b),d.replace(a,b)); log['пары моделей']+=1
for i,tok in (('145','M4'),('146','M5'),('1324','M5'),('1325','M4'),('1379','M5'),('1380','M4')): sub(i,'iPad Pro 13','iPad Pro 13 '+tok)
t,d=cur('P','1455'); setm('P','1455',t.replace('Apple Watch SE','Apple Watch SE 2'),d if 'SE 2' in d else d.replace('Apple Watch SE','Apple Watch SE 2'))
setm('P','1296',t="Замена дисплея iPad Pro 13 M5 в Москве | Сервис iRepair")
# --- D. Одинаковые описания у разных услуг: начать с названия услуги и модели ---
main=[r for r in R if r[0]=='P' and r[3]=='0']
g=defaultdict(list)
for r in main:
    t,d=cur('P',r[1]) if ('P',r[1]) in upd else (r[5].strip(),r[6].strip())
    if d: g[d].append(r)
for d,v in g.items():
    if len(v)<2: continue
    for r in v:
        name=re.sub(r'\s*/\s*',' и ',r[4].strip()); name=name.replace('громкости и блокировки','громкости и блокировки')
        nd=f'{name} в Москве. {d}'
        while len(nd)>255 and '. ' in nd[len(name)+12:]:
            nd=nd[:nd.rstrip('. ').rfind('. ')+1]
        setm('P',r[1],d=nd); log['одинаковые описания']+=1
# одинаковые title (шлейф ↔ кнопки уже разведены; Face ID разведены) — проверка ниже
# --- E. Категории ---
setm('C','153','Ремонт Apple Watch SE 3 в Москве | Сервис iRepair','Ремонт Apple Watch SE 3 в Москве срочно: бесплатная диагностика, гарантия до 1 года, запчасть и работа включены. Замена стекла, дисплея и аккумулятора. Выезд курьера по Москве. 8 (800) 555-21-90')
setm('C','111','Ремонт iPad Pro 13 M4 в Москве | Сервис iRepair','Ремонт iPad Pro 13 M4 (2024) в Москве: замена стекла, дисплея или аккумулятора. Бесплатная диагностика, гарантия до 1 года. Курьер в пределах МКАД. 8 (800) 555-21-90')
setm('C','84','Ремонт iPhone 7 в Москве — замена экрана, аккумулятора | iRepair','Ремонт iPhone 7 (Айфон 7) в Москве в сервисном центре iRepair — диагностика бесплатно. Замена экрана, аккумулятора, разъёма зарядки, камеры и кнопок, чистка после попадания воды. Запчасти в наличии, гарантия. Курьер по Москве.')
setm('C','3','Каталог услуг по ремонту техники Apple в Москве | iRepair','Каталог услуг сервисного центра iRepair в Москве: ремонт iPhone, MacBook, iPad, iMac и Apple Watch. Выберите устройство и модель — покажем цены, сроки и гарантию. Диагностика бесплатно, курьер по Москве.')
setm('C','127','Выбор модели устройства Apple для ремонта | iRepair','Выберите услугу и модель iPhone, MacBook, iPad, iMac или Apple Watch — покажем цену, срок и гарантию на ремонт в сервисном центре iRepair в Москве. Диагностика бесплатно, курьер по Москве.')
setm('C','54',t='Ремонт iPhone 16 Pro. Пейте кофе, а мы отремонтируем iPhone | iRepair')
setm('C','44',t='Услуга по ремонту Apple Watch SE 2 в Москве | Сервис iRepair')
# --- F. Страницы и блог ---
setm('A','39','Полезные статьи о ремонте вашей техники Apple от iRepair','Все о ремонте вашего iPhone или MacBook от мастеров сервисного центра Apple в Москве - iRepair. Что и как можно сделать самому, а когда лучше нести в ремонт.')
setm('A','44',t='Как очистить и продлить срок службы клавиатуры MacBook | iRepair')
setm('A','26',d='Отзывы клиентов о сервисном центре Apple iRepair в Москве: ремонт iPhone, MacBook, iPad и Apple Watch. Оставьте отзыв о ремонте и участвуйте в ежемесячном розыгрыше подарков.')
setm('A','30','Пользовательское соглашение | Сервисный центр iRepair','Пользовательское соглашение сайта сервисного центра Apple iRepair в Москве: условия использования сайта, права и обязанности сторон.')
setm('A','31',d='Политика сервисного центра Apple iRepair в отношении обработки персональных данных: какие данные мы собираем, как храним и защищаем, права пользователей.')
# --- G. Цена курьера в мета (250 — устарела, на сайте от 350): убираем сумму ---
PAT=[(r'\s*(от|—|-|за|по цене)?\s*250\s?(₽|руб(лей|\.)?)(\s+по Москве)?',lambda m:' по Москве' if m.group(5) else '')]
def strip_courier(s):
    s2=re.sub(r'(курьер\w*|доставк\w*)([^.;✓◈►→|]{0,40}?)\s*(?:—|-|от|за|по цене)?\s*250\s?(?:₽|руб(?:лей|\.)?)',lambda m:m.group(1)+m.group(2).rstrip(' —-'),s,flags=re.I)
    return re.sub(r'\s{2,}',' ',s2).replace(' .','.').replace(' ;',';')
for k,D in (('C',C),('P',P),('A',A)):
    for i,r in D.items():
        t,d=upd.get((k,i),[r[5].strip(),r[6].strip()])
        nt,nd=strip_courier(t),strip_courier(d)
        if (nt,nd)!=(t,d): setm(k,i,nt,nd); log['цена курьера 250 убрана']+=1
for k,D in (('C',C),('P',P),('A',A)):
    for i,r in D.items():
        t,d=upd.get((k,i),[r[5].strip(),r[6].strip()])
        nt,nd=[re.sub(r'\+7 \(49[59]\) \d{3}-\d{2}-\d{2}','8 (800) 555-21-90',x) for x in (t,d)]
        if (nt,nd)!=(t,d): setm(k,i,nt,nd); log['телефон заменён на 8 800']+=1
for key,v in upd.items():
    if len(v[1])>250: v[1]=v[1].replace(' в сервисном центре iRepair',' в iRepair')
    while len(v[1])>250 and '. ' in v[1][40:]:
        v[1]=v[1][:v[1].rstrip('. ').rfind('. ')+1]
    assert len(v[1])<=255 and len(v[0])<=255,(key,len(v[1]))
left=[(k,i) for k,D in (('C',C),('P',P),('A',A)) for i,r in D.items() if re.search(r'250\s?(₽|руб)',' '.join(upd.get((k,i),[r[5],r[6]])))]
print(dict(log)); print('осталось с «250 ₽/руб»:',len(left),[ (k,i,' '.join(upd.get((k,i),[{'C':C,'P':P,'A':A}[k][i][5],{'C':C,'P':P,'A':A}[k][i][6]]))[:130]) for k,i in left[:4]])
# проверка дублей после правок (главные товары, категории)
for kind,D,cond in (('P',P,lambda r:r[3]=='0'),('C',C,lambda r:True)):
    for fld in (0,1):
        gg=defaultdict(list)
        for i,r in D.items():
            if not cond(r): continue
            v=upd.get((kind,i),[r[5].strip(),r[6].strip()])[fld]
            if v: gg[v].append(i)
        dd={k:v for k,v in gg.items() if len(v)>1}
        print(kind,'дубли','title' if fld==0 else 'desc',len(dd),list(dd.items())[:3])
empt=[(k,i,D[i][4]) for k,D in (('C',C),('P',P),('A',A)) for i in D if (k!='P' or D[i][3]=='0') and not all(upd.get((k,i),[D[i][5].strip(),D[i][6].strip()]))]
print('пустые после правок:',empt)
print('макс длина title:',max(len(v[0]) for v in upd.values()),'desc:',max(len(v[1]) for v in upd.values()))
import random; random.seed(5)
for key in random.sample(sorted(upd),6)+[('P','471'),('P','657'),('C','16')]: print(key,'\n   T:',upd[key][0],'\n   D:',upd[key][1])
esc=lambda s:s.replace('\\','\\\\').replace("'","\\'")
T={'C':('cscart_category_descriptions','category_id'),'P':('cscart_product_descriptions','product_id'),'A':('cscart_page_descriptions','page_id')}
with open('fixmeta.sql','w',encoding='utf-8') as f:
    for (k,i),(t,d) in sorted(upd.items()):
        f.write(f"update {T[k][0]} set page_title='{esc(t)}', meta_description='{esc(d)}' where {T[k][1]}={int(i)};\n")
open('/Users/a0000/Документы/Cursor/Service-Cursor/Новый проект сервиса/migration/meta-fixes-2026-10-06.tsv','w',encoding='utf-8').write('тип\tid\tназвание\ttitle было\ttitle стало\tdescription было\tdescription стало\n'+'\n'.join('\t'.join([k,i,{'C':C,'P':P,'A':A}[k][i][4].strip(),{'C':C,'P':P,'A':A}[k][i][5].strip(),t,{'C':C,'P':P,'A':A}[k][i][6].strip(),d]) for (k,i),(t,d) in sorted(upd.items()))+'\n')
print('обновлений:',len(upd))
