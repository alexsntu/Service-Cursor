"""Фото модели — всем услугам этой модели (владелец 2026-10-01: «залей эти фото ко всем услугам данной модели»).

  python3 set_model_photo.py <фото> <slug модели> <id категории модели> [--dry-run]
  напр.: python3 set_model_photo.py ~/Downloads/iphone-17-pro-max-min.jpg iphone-17-pro-max 49

Фото обрезается по контуру (белые/прозрачные поля, как crop_images.py), кладётся на сервер в
/images/content/catalog/<slug>-service.<ext> и ставится ГЛАВНОЙ картинкой всем товарам, у которых эта категория —
главная (общие услуги «для всех» с главной категорией «Ремонт iPhone» не трогаем). Старые картинки убираются:
главная заменяется (API PUT main_pair заменяет пару), дополнительные удаляются.
Доступы — переменная окружения CSCART_AUTH (как у import_service.py).
"""
import argparse
import base64
import json
import os
import subprocess
import sys
import tempfile
import urllib.request

from PIL import Image

from crop_images import _bbox, _run, _save, _sql

ap = argparse.ArgumentParser()
ap.add_argument('photo')
ap.add_argument('slug')
ap.add_argument('cat', type=int)
ap.add_argument('--dry-run', action='store_true')
args = ap.parse_args()

NEW_SSH = ['ssh', '-o', 'ConnectTimeout=20', '-i', os.path.expanduser('~/.ssh/irepair_firstvds'), 'root@188.120.249.151']
SCP = ['scp', '-q', '-o', 'ConnectTimeout=20', '-i', os.path.expanduser('~/.ssh/irepair_firstvds')]
ROOT = '/var/www/www-root/data/www/dev.irepair.ru'
AUTH = base64.b64encode(os.environ['CSCART_AUTH'].encode()).decode()


def cs(method, path, data=None):
    req = urllib.request.Request('https://dev.irepair.ru/api.php?_d=' + path, method=method,
                                 data=json.dumps(data).encode() if data is not None else None,
                                 headers={'Authorization': 'Basic ' + AUTH, 'Content-Type': 'application/json'})
    return json.loads(urllib.request.urlopen(req, timeout=90).read())


# 1. Фото: обрезка по контуру
im = Image.open(os.path.expanduser(args.photo))
fmt = im.format or 'JPEG'
ext = {'JPEG': 'jpg', 'PNG': 'png', 'WEBP': 'webp'}.get(fmt, 'jpg')
b = _bbox(im)
if b:
    im = im.crop(b)
print(f'фото {os.path.basename(args.photo)}: обрезано до {im.size[0]}×{im.size[1]}' + ('  ⚠️ меньше 500 по стороне' if min(im.size) < 500 else ''))
name = f'{args.slug}-service.{ext}'
url = f'https://dev.irepair.ru/images/content/catalog/{name}'

# 2. Товары модели (эта категория — главная)
rows = _sql(f"select pc.product_id, d.product from cscart_products_categories pc join cscart_product_descriptions d "
            f"on d.product_id = pc.product_id and d.lang_code = 'ru' where pc.category_id = {args.cat} and pc.link_type = 'M' "
            f"order by pc.position, pc.product_id")
products = [line.split('\t', 1) for line in rows.split('\n') if line.strip()]
print(f'категория {args.cat}: товаров {len(products)}')
for pid, pname in products:
    print(f'  {pid} {pname}')
if args.dry_run:
    sys.exit(0)

with tempfile.TemporaryDirectory() as tmp:
    local = os.path.join(tmp, name)
    _save(im, local, fmt)
    _run(NEW_SSH + [f'mkdir -p {ROOT}/images/content/catalog'])
    _run(SCP + [local, f'root@188.120.249.151:{ROOT}/images/content/catalog/{name}'])
    _run(NEW_SSH + [f'chown www-root: {ROOT}/images/content/catalog/{name}'])

# 3. Главная картинка — новое фото, дополнительные — удалить
for pid, pname in products:
    cs('PUT', f'products/{pid}', {'main_pair': {'detailed': {'image_path': url, 'alt': pname}}})
extra = _sql(f"select pair_id from cscart_images_links where object_type = 'product' and type = 'A' "
             f"and object_id in ({','.join(p for p, _ in products)})")
extra_ids = [x for x in extra.split('\n') if x.strip()]
if extra_ids:
    _sql(f"delete from cscart_images_links where pair_id in ({','.join(extra_ids)})")
    print('удалены дополнительные картинки:', len(extra_ids))
_run(NEW_SSH + [f'rm -rf {ROOT}/var/cache/registry/block_content_* {ROOT}/var/cache/registry'])

# 4. Проверка
for pid, pname in products:
    p = cs('GET', f'products/{pid}')
    img = (p.get('main_pair') or {}).get('detailed', {}).get('image_path', '')
    print(f"{pid} | {'OK' if args.slug in img else 'НЕ ЗАМЕНЕНО ' + img}")
