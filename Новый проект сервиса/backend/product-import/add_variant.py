"""Добавить вариант в готовую услугу (группу вариаций) — когда строки таблицы ещё нет в RemOnline
(владелец 2026-10-04: «сделаем для этой опции свой код, а потом скажу код в RemOnline»).

  python3 add_variant.py <id главного товара> <id хар-ки модели> "<значение модели>" <позиция значения> <код> <цена> "<гарантия>"

Вариант копирует главный товар (описание, мета, фото, категория, тип запчасти, время ремонта), отличается моделью,
ценой, кодом и гарантией. Значение модели создаётся, если его ещё нет. Доступы — CSCART_AUTH.
"""
import base64, json, os, subprocess, sys, urllib.request

main, mfid, label, pos, code, price, warranty = int(sys.argv[1]), sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5], int(sys.argv[6]), sys.argv[7]
AUTH = base64.b64encode(os.environ['CSCART_AUTH'].encode()).decode()


def cs(method, path, data=None):
    req = urllib.request.Request('https://dev.irepair.ru/api.php?_d=' + path, method=method,
                                 data=json.dumps(data).encode() if data is not None else None,
                                 headers={'Authorization': 'Basic ' + AUTH, 'Content-Type': 'application/json'})
    return json.loads(urllib.request.urlopen(req, timeout=90).read())


def sql(q):
    return subprocess.run(['ssh', '-i', os.path.expanduser('~/.ssh/irepair_firstvds'), 'root@188.120.249.151',
                           'mysql --defaults-extra-file=/root/.my.cscart.cnf irepair_cscart -N -e ' + json.dumps(q)],
                          capture_output=True, text=True, check=True).stdout


m = cs('GET', f'products/{main}')
gid = m['variation_group_id']
feat = cs('GET', f'features/{mfid}')
ids = {v['variant'].strip(): str(v['variant_id']) for v in feat['variants'].values()}
if label not in ids:
    # существующие значения передаём с id (иначе API их удалит), новое — без id
    keep = [{'variant_id': v['variant_id'], 'variant': v['variant'], 'position': v.get('position', 0)} for v in feat['variants'].values()]
    cs('PUT', f'features/{mfid}', {'variants': keep + [{'variant': label, 'position': pos}]})
    ids = {v['variant'].strip(): str(v['variant_id']) for v in cs('GET', f'features/{mfid}')['variants'].values()}
    print('новое значение модели:', label, ids[label])
feats = {}
for fid, f in m['product_features'].items():
    if f.get('purpose') == 'group_variation_catalog_item' and fid != mfid:
        feats[fid] = str(f['variant_id'])   # тип запчасти — как у главного
feats.update({mfid: ids[label], '4': warranty})
if m['product_features'].get('5'):
    feats['5'] = m['product_features']['5']['value']
type_name = ' | '.join(f['variant'] for fid, f in m['product_features'].items() if f.get('purpose') == 'group_variation_catalog_item' and fid != mfid)
name = f"{m['product']} | {label}" + (f' | {type_name}' if type_name else '')
body = dict(product=name, price=price, product_code=code, status='A', category_ids=m['category_ids'], main_category=m['main_category'], company_id=1,
            page_title=m.get('page_title'), meta_description=m.get('meta_description'), full_description=m.get('full_description'), product_features=feats,
            **({'main_pair': {'detailed': {'image_path': m['main_pair']['detailed']['image_path'], 'alt': m['product']}}} if m.get('main_pair') else {}))
pid = cs('POST', f'product_variations_groups/{gid}/product_variations', body)['product_id']
cs('PUT', f'products/{pid}', {'product': name, 'product_features': feats})
position = sql(f"select position from cscart_products_categories where product_id={main} and category_id={m['main_category']}").strip()
sql(f"update cscart_products_categories set position={position} where product_id={pid}")
sql(f"delete from cscart_seo_redirects where type='p' and object_id={pid}")
d = cs('GET', f'products/{pid}')
f = d['product_features']
print(pid, '|', d['product'], '|', d['price'], d['product_code'], '| parent', d.get('parent_product_id'), '| group', d.get('variation_group_id'), '|', f[mfid]['variant'], '|', f['4']['value'], '|', f.get('5', {}).get('value'))
