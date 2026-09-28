"""Обрезка белых (и прозрачных) полей у картинок товаров CS-Cart — прямо на dev-сервере, «на месте».

Для каждого товара берём его картинки (главную и дополнительные) из cscart_images_links,
скачиваем файл из images/detailed, режем по контуру объекта (без отступов), заливаем обратно
под тем же именем, обновляем image_x/image_y и удаляем закэшированные превью (images/thumbnails),
чтобы CS-Cart пересоздал их из обрезанного файла. Если обрезать нечего — файл не трогаем.

  python3 crop_images.py [--dry-run] 13 14 15 …      # отдельно, по id товаров
  from crop_images import crop_products               # из import_service.py после создания товаров

Нужен только SSH-ключ ~/.ssh/irepair_firstvds (Pillow — локально, на сервере его нет).
"""
import argparse
import json
import os
import subprocess
import tempfile
import time

from PIL import Image, ImageChops

SSH = ['ssh', '-n', '-o', 'ConnectTimeout=20', '-i', os.path.expanduser('~/.ssh/irepair_firstvds'), 'root@188.120.249.151']
SCP = ['scp', '-q', '-o', 'ConnectTimeout=20', '-i', os.path.expanduser('~/.ssh/irepair_firstvds')]
HOST = 'root@188.120.249.151'
ROOT = '/var/www/www-root/data/www/dev.irepair.ru/images'
MIN_GAIN = 0.03  # режем, только если убирается больше 3% ширины или высоты


def _run(cmd, **kw):
    """SSH/scp до сервера иногда рвётся («Connection closed») — до 4 попыток."""
    for attempt in range(4):
        try:
            return subprocess.run(cmd, check=True, **kw)
        except subprocess.CalledProcessError:
            if attempt == 3:
                raise
            time.sleep(5)


def _ssh(cmd):
    return _run(SSH + [cmd], capture_output=True, text=True).stdout


def _sql(q):
    return _ssh('mysql --defaults-extra-file=/root/.my.cscart.cnf irepair_cscart -N -e ' + json.dumps(q))


def _bbox(im):
    """Рамка объекта: всё, что не белое (порог 12) и не прозрачное."""
    if im.mode in ('RGBA', 'LA', 'P'):
        rgba = im.convert('RGBA')
        flat = Image.new('RGB', im.size, (255, 255, 255))
        flat.paste(rgba, mask=rgba.split()[3])
    else:
        flat = im.convert('RGB')
    diff = ImageChops.difference(flat, Image.new('RGB', im.size, (255, 255, 255))).convert('L')
    return diff.point(lambda p: 255 if p > 12 else 0).getbbox()


def _save(im, path, fmt):
    if fmt == 'JPEG':
        im.convert('RGB').save(path, 'JPEG', quality=92, optimize=True)
    else:
        im.save(path, fmt)


def crop_products(product_ids, dry_run=False):
    ids = ','.join(str(int(i)) for i in product_ids)
    rows = _sql('select i.image_id, i.image_path from cscart_images_links l '
                'join cscart_images i on i.image_id = l.detailed_id '
                f"where l.object_type = 'product' and l.object_id in ({ids})")
    done = []
    with tempfile.TemporaryDirectory() as tmp:
        for line in filter(None, rows.split('\n')):
            image_id, name = line.split('\t')
            remote = _ssh(f'ls {ROOT}/detailed/*/{json.dumps(name)} 2>/dev/null').strip().split('\n')[0]
            if not remote:
                print('  нет файла', name)
                continue
            local = os.path.join(tmp, name)
            _run(SCP + [f'{HOST}:{remote}', local])
            im = Image.open(local)
            fmt = im.format
            w, h = im.size
            b = _bbox(im)
            if not b or ((w - (b[2] - b[0])) / w < MIN_GAIN and (h - (b[3] - b[1])) / h < MIN_GAIN):
                print(f'  {name}: {w}×{h} — обрезать нечего')
                continue
            c = im.crop(b)
            print(f'  {name}: {w}×{h} → {c.size[0]}×{c.size[1]}' + (' (dry-run)' if dry_run else ''))
            if dry_run:
                continue
            _save(c, local, fmt)
            _run(SCP + [local, f'{HOST}:{remote}'])
            stem = os.path.splitext(name)[0]
            rel = remote[len(ROOT) + 1:]  # detailed/1/<name>
            _ssh(f'chown www-root: {json.dumps(remote)}; '
                 f'find {ROOT}/thumbnails -path {json.dumps("*/" + os.path.dirname(rel) + "/" + stem + ".*")} -delete')
            _sql(f'update cscart_images set image_x={c.size[0]}, image_y={c.size[1]} where image_id={image_id}')
            done.append(name)
    return done


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry-run', action='store_true')
    ap.add_argument('product_ids', nargs='+', type=int)
    a = ap.parse_args()
    crop_products(a.product_ids, a.dry_run)
