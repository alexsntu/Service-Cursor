"""Генератор страниц серий (корневых категорий) по эталону «Серия iPhone 17».

Создаёт два файла рядом с эталоном:
  <slug>.html      — код для блока 202 «Код категории» (баннер + выбор модели)
  <slug>-seo.html  — небольшой SEO-текст для поля «Описание» категории

Пример:
  python3 gen_series.py --config series15.json

Конфиг (JSON):
{
  "dir": "../iPhone",                      # папка с эталоном и результатом
  "template": "seriya-iphone-17",          # эталон (без .html)
  "slug": "seriya-iphone-15",
  "series": "15",                          # «iPhone 15 серии»
  "device": "iPhone",
  "title_models": "15, 15&nbsp;Plus, 15&nbsp;Pro и&nbsp;15&nbsp;Pro&nbsp;Max",
  "intro_models": "iPhone&nbsp;15, 15&nbsp;Plus, 15&nbsp;Pro и 15&nbsp;Pro&nbsp;Max",
  "image": "/images/content/catalog/iphone-15-series.webp",
  "image_alt": "iPhone 15 Pro и iPhone 15 Pro Max",
  "category_url": "/catalog/remont-iphone/iphone-15/",
  "models": [["iPhone 15", "/catalog/..."], ...],
  "top_repairs": ["аккумулятор", "стекло", "заднее стекло", "дисплей"],   # по Wordstat
  "offers": ["Замена аккумулятора iPhone 15", ...],
  "faq": [["вопрос", "ответ"], ...]                                         # 3 штуки
}
"""
import argparse
import json
import os
import re

p = argparse.ArgumentParser()
p.add_argument('--config', required=True)
cfg = json.load(open(p.parse_args().config, encoding='utf-8'))
base = os.path.join(os.path.dirname(os.path.abspath(p.parse_args().config)), cfg['dir'])
tpl_block = open(os.path.join(base, cfg['template'] + '.html'), encoding='utf-8').read()
tpl_seo = open(os.path.join(base, cfg['template'] + '-seo.html'), encoding='utf-8').read()
dev, ser = cfg['device'], cfg['series']
# необязательные поля (для не-iPhone разделов, напр. MacBook Pro):
sp = cfg.get('series_phrase', f'{dev} {ser} серии')          # «iPhone 15 серии» / «MacBook Pro»
sub = cfg.get('sub', f'Все модели {ser} серии.')             # первая фраза подписи в баннере
pick = cfg.get('pick_title', f'Выберите модель {dev}, чтобы узнать стоимость ремонта')
faq_title = cfg.get('faq_title', f'Частые вопросы о ремонте {dev} {ser}')

# ---------- блок 202 ----------
s = tpl_block
s = re.sub(r'(<div class="irepair-page-series__banner-title">).*?(</div>)',
           lambda m: f'{m.group(1)}Ремонт {dev} {cfg["title_models"]}{m.group(2)}', s, count=1)
s = re.sub(r'Все модели \S+ серии\.', lambda m_: sub, s, count=1)
s = re.sub(r'data-service="Ремонт [^"]*"', f'data-service="Ремонт {sp}"', s, count=1)
s = re.sub(r'(<h2 class="irepair-page-series__section-title">).*?(</h2>)', lambda m_: m_.group(1) + pick + m_.group(2), s, count=1)
s = re.sub(r'(class="irepair-page-series__banner-img" role="img" aria-label=")[^"]*"', lambda m: m.group(1) + cfg['image_alt'] + '"', s, count=1)
s = re.sub(r"url\('/images/content/catalog/[^']+'\)", f"url('{cfg['image']}')", s, count=1)
a = s.index('<div class="irepair-page-series__models">')
b = s.index('</div>', a)
s = (s[:a] + '<div class="irepair-page-series__models">\n'
     + f'      <!-- модели = категории CS-Cart раздела «{sp}» (при изменении категорий обновить) -->\n'
     + ''.join(f'      <a href="{u}">{n}</a>\n' for n, u in cfg['models']) + '    ' + s[b:])

# ---------- SEO ----------
t = tpl_seo
m = re.search(r'<script type="application/ld\+json">\n(.*?)\n</script>', t, re.S)
ld = json.loads(m.group(1))
url = 'https://irepair.ru' + cfg['category_url']
for g in ld['@graph']:
    if g['@type'] == 'LocalBusiness':
        g['hasOfferCatalog'] = {'@type': 'OfferCatalog', 'name': f'Ремонт {sp}',
                                'itemListElement': [{'@type': 'Offer', 'itemOffered': {'@type': 'Service', 'name': n}} for n in cfg['offers']]}
    elif g['@type'] == 'WebPage':
        g.update({'@id': url + '#webpage', 'url': url, 'name': f'Ремонт {sp} в Москве'})
    elif g['@type'] == 'FAQPage':
        g['mainEntity'] = [{'@type': 'Question', 'name': q, 'acceptedAnswer': {'@type': 'Answer', 'text': a_}} for q, a_ in cfg['faq']]
t = t[:m.start(1)] + json.dumps(ld, ensure_ascii=False, indent=2) + t[m.end(1):]
t = re.sub(r'(<h2 class="mm-h2" id="mm-heading-intro">).*?(</h2>)', lambda mm: f'{mm.group(1)}Ремонт {sp} в Москве{mm.group(2)}', t, count=1)
rep = cfg['top_repairs']
rep_txt = ', '.join(rep[:-1]) + ' и ' + rep[-1]
intro = (f'<p class="mm-intro-text">Ремонт {sp} в Москве выполняет сервисный центр iRepair: чиним все модели линейки — '
         f'{cfg["intro_models"]}. Чаще всего меняем {rep_txt}. Диагностика бесплатно, большинство работ — в день обращения '
         f'при наличии запчасти, на ремонт даём гарантию.</p>')
t = re.sub(r'<p class="mm-intro-text">.*?</p>', lambda mm: intro, t, count=1, flags=re.S)
t = re.sub(r'Частые вопросы о ремонте [^<]*', lambda m_: faq_title, t, count=1)
fa = t.index('<div class="mm-faq-list">')
fb = t.index('</div>\n</section>', fa)
t = t[:fa] + '<div class="mm-faq-list">\n' + ''.join(
    f'<div class="mm-faq-item mm-glass"><h3 class="mm-faq-question">{q}</h3><p class="mm-faq-answer">{a_}</p></div>\n'
    for q, a_ in cfg['faq']) + t[fb:]
ra = t.index('<div class="mm-related" role="list">')
rb = t.index('</div>', ra)
t = t[:ra] + '<div class="mm-related" role="list">\n' + ''.join(
    f'<a href="{u}" class="mm-related-link" role="listitem">{n}</a>\n' for n, u in cfg['models']) + t[rb:]

open(os.path.join(base, cfg['slug'] + '.html'), 'w', encoding='utf-8').write(s)
open(os.path.join(base, cfg['slug'] + '-seo.html'), 'w', encoding='utf-8').write(t)
vis = re.sub(r'<script.*?</script>|<style>.*?</style>', '', t, flags=re.S)
print('written:', cfg['slug'], '| seo visible chars:', len(re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', ' ', vis)).strip()),
      '| smarty-unsafe braces:', len(re.findall(r'\{(?=\S)', s + t)))
