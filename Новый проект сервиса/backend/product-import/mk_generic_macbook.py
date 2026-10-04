"""Общие услуги MacBook (строки таблицы 1092–1100, владелец 2026-10-04): один товар на все модели,
где цен две — выбор варианта плитками. Главная категория 5 «Ремонт MacBook» + категории моделей."""
import os,json,base64,urllib.request,sys,subprocess,csv
S,mode=sys.argv[1],sys.argv[2]
auth=base64.b64encode(os.environ['CSCART_AUTH'].encode()).decode()
def cs(m,path,data=None):
    req=urllib.request.Request('https://dev.irepair.ru/api.php?_d='+path,method=m,data=json.dumps(data).encode() if data else None,headers={'Authorization':'Basic '+auth,'Content-Type':'application/json'})
    return json.loads(urllib.request.urlopen(req,timeout=90).read())
def sql(q):
    return subprocess.run(['ssh','-i',os.path.expanduser('~/.ssh/irepair_firstvds'),'root@188.120.249.151','mysql --defaults-extra-file=/root/.my.cscart.cnf irepair_cscart -N -e '+json.dumps(q)],capture_output=True,text=True,check=True).stdout
CATS=[5,90,91,92,93,94,95,96,23]
FEATS={
 'save':('Сохранение данных',[('Без сохранения данных','Чистая установка macOS: все данные на накопителе удаляются'),('С сохранением данных','Переустановка системы с сохранением ваших файлов, программ и настроек')]),
 'year':('Год выпуска MacBook',[('До 2020 года','Для моделей MacBook, выпущенных до 2020 года'),('После 2020 года','Для моделей MacBook, выпущенных после 2020 года')]),
 'kbd':('Способ чистки клавиатуры',[('Без разбора клавиатуры','Чистка клавиатуры без снятия клавиш'),('С разбором клавиатуры','Глубокая чистка со снятием клавиш')]),
}
SVC=[
 dict(name='Перенос данных MacBook',slug='perenos-dannyh-macbook',pos=90,time='от 60 минут',items=[(1092,None,3490)],
      title='Перенос данных на новый MacBook в Москве | iRepair',
      desc='Перенос данных на MacBook (Макбук) в Москве: файлы, фото, программы и настройки со старого Mac или Windows-компьютера на новый ноутбук. Работу выполняет инженер iRepair от 60 минут, диагностика бесплатно.',
      old=[8319,8367,8338,8246,8264,8283,8301]),
 dict(name='Переустановка macOS MacBook',slug='pereustanovka-macos-macbook',pos=100,time='от 60 минут',feat='save',items=[(1093,'Без сохранения данных',2490),(1094,'С сохранением данных',4990)],
      title='Переустановка macOS на MacBook в Москве | iRepair',
      desc='Переустановка macOS на MacBook (Макбук) в Москве: чистая установка системы или восстановление с сохранением данных, файлов и программ. Устраняем сбои и зависания от 60 минут, диагностика бесплатно, гарантия на работу.',
      old=[8317,8365,8336,8244,8262,8281,8299,8318,8366,8337,8245,8263,8282,8300]),
 dict(name='Замена клавиши клавиатуры MacBook',slug='zamena-klavishi-klaviatury-macbook',pos=110,time='от 10 минут',items=[(1095,None,490)],
      title='Замена клавиши клавиатуры MacBook в Москве | iRepair',
      desc='Замена клавиши клавиатуры MacBook (Макбук) в Москве: меняем отдельную кнопку и механизм крепления без замены всей клавиатуры и топкейса. Работа занимает от 10 минут, диагностика бесплатно, гарантия на ремонт в iRepair.',
      old=[8323,8342,8352,8250,8268,8287,8305]),
 dict(name='Замена комплекта клавиш клавиатуры MacBook',slug='zamena-komplekta-klavish-klaviatury-macbook',pos=120,time='от 30 минут',items=[(1096,None,4990)],
      title='Замена комплекта клавиш MacBook в Москве | iRepair',
      desc='Замена комплекта клавиш клавиатуры MacBook (Макбук) в Москве: устанавливаем полный набор кнопок с русской раскладкой с сохранением подсветки. Работа занимает от 30 минут, диагностика бесплатно, гарантия в iRepair.',
      old=[8322,8341,8351,8249,8267,8286,8304]),
 dict(name='Чистка MacBook после попадания жидкости',slug='chistka-macbook-posle-popadaniya-zhidkosti',pos=130,time='от 60 минут',feat='year',items=[(1097,'До 2020 года',2490),(1098,'После 2020 года',4990)],
      title='Чистка MacBook после попадания жидкости в Москве | iRepair',
      desc='Чистка MacBook (Макбук) после попадания жидкости в Москве: разбираем ноутбук, удаляем влагу и окислы с материнской платы, предотвращаем коррозию. Работа от 60 минут, диагностика бесплатно, гарантия в сервисе iRepair.',
      old=[8314,8362,8333,8241,8259,8278,8296]),
 dict(name='Чистка клавиатуры MacBook',slug='chistka-klaviatury-macbook',pos=140,time='от 2 часов',feat='kbd',items=[(1099,'Без разбора клавиатуры',2490),(1100,'С разбором клавиатуры',4990)],
      title='Чистка клавиатуры MacBook (Макбук) в Москве | iRepair',
      desc='Чистка клавиатуры MacBook (Макбук) в Москве: удаляем пыль, крошки и следы жидкости, возвращаем клавишам ход без залипаний. Доступна чистка без разбора и с разбором клавиатуры, диагностика бесплатно, гарантия iRepair.',
      old=[8316,8364,8335,8344,8243,8261,8280,8298]),
]
urls={r['product_id']:(r['status'],f"/{r['path']}/{r['kw']}") for r in csv.DictReader(open(f'{S}/old_urls_mb.tsv',encoding='utf-8'),delimiter='\t')}
for x in SVC:
    assert 45<=len(x['title'])<=70 and 180<=len(x['desc'])<=250,(x['name'],len(x['title']),len(x['desc']))
    print(x['name'],'|',x['items'],'| title',len(x['title']),'desc',len(x['desc']),'| old urls',len(x['old']))
if mode=='dry': sys.exit(0)
fid={}
state_p=f'{S}/generic_mb_state.json'; state=json.load(open(state_p)) if os.path.exists(state_p) else {}
base={'feature_type':'S','purpose':'group_variation_catalog_item','feature_style':'dropdown_labels','filter_style':'checkbox','status':'A','position':10,'display_on_product':'N','display_on_catalog':'N','display_on_header':'N','company_id':1,'categories_path':','.join(map(str,CATS))}
for k,(fname,vals) in FEATS.items():
    if 'feat_'+k not in state:
        state['feat_'+k]=cs('POST','features',{**base,'description':fname,'variants':[{'variant':v,'position':(i+1)*10,'description':d} for i,(v,d) in enumerate(vals)]})['feature_id']; json.dump(state,open(state_p,'w'))
    f=cs('GET',f"features/{state['feat_'+k]}"); fid[k]=(state['feat_'+k],{v['variant'].strip():str(v['variant_id']) for v in f['variants'].values()})
    print('feature',k,fid[k])
for x in SVC:
    if x['slug'] in state: print('skip',x['slug']); continue
    ids=[]
    for n,(row,val,price) in enumerate(x['items']):
        feats={'4':'1 месяц','5':x['time']}
        if val: feats[str(fid[x['feat']][0])]=fid[x['feat']][1][val]
        body=dict(product=x['name'],price=price,product_code=f'TAB-{row}',status='A',category_ids=CATS,main_category=5,company_id=1,page_title=x['title'],meta_description=x['desc'],product_features=feats)
        if n==0: body['seo_name']=x['slug']
        ids.append((cs('POST','products',body)['product_id'],val,feats))
    pids=[p for p,_,_ in ids]
    if x.get('feat'):
        g=cs('POST','product_variations_groups',{'product_ids':pids,'code':x['slug'],'features':[{'feature_id':fid[x['feat']][0],'purpose':'group_variation_catalog_item'}]})
        for pid,val,feats in ids[1:]: cs('PUT',f'products/{pid}',{'product':f"{x['name']} | {val}"})
        for pid,val,feats in ids: cs('PUT',f'products/{pid}',{'product_features':feats})
    L=','.join(map(str,pids))
    sql(f"update cscart_products_categories set position={x['pos']} where product_id in ({L})")
    sql(f"delete from cscart_seo_redirects where type='p' and object_id in ({L})")
    vals=[]
    for o in x['old']:
        st,u=urls[str(o)]
        vals.append(f"('{u}','','p',{pids[0]},1,'ru')")
    sql('insert into cscart_seo_redirects (src,dest,type,object_id,company_id,lang_code) values '+','.join(vals))
    state[x['slug']]=pids; json.dump(state,open(state_p,'w'))
    print('created',x['name'],pids,'redirects',len(vals))
