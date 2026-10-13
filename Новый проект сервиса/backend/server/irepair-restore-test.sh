#!/bin/bash
# Проверка восстановления: взять последнюю копию из /root/irepair-backup/, расшифровать, развернуть в отдельную папку и во временную базу
set -u
R=/root/restore-test; rm -rf $R; mkdir -p $R/dl $R/out
F=$(ls -1 /root/irepair-backup/irepair-*.tar.gz.gpg | sort | tail -1)
echo "копия: $F"
gpg --batch --pinentry-mode loopback --passphrase-file /root/.irepair-backup.pass -d "$F" 2>/dev/null | tar xzf - -C $R/out || { echo "НЕ РАСПАКОВАЛОСЬ"; exit 1; }
ls $R/out
SITE=/var/www/www-root/data/www/dev.irepair.ru
echo "файлов в копии: $(find $R/out/site -type f | wc -l); на сайте (без кэша и миниатюр): $(find $SITE -type f -not -path "$SITE/var/cache/*" -not -path "$SITE/images/thumbnails/*" | wc -l)"
for f in config.local.php ajax/lk/config.php ajax/lk/api.php app/addons/my_changes/func.php index.php; do cmp -s "$R/out/site/$f" "$SITE/$f" && echo "  совпадает: $f" || echo "  ОТЛИЧАЕТСЯ: $f"; done
echo "картинок товаров в копии: $(find $R/out/site/images/detailed -type f 2>/dev/null | wc -l)"
ls $R/out/server
gunzip -t $R/out/db.sql.gz && echo "дамп базы цел, $(stat -c %s $R/out/db.sql.gz) байт"
if mysql -e "select 1" >/dev/null 2>&1; then
  mysql -e "drop database if exists irepair_restore_test; create database irepair_restore_test"
  gunzip -c $R/out/db.sql.gz | mysql irepair_restore_test && echo "база развёрнута во временную"
  mysql -N -e "select concat('таблиц: ', count(*)) from information_schema.tables where table_schema='irepair_restore_test'; select concat('услуг: ', count(*)) from irepair_restore_test.cscart_products; select concat('клиентов кабинета: ', count(*)) from irepair_restore_test.irepair_lk_clients; select concat('редиректов: ', count(*)) from irepair_restore_test.cscart_seo_redirects"
  mysql --defaults-extra-file=/root/.my.cscart.cnf -N -e "select concat('на сайте — таблиц: ', (select count(*) from information_schema.tables where table_schema='irepair_cscart'), ', услуг: ', (select count(*) from cscart_products), ', редиректов: ', (select count(*) from cscart_seo_redirects))" irepair_cscart
  mysql -e "drop database irepair_restore_test" && echo "временная база удалена"
else echo "нет доступа администратора MySQL — базу во временную не разворачивал"; fi
rm -rf $R; echo RESTORE_DONE
