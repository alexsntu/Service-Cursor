#!/bin/bash
# iRepair: учебное восстановление — поднять из последней копии на Яндекс Диске РАБОТАЮЩУЮ копию сайта рядом с основным.
# На сервере: /root/irepair-restore-drill.sh up | down
#   up   — скачать последнюю копию, развернуть файлы в отдельную папку и базу в отдельную базу,
#          поднять под временным именем restore.dev.irepair.ru (в DNS его нет — открывается только с подстановкой адреса сервера);
#   down — убрать всё за собой (папку, базу, настройку nginx).
# Основной сайт, его база и настройки не затрагиваются. Копия закрыта от индексации.
set -u
MODE=${1:-}
NAME=restore.dev.irepair.ru
DIR=/var/www/www-root/data/www/restore-test
DB=irepair_restore
CONF=/etc/nginx/conf.d/irepair-restore-test.conf
TMP=/root/restore-drill

down() {
    rm -f "$CONF"
    nginx -t >/dev/null 2>&1 && nginx -s reload
    mysql -e "DROP DATABASE IF EXISTS $DB"
    rm -rf "$DIR" "$TMP"
    echo "убрано: папка, база $DB, настройка nginx"
}

if [ "$MODE" = "down" ]; then down; exit 0; fi
[ "$MODE" = "up" ] || { echo "использование: $0 up|down"; exit 1; }

set -e
rm -rf "$TMP" "$DIR"; mkdir -p "$TMP/dl" "$TMP/out"
T0=$(date +%s)
F=$(rclone lsf yadisk:iRepair-backup/daily/ | sort | tail -1)
echo "1. копия с Диска: $F"
rclone copy "yadisk:iRepair-backup/daily/$F" "$TMP/dl/"
gpg --batch --pinentry-mode loopback --passphrase-file /root/.irepair-backup.pass -d "$TMP/dl/$F" 2>/dev/null | tar xzf - -C "$TMP/out"

echo "2. файлы → $DIR"
mv "$TMP/out/site" "$DIR"
mkdir -p "$DIR/var/cache" "$DIR/images/thumbnails"

echo "3. база → $DB"
mysql -e "DROP DATABASE IF EXISTS $DB; CREATE DATABASE $DB CHARACTER SET utf8mb3; GRANT ALL ON $DB.* TO 'irepair_cscart'@'localhost'"
gunzip -c "$TMP/out/db.sql.gz" | mysql "$DB"
mysql "$DB" -e "UPDATE cscart_storefronts SET url = '$NAME'"

echo "4. настройки копии: своя база и своё имя (ключи и пароли те же, что в архиве)"
sed -i -E "s/(\\\$config\['db_name'\] = ')[^']*'/\1$DB'/; s/(\\\$config\['http_host'\] = ')[^']*'/\1$NAME'/; s/(\\\$config\['https_host'\] = ')[^']*'/\1$NAME'/" "$DIR/config.local.php"
sed -i -E "s/('name' => ')irepair_cscart'/\1$DB'/" "$DIR/ajax/lk/config.php"
grep -c "$DB" "$DIR/config.local.php" "$DIR/ajax/lk/config.php" | tr '\n' ' '; echo
chown -R www-root:www-root "$DIR"

echo "5. nginx: временное имя $NAME"
cat > "$CONF" <<EOF
# iRepair: ВРЕМЕННАЯ настройка учебного восстановления из резервной копии. Убирается командой irepair-restore-drill.sh down
server {
	listen 188.120.249.151:443 ssl;
	http2 on;
	server_name $NAME;
	ssl_certificate "/var/www/httpd-cert/www-root/dev.irepair.ru_le1.crtca";
	ssl_certificate_key "/var/www/httpd-cert/www-root/dev.irepair.ru_le1.key";
	add_header X-Robots-Tag "noindex, nofollow" always;
	root $DIR;
	index index.php index.html;
	location / {
		try_files \$uri \$uri/ /index.php?\$args;
		location ~ [^/]\\.ph(p\\d*|tml)\$ {
			try_files /does_not_exists @php;
		}
	}
	location @php {
		fastcgi_index index.php;
		fastcgi_pass unix:/var/www/php-fpm/1.sock;
		fastcgi_split_path_info ^((?U).+\\.ph(?:p\\d*|tml))(/?.+)\$;
		try_files \$uri =404;
		include fastcgi_params;
	}
}
EOF
if nginx -t 2>&1 | grep -q "test is successful"; then nginx -s reload; else nginx -t 2>&1 | tail -3; rm -f "$CONF"; echo "nginx: настройка не принята — убрана"; exit 1; fi

rm -rf "$TMP"
echo "готово за $(( $(date +%s) - T0 )) с: копия сайта поднята как https://$NAME (адрес сервера подставляется вручную)"
echo DRILL_UP_DONE
