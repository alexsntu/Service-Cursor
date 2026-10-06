#!/bin/bash
# iRepair, новый сервер: HTTP/2, OPcache, пул PHP-FPM, буфер MySQL. Каждое изменение — с проверкой конфигурации и резервной копией.
set -u
TS=20261006
echo "== 1. HTTP/2"
F=/etc/nginx/vhosts-resources/dev.irepair.ru/http2.conf
cat > "$F" <<'EOF'
# iRepair: HTTP/2 для сайта (в ISPmanager отдельной настройки нет; файл в этой папке панель не перезаписывает).
# При переезде на боевой домен перенести этот файл в папку нового домена.
http2 on;
EOF
if nginx -t 2>&1 | grep -q "test is successful"; then nginx -s reload && echo "nginx перезагружен"; else nginx -t 2>&1 | tail -3; rm -f "$F"; echo "HTTP/2 НЕ включён — файл убран"; fi

echo "== 2. OPcache"
O=/etc/php/8.3/fpm/conf.d/99-irepair-opcache.ini
cat > "$O" <<'EOF'
; iRepair: в CS-Cart почти 10 000 php-файлов — стандартного предела OPcache (10 000 файлов, 128 МБ) впритык
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=20000
EOF

echo "== 3. пул PHP-FPM сайта"
P=/etc/php/8.3/fpm/pool.d/pool.d/dev.irepair.ru.conf
cp -n "$P" "/root/dev.irepair.ru.pool.conf.bak_$TS"
sed -i -E 's/^pm = ondemand/pm = dynamic/; s/^pm\.max_children = .*/pm.max_children = 20/' "$P"
grep -q '^pm.start_servers' "$P" || sed -i '/^pm.max_children/a pm.start_servers = 4\npm.min_spare_servers = 2\npm.max_spare_servers = 6' "$P"
if php-fpm8.3 -t 2>&1 | grep -q "test is successful"; then systemctl reload php8.3-fpm && echo "php-fpm перезагружен"; else php-fpm8.3 -t 2>&1 | tail -3; cp "/root/dev.irepair.ru.pool.conf.bak_$TS" "$P"; rm -f "$O"; echo "PHP-FPM: настройки ОТКАЧЕНЫ"; fi
grep -E "^pm" "$P" | tr '\n' ' '; echo

echo "== 4. буфер MySQL"
C=/etc/mysql/mysql.conf.d/zz-irepair.cnf
cat > "$C" <<'EOF'
# iRepair: буфер InnoDB (стандартные 128 МБ малы для базы CS-Cart; на сервере 8 ГБ памяти)
[mysqld]
innodb_buffer_pool_size = 2G
EOF
mysql --defaults-extra-file=/root/.my.cscart.cnf -e "SET GLOBAL innodb_buffer_pool_size = 2147483648" 2>&1 || echo "онлайн-изменение не прошло (нужны права администратора MySQL) — значение применится после перезапуска MySQL"
sleep 3
mysql --defaults-extra-file=/root/.my.cscart.cnf -N -e "select concat('буфер сейчас, МБ: ', round(@@innodb_buffer_pool_size/1048576))"

echo "== проверка"
sleep 2
systemctl is-active nginx php8.3-fpm mysql | tr '\n' ' '; echo
php-fpm8.3 -i 2>/dev/null | grep -E "^opcache\.(memory_consumption|max_accelerated_files|interned_strings_buffer) " | tr '\n' ' '; echo
for n in 1 2 3 4 5 6; do curl -s -o /dev/null -k --resolve dev.irepair.ru:443:188.120.249.151 -w "%{http_code}/%{http_version}/%{time_starttransfer} " https://dev.irepair.ru/catalog/remont-iphone/; done; echo
echo DONE
