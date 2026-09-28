"""Перенос статей блога со старого сайта (OpenCart, oc_article) в блог CS-Cart (страницы page_type=B).

  python3 import_blog.py [--dry-run] <old article_id …>

Для каждой статьи:
- текст (oc_article_description.description): убираем встроенный <style> старого формата
  (оформление даёт наш блог — my_changes overrides/addons/blog), <h1> в тексте → <h2>
  (H1 страницы — название статьи), картинки из текста копируем на dev в /images/content/blog/<slug>/
  и ставим относительные ссылки;
- название, title, meta description, meta keywords, дата публикации (date_added), адрес = старый slug
  (адрес статьи тот же, что на старом сайте: /blog/<slug>/);
- главное фото (oc_article.image) → картинка блога CS-Cart (object_type=blog, тип M): в списке /blog/ видно,
  в самой статье не показываем.
Статью с уже существующим адресом пропускаем.

Доступы — переменные окружения (в репозиторий не кладём): CSCART_AUTH="admin@irepair.ru:<api key>",
SSHPASS=<пароль старого сервера>.
"""
import argparse
import base64
import html
import io
import json
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'product-import'))
from crop_images import _run  # noqa: E402  (SSH/scp с повторами)

OLD_SSH = 'www-root@31.31.207.64'
NEW = ['ssh', '-n', '-o', 'ConnectTimeout=20', '-i', os.path.expanduser('~/.ssh/irepair_firstvds'), 'root@188.120.249.151']
SCP = ['scp', '-q', '-o', 'ConnectTimeout=20', '-i', os.path.expanduser('~/.ssh/irepair_firstvds')]
HOST = 'root@188.120.249.151'
ROOT = '/var/www/www-root/data/www/dev.irepair.ru'
API = 'https://dev.irepair.ru/api.php?_d='
BLOG_ROOT_PAGE = 39  # страница «Блог» (/blog/)

ap = argparse.ArgumentParser()
ap.add_argument('--dry-run', action='store_true')
ap.add_argument('ids', nargs='+', type=int)
args = ap.parse_args()
AUTH = 'Basic ' + base64.b64encode(os.environ['CSCART_AUTH'].encode()).decode()


def cs(method, path, body=None):
    req = urllib.request.Request(API + path, method=method, data=json.dumps(body).encode() if body is not None else None,
                                 headers={'Authorization': AUTH, 'Content-Type': 'application/json'})
    return json.loads(urllib.request.urlopen(req, timeout=180).read() or b'{}')


def sql(q):
    return _run(NEW + ['mysql --defaults-extra-file=/root/.my.cscart.cnf irepair_cscart -N -e ' + shlex.quote(q)],
                capture_output=True, text=True).stdout


def unesc(s):
    return s.replace('\\\\', '\x00').replace('\\n', '\n').replace('\\t', '\t').replace('\\r', '\r').replace('\x00', '\\')


def fetch(url):
    return urllib.request.urlopen(urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'}), timeout=120).read()


def head(url):
    class NR(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *a, **k):
            return None
    try:
        r = urllib.request.build_opener(NR).open(urllib.request.Request(url, method='HEAD'), timeout=60)
        return r.status
    except urllib.error.HTTPError as e:
        return e.code


# 1. старые статьи (только чтение)
ids = ','.join(map(str, args.ids))
q = ('select a.article_id, a.image, unix_timestamp(a.date_added) ts, ad.name, ad.meta_title, ad.meta_description, '
     'ad.meta_keyword, ad.description, (select keyword from oc_seo_url where query=concat("article_id=",a.article_id) limit 1) kw '
     f'from oc_article a join oc_article_description ad on ad.article_id=a.article_id and ad.language_id=1 where a.article_id in ({ids})')
remote = ('cd ~/www/irepair.ru && P=$(php -r "include \\"config.php\\"; echo DB_PASSWORD;") && '
          f"mysql -uocstore -p\"$P\" ocstore --batch -e '{q}' 2>/dev/null")
out = _run(['sshpass', '-e', 'ssh', '-o', 'ConnectTimeout=20', OLD_SSH, remote], capture_output=True).stdout.decode('utf-8')
lines = out.split('\n')
hdr = lines[0].split('\t')
arts = [dict(zip(hdr, [unesc(x) for x in l.split('\t')])) for l in lines[1:] if l.strip()]

existing = set(sql("select name from cscart_seo_names where type='a'").split())

for a in arts:
    slug = a['kw']
    name = html.unescape(a['name']).strip()
    print(f"\n== {a['article_id']} «{name}» → /blog/{slug}/")
    if slug in existing:
        print('   адрес уже есть на новом сайте — пропускаем')
        continue
    desc = html.unescape(a['description'])
    desc = re.sub(r'<style\b.*?</style>', '', desc, flags=re.S | re.I)          # оформление даёт наш блог
    desc = re.sub(r'<h1(\b[^>]*)>(.*?)</h1>', r'<h2\1>\2</h2>', desc, flags=re.S | re.I)  # H1 страницы — название
    imgs = re.findall(r'<img[^>]+src="([^"]+)"', desc)
    assert not any(ord(ch) > 0xFFFF for ch in desc + name + a['meta_description']), 'эмодзи (4 байта) — CS-Cart их не сохранит'
    print(f"   текст {len(desc)} симв., картинок в тексте {len(imgs)}, главное фото: {a['image'] or '—'}, дата {time.strftime('%Y-%m-%d', time.localtime(int(a['ts'])))}")
    if args.dry_run:
        continue

    # картинки из текста → /images/content/blog/<slug>/
    with tempfile.TemporaryDirectory() as tmp:
        if imgs:
            _run(NEW + [f'mkdir -p {ROOT}/images/content/blog/{slug}'])
        for src in imgs:
            url = src if src.startswith('http') else 'https://irepair.ru' + src
            fn = os.path.basename(urllib.parse.urlparse(url).path)
            local = os.path.join(tmp, fn)
            open(local, 'wb').write(fetch(url))
            _run(SCP + [local, f'{HOST}:{ROOT}/images/content/blog/{slug}/{fn}'])
            desc = desc.replace(f'src="{src}"', f'src="/images/content/blog/{slug}/{fn}"')
        if imgs:
            _run(NEW + [f'chown -R www-root:www-root {ROOT}/images/content/blog/{slug}'])

        # 2. статья в CS-Cart
        page_id = cs('POST', 'pages', {
            'page': name, 'page_type': 'B', 'parent_id': BLOG_ROOT_PAGE, 'status': 'A', 'company_id': 1,
            'description': desc, 'page_title': html.unescape(a['meta_title']).strip(),
            'meta_description': html.unescape(a['meta_description']).strip(), 'meta_keywords': html.unescape(a['meta_keyword']).strip(),
            'seo_name': slug, 'timestamp': int(a['ts']),
        })['page_id']
        print('   создана статья', page_id)

        # 3. главное фото → images/blog/<dir>/ + cscart_images + cscart_images_links (object_type=blog, M)
        if a['image']:
            data = fetch('https://irepair.ru/image/' + urllib.parse.quote(a['image']))
            fn = re.sub(r'[^A-Za-z0-9._-]+', '-', os.path.basename(a['image'])) or 'image.jpg'
            fn = f'{slug[:80]}{os.path.splitext(fn)[1].lower() or ".jpg"}'
            local = os.path.join(tmp, fn)
            open(local, 'wb').write(data)
            w, h = Image.open(io.BytesIO(data)).size
            image_id = int(sql(f"insert into cscart_images (image_path, image_x, image_y) values ('{fn}', {w}, {h}); select last_insert_id();").split()[-1])
            d = f'{ROOT}/images/blog/{image_id // 1000}'
            _run(NEW + [f'mkdir -p {d}'])
            _run(SCP + [local, f'{HOST}:{d}/{fn}'])
            _run(NEW + [f'chown -R www-root:www-root {d}'])
            sql(f"insert into cscart_images_links (object_id, object_type, image_id, detailed_id, type, position) values ({page_id}, 'blog', {image_id}, 0, 'M', 0)")
            print(f'   главное фото {fn} {w}×{h} (image {image_id})')

    code = head(f'https://dev.irepair.ru/blog/{slug}/')
    print(f'   новый адрес /blog/{slug}/ → {code}')

_run(NEW + [f'rm -rf {ROOT}/var/cache/registry/* {ROOT}/var/cache/templates/*'])
