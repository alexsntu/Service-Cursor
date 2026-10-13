#!/bin/bash
# iRepair: ночная резервная копия нового сайта. На сервере: /root/irepair-backup.sh, запуск по расписанию root.
#
# Каждую ночь — один зашифрованный архив: файлы сайта (без кэша и миниатюр) + дамп базы + настройки сервера.
# Архив остаётся на сервере в /root/irepair-backup/ (только последний) и никуда не отправляется:
# его сам забирает Mac владельца (irepair-backup-pull-mac.sh, раз в час, когда Mac включён) и хранит 3 последних
# в папке backups/ проекта. До 2026-10-13 архив уходил на Яндекс Диск — отключено по решению владельца.
# Архив шифруется (gpg, AES-256): в нём база с данными клиентов и файлы с ключами. Пароль — /root/.irepair-backup.pass
# (копия у владельца; без пароля архив не открыть).
#
# Восстановление:
#   gpg --batch --passphrase-file /root/.irepair-backup.pass -d <файл> | tar xzf - -C /root/restore/
#   внутри: site/ (файлы сайта), db.sql.gz (база), server/ (nginx, php, mysql, расписания)
set -u
export LC_ALL=C

SITE=/var/www/www-root/data/www/dev.irepair.ru
WORK=/root/irepair-backup
PASS=/root/.irepair-backup.pass
LOG=/var/log/irepair-backup.log
DAY=$(date +%F)
NAME="irepair-$DAY.tar.gz.gpg"

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }
fail() { log "ОШИБКА: $*"; echo "ОШИБКА: $*" >&2; exit 1; }

[ -s "$PASS" ] || fail "нет файла с паролем $PASS"
mkdir -p "$WORK/stage/server" || fail "не создать $WORK"
rm -f "$WORK"/irepair-*.tar.gz.gpg "$WORK/stage/db.sql.gz"

log "начало"
# 1. база
mysqldump --defaults-extra-file=/root/.my.cscart.cnf --single-transaction --routines --triggers irepair_cscart 2>>"$LOG" | gzip > "$WORK/stage/db.sql.gz"
[ "${PIPESTATUS[0]}" = "0" ] && [ "$(stat -c %s "$WORK/stage/db.sql.gz")" -gt 1000000 ] || fail "дамп базы не получился"

# 2. настройки сервера (малый объём, но без них сервер долго восстанавливать)
tar czf "$WORK/stage/server/etc.tar.gz" -C / etc/nginx etc/php/8.3/fpm etc/mysql 2>>"$LOG"
crontab -l > "$WORK/stage/server/crontab-root.txt" 2>/dev/null
crontab -u www-root -l > "$WORK/stage/server/crontab-www-root.txt" 2>/dev/null
cp /root/lk-toggle.php /root/irepair-backup.sh "$WORK/stage/server/" 2>/dev/null

# 3. архив: файлы сайта + база + настройки → сразу шифруем
tar czf - \
    --exclude='./var/cache' --exclude='./images/thumbnails' --exclude='./var/irepair-search/cron.log' \
    --transform 's,^\./,site/,' -C "$SITE" . \
    --transform 's,^stage/,,' -C "$WORK" stage/db.sql.gz stage/server 2>>"$LOG" \
  | gpg --batch --yes --pinentry-mode loopback --passphrase-file "$PASS" --symmetric --cipher-algo AES256 -o "$WORK/$NAME" 2>>"$LOG"
SIZE=$(stat -c %s "$WORK/$NAME" 2>/dev/null || echo 0)
[ "$SIZE" -gt 100000000 ] || fail "архив подозрительно мал: $SIZE байт"

log "готово: $NAME, $((SIZE / 1048576)) МБ"
echo "готово: $NAME, $((SIZE / 1048576)) МБ"
