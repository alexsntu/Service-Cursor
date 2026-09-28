"""Импорт одной услуги (со всеми вариантами) из RemOnline в CS-Cart — по процедуре из памяти Claude
(project_cscart_product_import): главный товар = самый дешёвый вариант, ему название и URL старого сайта
(`_` → `-`) + 301-редирект; всем вариантам — картинки, title, meta description, описание (prep_desc.py),
гарантия (столбец L таблицы → характеристика 4), время ремонта (upc старого товара → характеристика 5).
Картинки после создания обрезаются по контуру объекта (crop_images.py).
Товары создаются СРАЗУ в нужной категории и ВКЛЮЧЁННЫМИ.

  python3 import_service.py --cat 48 --feature 3 60709691 60709695

Доступы — только через переменные окружения (в репозиторий не кладём):
  CSCART_AUTH="admin@irepair.ru:<api key>"   RO_KEY="<RemOnline key>"   SSHPASS="<пароль старого сервера>"
Флаг --dry-run: только собрать и показать данные, ничего не создавать.
"""
import argparse
import base64
import html
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

import openpyxl

from crop_images import _run, crop_products

HERE = os.path.dirname(os.path.abspath(__file__))
TABLE = os.path.expanduser('~/Документы/Сервис/Новая таблица888.xlsx')
PRICE_ID = 543835
OLD_SSH = 'www-root@31.31.207.64'
NEW_SSH = ['ssh', '-o', 'ConnectTimeout=20', '-i', os.path.expanduser('~/.ssh/irepair_firstvds'), 'root@188.120.249.151']
API = 'https://dev.irepair.ru/api.php?_d='

ap = argparse.ArgumentParser()
ap.add_argument('--cat', type=int, required=True, help='id категории CS-Cart')
ap.add_argument('--feature', type=int, required=True, help='id характеристики вариантов (напр. 3 = тип запчасти аккумулятора)')
ap.add_argument('--dry-run', action='store_true')
ap.add_argument('ro_ids', nargs='+')
args = ap.parse_args()

AUTH = 'Basic ' + base64.b64encode(os.environ['CSCART_AUTH'].encode()).decode()


def cs(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={'Authorization': AUTH, 'Content-Type': 'application/json'})
    return json.loads(urllib.request.urlopen(req, timeout=180).read() or b'{}')


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *a, **k):
        return None


def head(url):
    """HTTP-код и Location без перехода по редиректам."""
    try:
        r = urllib.request.build_opener(_NoRedirect).open(urllib.request.Request(url, method='HEAD'), timeout=60)
        return r.status, None
    except urllib.error.HTTPError as e:
        return e.code, e.headers.get('Location')


def ro(sid):
    req = urllib.request.Request(f'https://api.roapp.io/v2/catalog/services/{sid}',
                                 headers={'Authorization': 'Bearer ' + os.environ['RO_KEY']})
    d = json.loads(urllib.request.urlopen(req, timeout=60).read())
    d = d.get('data', d)
    price = next(float(p['price']) for p in d['prices'] if p['id'] == PRICE_ID)
    return d['title'].strip(), int(round(price))


def sql_new(q):
    # _run: SSH до dev иногда рвётся («Connection closed», 255) — до 6 попыток
    return _run(NEW_SSH + ['mysql --defaults-extra-file=/root/.my.cscart.cnf irepair_cscart -N -e ' + json.dumps(q)],
                capture_output=True, text=True).stdout


# 1. RemOnline
items = []
for sid in args.ro_ids:
    title, price = ro(sid)
    items.append({'ro': sid, 'title': title, 'price': price, 'value': title.split('|')[-1].strip() if '|' in title else ''})
    time.sleep(0.4)
items.sort(key=lambda x: x['price'])

# 2. Таблица: RO id → старый product_id, гарантия (L), старый URL (D)
ws = openpyxl.load_workbook(TABLE, read_only=True, data_only=True)['МСервис']
rows = {str(r[4]).replace('.0', ''): r for r in ws.iter_rows(values_only=True) if r[4] is not None}
for it in items:
    r = rows[it['ro']]
    it['old_id'] = int(re.search(r'product_id=(\d+)', r[1]).group(1))
    it['warranty'] = str(int(r[11])) if r[11] not in (None, '') else ''
old_ids = {it['old_id'] for it in items}
assert len(old_ids) == 1, f'варианты ссылаются на разные старые товары: {old_ids}'
old_id = old_ids.pop()

# 3. Старый сайт (только чтение)
q = (f'select name, meta_title, meta_description, description from oc_product_description where product_id={old_id} and language_id=1;'
     f'select keyword from oc_seo_url where query="product_id={old_id}";'
     f'select image, upc from oc_product where product_id={old_id};'
     f'select image from oc_product_image where product_id={old_id} order by sort_order;')
remote = ('cd ~/www/irepair.ru && P=$(php -r "include \\"config.php\\"; echo DB_PASSWORD;") && '
          f"mysql -uocstore -p\"$P\" ocstore --batch -e '{q}' 2>/dev/null")
# байты, а не text=True: в старых данных бывает \r, текстовый режим превратил бы его в перенос строки
# SSH до старого сервера иногда разово отвечает 255 — повторяем (до 4 попыток)
for attempt in range(4):
    try:
        out = subprocess.run(['sshpass', '-e', 'ssh', '-o', 'ConnectTimeout=20', OLD_SSH, remote],
                             capture_output=True, check=True).stdout.decode('utf-8').split('\n')
        break
    except subprocess.CalledProcessError:
        if attempt == 3:
            raise
        time.sleep(10)


def unesc(s):
    return s.replace('\\\\', '\x00').replace('\\n', '\n').replace('\\t', '\t').replace('\\r', '\r').replace('\x00', '\\')


# вывод --batch: заголовок + строки для каждого запроса
blocks, cur = [], None
for line in out:
    if line in ('name\tmeta_title\tmeta_description\tdescription', 'keyword', 'image\tupc', 'image'):
        cur = []
        blocks.append(cur)
    elif cur is not None and line:
        cur.append(line)
name, meta_title, meta_desc, desc_raw = blocks[0][0].split('\t')
name, meta_title, meta_desc = [html.unescape(unesc(x)).strip() for x in (name, meta_title, meta_desc)]
slug = blocks[1][0].strip()
main_img, upc = (blocks[2][0].split('\t') + [''])[:2]
extra_imgs = [x.strip() for x in blocks[3]] if len(blocks) > 3 else []
upc = upc.strip()
desc_in = html.unescape(unesc(desc_raw))
assert not any(ord(ch) > 0xFFFF for ch in name + meta_title + meta_desc + desc_in), '4-байтовые символы (эмодзи) — CS-Cart их не сохранит'
old_url = next((rows[it['ro']][3] for it in items if rows[it['ro']][3]), '')
# столбец D бывает неверным (напр. у 9005 там адрес замены дисплея) — берём папку категории из D + настоящий slug
# старого товара и проверяем, что адрес живой на старом сайте
if old_url:
    cand = old_url.rstrip('/').rsplit('/', 1)[0] + '/' + slug + '/'
    code = head(cand)[0]
    if cand != old_url:
        print(f'!!! столбец D: {old_url} → по slug старого товара: {cand} (HTTP {code})')
    if code == 200:
        old_url = cand
    else:
        print('!!! старый адрес не подтверждён — редирект не создаём, проверить вручную')
        old_url = ''

with tempfile.TemporaryDirectory() as tmp:
    open(os.path.join(tmp, 'in.html'), 'w', encoding='utf-8').write(desc_in)
    subprocess.run([sys.executable, os.path.join(HERE, 'prep_desc.py'), os.path.join(tmp, 'in.html'), os.path.join(tmp, 'out.html')], check=True)
    desc = open(os.path.join(tmp, 'out.html'), encoding='utf-8').read() if desc_in.strip() else ''

# значения характеристики вариантов
feat = cs('GET', f'features/{args.feature}')
variant_ids = {v['variant'].strip(): str(v['variant_id']) for v in feat['variants'].values()}
for it in items:
    assert it['value'] in variant_ids, f"нет значения «{it['value']}» у характеристики {args.feature}: {list(variant_ids)}"

print(f'Старый товар {old_id}: «{name}» | slug {slug} | upc «{upc}» | картинок {1 + len(extra_imgs)} | описание {len(desc)} симв.')
print('Старый URL:', old_url)
for it in items:
    print(f"  RO {it['ro']} {it['value']} {it['price']} ₽ гарантия «{it['warranty']}»")
if args.dry_run:
    sys.exit(0)

# 4-5. Создание (сразу в категории, включёнными)
ids = []
for n, it in enumerate(items):
    features = {str(args.feature): variant_ids[it['value']]}
    if it['warranty']:
        features['4'] = it['warranty']
    if upc:
        features['5'] = upc
    body = dict(product=name if n == 0 else f"{name} | {it['value']}", price=it['price'], product_code=f"RO-{it['ro']}",
                status='A', category_ids=[args.cat], main_category=args.cat, company_id=1,
                page_title=meta_title, meta_description=meta_desc, full_description=desc, product_features=features,
                main_pair={'detailed': {'image_path': 'https://irepair.ru/image/' + main_img, 'alt': name}})
    if extra_imgs:
        body['image_pairs'] = [{'detailed': {'image_path': 'https://irepair.ru/image/' + x, 'alt': name}} for x in extra_imgs]
    if n == 0:
        body['seo_name'] = slug.replace('_', '-')
    ids.append(cs('POST', 'products', body)['product_id'])
    print('создан товар', ids[-1])

# 6. Группа вариаций + имена вариантов
if len(ids) > 1:
    code = f"{re.sub(r'[^a-z0-9]+', '-', slug.replace('_', '-'))}-{args.cat}"
    g = cs('POST', 'product_variations_groups', {'product_ids': ids, 'code': code,
                                                   'features': [{'feature_id': args.feature, 'purpose': 'group_variation_catalog_item'}]})
    print('группа', g['group']['id'], code)
    for pid, it in zip(ids[1:], items[1:]):
        cs('PUT', f'products/{pid}', {'product': f"{name} | {it['value']}"})

# 7. Редиректы: удалить авто-редирект, созданный при создании главного товара; добавить 301 со старого адреса
main = ids[0]
auto = sql_new(f"select redirect_id, src from cscart_seo_redirects where type='p' and object_id in ({','.join(map(str, ids))})")
for line in filter(None, auto.split('\n')):
    rid, src = line.split('\t')
    sql_new(f'delete from cscart_seo_redirects where redirect_id={rid}')
    print('удалён авто-редирект', rid, src)
src = re.sub(r'^https?://[^/]+', '', old_url).rstrip('/') if old_url else ''
if src:
    # если новый адрес товара совпадает со старым — редирект не нужен
    if head('https://dev.irepair.ru' + src + '/')[0] == 200:
        print('старый адрес совпадает с новым — редирект не нужен:', src + '/')
        src = ''
if src:
    sql_new("insert into cscart_seo_redirects (src,dest,type,object_id,company_id,lang_code) "
            f"values ('{src}','','p',{main},1,'ru')")
# 7a. Картинки: обрезать белые/прозрачные поля по контуру объекта (crop_images.py)
print('обрезка картинок:')
crop_products(ids)
_run(NEW_SSH + ['rm -rf /var/www/www-root/data/www/dev.irepair.ru/var/cache/registry/block_content_*'])

# 8. Проверка
for pid in ids:
    p = cs('GET', f'products/{pid}')
    f = p.get('product_features', {})
    print(f"{pid} | {p['product']} | {p['price']} | {p['product_code']} | {p['status']} | seo {p.get('seo_name')} | parent {p.get('parent_product_id')} "
          f"| cat {p.get('category_ids')} | desc same {p.get('full_description') == desc} | img {bool(p.get('main_pair'))} "
          f"| f{args.feature} {f.get(str(args.feature), {}).get('variant')} | f4 {f.get('4', {}).get('value')} | f5 {f.get('5', {}).get('value')}")
if src:
    print('старый URL →', *head('https://dev.irepair.ru' + src + '/'))
