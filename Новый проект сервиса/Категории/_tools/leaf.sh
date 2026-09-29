#!/bin/bash
# leaf.sh — одна конечная категория целиком: обрезка и загрузка картинки баннера (md5-проверка), конфиг, баннер (gen_series.py), пробный и настоящий импорт услуг (import_service.py), коммит.
# Watch: slug apple-watch-… → папка Категории/AppleWatch, фичи 10 (тип) / 11 (размер корпуса).
# leaf.sh <slug> <title-html> <service> <alt> <cat> <feature> <model-feature|-> <image-path|copy:<файл.webp во временной папке>> <RO ids…>
# DRY_ONLY=1 — только баннер и пробный импорт. Ключи берутся из памяти Claude и credentials.local.md (в репозиторий не попадают).
set -e
S="${LEAF_TMP:-/tmp/irepair-leaf}"; mkdir -p "$S"
SLUG=$1; TITLE=$2; SERVICE=$3; ALT=$4; CAT=$5; FEAT=$6; MFEAT=$7; IMG=$8; shift 8
DEV=${SLUG%%-*}   # ipad / macbook / iphone
T="/Users/a0000/Документы/Cursor/Service-Cursor/Новый проект сервиса/Категории/_tools"
cd "$T"
W=$S/$SLUG-model.webp
if [[ "$IMG" == copy:* ]]; then cp "$S/${IMG#copy:}" "$W"; else
python3 - "$IMG" "$W" <<'EOF'
import sys
from PIL import Image, ImageChops
im=Image.open(sys.argv[1]); flat=Image.new('RGB',im.size,(255,255,255))
if im.mode in ('RGBA','LA','P'):
    r=im.convert('RGBA'); flat.paste(r,mask=r.split()[3])
else: flat=im.convert('RGB')
b=ImageChops.difference(flat,Image.new('RGB',im.size,(255,255,255))).convert('L').point(lambda p:255 if p>12 else 0).getbbox()
c=flat.crop(b); c.save(sys.argv[2],'WEBP',quality=85); c.save(sys.argv[2]+'.png'); print('crop',im.size,'->',c.size)
EOF
fi
python3 - "$SLUG" "$TITLE" "$SERVICE" "$ALT" <<'EOF'
import json,sys
slug,title,service,alt=sys.argv[1:5]
dev=slug.split('-')[0]
base={'ipad':'model-ipad-2.json','macbook':'model-macbook-pro-13.json','apple':'model-ipad-2.json'}.get(dev,'model-iphone-16.json')
c=json.load(open(base))
if slug.startswith('apple-watch'):  # Watch: как iPad (моб. название → картинка → текст → кнопка), своя папка
    c.update(dir='../AppleWatch', device='Apple Watch')
c.update(slug='remont-'+slug,title=title,service=service,image=f'/images/content/catalog/{slug}-model.webp',image_alt=alt)
json.dump(c,open(f'model-{slug}.json','w'),ensure_ascii=False,indent=2); open(f'model-{slug}.json','a').write('\n')
EOF
D=/var/www/www-root/data/www/dev.irepair.ru/images/content/catalog
for i in 1 2 3 4 5 6 7 8; do scp -q -i ~/.ssh/irepair_firstvds "$W" root@188.120.249.151:$D/ && break; sleep 15; done
for i in 1 2 3 4 5 6 7 8; do R=$(ssh -n -i ~/.ssh/irepair_firstvds root@188.120.249.151 "chown www-root: $D/$SLUG-model.webp && md5sum $D/$SLUG-model.webp | cut -d' ' -f1") && break; sleep 15; done
[ "$R" == "$(md5 -q "$W")" ] && echo "img uploaded OK" || { echo "IMG MD5 MISMATCH"; exit 1; }
python3 gen_series.py --config model-$SLUG.json
M=/Users/a0000/.claude/projects/-Users-a0000-----------Cursor-Service-Cursor/memory/reference_new_site_credentials.md
export RO_KEY=$(sed -n 37p $M | sed -E 's/.*`([^`]+)`.*/\1/'); CK=$(sed -n 42p $M | sed -E 's/.*API key `([^`]+)`.*/\1/'); export CSCART_AUTH="admin@irepair.ru:$CK"; export SSHPASS=$(sed -n 6p /Users/a0000/Документы/Cursor/Service-Cursor/credentials.local.md | sed -E 's/.*`([^`]+)`.*/\1/')
cd ../../backend/product-import
MF=""; [ "$MFEAT" != "-" ] && MF="--model-feature $MFEAT"
python3 import_service.py --cat $CAT --feature $FEAT $MF --dry-run "$@" 2>&1 | tail -15
[ "${DRY_ONLY:-}" == 1 ] && exit 0
python3 import_service.py --cat $CAT --feature $FEAT $MF "$@" 2>&1 | grep -v "^  Ремонт_\|^   товар\|^  RO\|новое значение\|^Старый\|^!!! RO"
cd /Users/a0000/Документы/Cursor/Service-Cursor
DIRN=$(python3 -c "import json;print(json.load(open('Новый проект сервиса/Категории/_tools/model-$SLUG.json'))['dir'].split('/')[-1])")
git add "Новый проект сервиса/Категории/$DIRN/remont-$SLUG.html" "Новый проект сервиса/Категории/_tools/model-$SLUG.json" && git commit -q -m "$ALT: баннер

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" && git log --oneline -1
