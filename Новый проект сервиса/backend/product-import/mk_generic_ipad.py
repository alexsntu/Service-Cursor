"""Общие услуги iPad (владелец 2026-10-04: «по пункту 2» — одна услуга на все iPad с ценой «от …», данные — со старого
товара-примера iPad 8, редиректы со всех старых адресов по моделям). Список услуг и старые адреса — <scratch>/ipad_generic2.json.

  python3 mk_generic_ipad.py <scratch> dry|real
"""
import base64, json, os, re, subprocess, sys, urllib.request

S, mode = sys.argv[1], sys.argv[2]
AUTH = base64.b64encode(os.environ['CSCART_AUTH'].encode()).decode()
CATS = [6] + [c for c in range(97, 127) if c != 118]
META = {
    'KORPUS': ('Замена корпуса iPad в Москве — цена, сроки | iRepair', 'Замена корпуса iPad (Айпад) в Москве: меняем погнутую, поцарапанную или разбитую заднюю крышку планшета на новую с переносом всех компонентов. Работа занимает от 2 часов, диагностика бесплатно, гарантия в iRepair.'),
    'KAMERA': ('Замена задней камеры iPad (Айпад) в Москве | iRepair', 'Замена задней камеры iPad (Айпад) в Москве: меняем основную камеру, если планшет не фокусируется, снимает с пятнами или показывает чёрный экран в приложении «Камера». Работа от 90 минут, диагностика бесплатно, гарантия.'),
    'FRONT': ('Замена передней камеры iPad в Москве | iRepair', 'Замена передней камеры iPad (Айпад) в Москве: восстанавливаем фронтальную камеру для видеозвонков и селфи, если изображение мутное или камера не включается. Работа от 90 минут, диагностика бесплатно, гарантия iRepair.'),
    'DINAMIK': ('Замена полифонического динамика iPad в Москве | iRepair', 'Замена полифонического динамика iPad (Айпад) в Москве: меняем динамик, если звук пропал, стал тихим или хрипит при воспроизведении музыки и видео. Работа занимает от 90 минут, диагностика бесплатно, гарантия iRepair.'),
    'MIKROFON': ('Замена микрофона iPad (Айпад) в Москве | iRepair', 'Замена микрофона iPad (Айпад) в Москве: меняем микрофон, если собеседник вас не слышит, голос записывается тихо или с шумами. Работа занимает от 90 минут, диагностика бесплатно, гарантия на ремонт в сервисе iRepair.'),
    'WIFI': ('Замена шлейфа Wi-Fi iPad (Айпад) в Москве | iRepair', 'Замена шлейфа Wi-Fi iPad (Айпад) в Москве: восстанавливаем антенну, если планшет не видит сети, теряет соединение или ловит сигнал только рядом с роутером. Работа от 90 минут, диагностика бесплатно, гарантия iRepair.'),
    'KONTROLLER': ('Замена контроллера питания iPad в Москве | iRepair', 'Замена контроллера питания iPad (Айпад) в Москве: меняем микросхему на материнской плате, если планшет не заряжается, быстро разряжается или не включается. Срок ремонта от 1 до 3 дней, диагностика бесплатно, гарантия.'),
    'PLATA': ('Ремонт материнской платы iPad в Москве | iRepair', 'Ремонт материнской платы iPad (Айпад) в Москве: восстанавливаем цепи питания, меняем микросхемы и устраняем последствия удара или влаги. Срок ремонта от 1 до 3 дней, диагностика бесплатно, гарантия на работу iRepair.'),
    'PROSHIVKA': ('Перепрошивка iPad в Москве — восстановление iPadOS | iRepair', 'Перепрошивка iPad (Айпад) в Москве: восстанавливаем iPadOS, если планшет завис на яблоке, не обновляется или показывает ошибку при восстановлении. Работа занимает от 30 минут, диагностика бесплатно, гарантия iRepair.'),
}


def cs(method, path, data=None):
    req = urllib.request.Request('https://dev.irepair.ru/api.php?_d=' + path, method=method,
                                 data=json.dumps(data).encode() if data is not None else None,
                                 headers={'Authorization': 'Basic ' + AUTH, 'Content-Type': 'application/json'})
    return json.loads(urllib.request.urlopen(req, timeout=90).read())


def sql(q):
    return subprocess.run(['ssh', '-i', os.path.expanduser('~/.ssh/irepair_firstvds'), 'root@188.120.249.151',
                           'mysql --defaults-extra-file=/root/.my.cscart.cnf irepair_cscart -N -e ' + json.dumps(q)],
                          capture_output=True, text=True, check=True).stdout


svc = json.load(open(f'{S}/ipad_generic2.json'))
for x in svc:
    t, d = META[x['key']]
    assert 45 <= len(t) <= 70 and 180 <= len(d) <= 250, (x['key'], len(t), len(d))
    print(x['key'], x['name'], '| от', x['price'], '| старых адресов', len(x['urls']), '| title', len(t), 'desc', len(d))
if mode == 'dry':
    sys.exit(0)
state_p = f'{S}/ipad_generic2_state.json'
state = json.load(open(state_p)) if os.path.exists(state_p) else {}
for x in svc:
    if x['key'] in state:
        print('skip', x['key'])
        continue
    cmd = ['python3', 'import_service.py', '--cat', '6', '--old-product', str(x['ex']), '--old-ignore-options', '--position', str(x['pos']), '--price', str(x['price']),
           '--price-from', '--name', x['name'], '--slug', x['slug'], '--rename-model', 'iPad 8', 'iPad']
    r = subprocess.run(cmd, stdin=subprocess.DEVNULL, capture_output=True, text=True)
    m = re.search(r'^(\d+) \| ', r.stdout, re.M)
    assert m, (x['key'], r.stdout[-1500:], r.stderr[-800:])
    pid = int(m.group(1))
    t, d = META[x['key']]
    cs('PUT', f'products/{pid}', {'category_ids': CATS, 'main_category': 6, 'page_title': t, 'meta_description': d, 'product_code': f"TAB-IPAD-{x['key']}"})
    sql(f"update cscart_products_categories set position={x['pos']} where product_id={pid}")
    have = {l.split('\t')[0] for l in sql(f"select src from cscart_seo_redirects where type='p' and object_id={pid}").split('\n') if l}
    vals = [f"('{u}','','p',{pid},1,'ru')" for u in x['urls'] if u not in have]
    if vals:
        sql('insert into cscart_seo_redirects (src,dest,type,object_id,company_id,lang_code) values ' + ','.join(vals))
    state[x['key']] = pid
    json.dump(state, open(state_p, 'w'))
    p = cs('GET', f'products/{pid}')
    f = p['product_features']
    print('создан', pid, p['product'], p['price'], p['product_code'], len(p['category_ids']), 'кат. | от:', f.get('19', {}).get('value'), '|', f['4']['value'], '|', f.get('5', {}).get('value'),
          '| редиректов', len(vals), '| «iPad 8» в описании:', 'iPad 8' in (p.get('full_description') or ''))
