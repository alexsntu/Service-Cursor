#!/bin/bash
# iRepair: забирает ночную резервную копию нового сайта с сервера на этот Mac.
#
# Сервер каждую ночь в 04:15 готовит один зашифрованный архив (/root/irepair-backup.sh) и никуда его не отправляет.
# Этот скрипт запускается на Mac раз в час и при входе в систему (launchd, ru.irepair.backup-pull):
# если на сервере появился архив, которого здесь ещё нет, — скачивает его, сверяет размер и контрольную сумму.
# Хранение: 3 последних архива в папке backups/ проекта (папка в .gitignore — в git не попадает).
# Если свежей копии нет больше двух дней — показывает уведомление (не чаще раза в сутки).
#
# Установка расписания: скопировать ru.irepair.backup-pull.plist в ~/Library/LaunchAgents и выполнить
#   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/ru.irepair.backup-pull.plist
# Ручной запуск: bash irepair-backup-pull-mac.sh
# Архив открывается паролем из credentials.local.md (как — в шапке irepair-backup.sh).
set -u
export LC_ALL=C

DEST="/Users/a0000/Документы/Cursor/Service-Cursor/backups"
KEY=/Users/a0000/.ssh/irepair_firstvds
HOST=root@188.120.249.151
REMOTE_DIR=/root/irepair-backup
KEEP=3
STALE_DAYS=2
LOG="$DEST/pull.log"
LOCK="$DEST/.lock"
SSH_OPTS=(-i "$KEY" -o BatchMode=yes -o ConnectTimeout=20 -o ServerAliveInterval=15 -o ServerAliveCountMax=4)

mkdir -p "$DEST" || exit 1
log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

# один запуск одновременно; зависший замок старше двух часов снимаем
if ! mkdir "$LOCK" 2>/dev/null; then
    [ -n "$(find "$LOCK" -maxdepth 0 -mmin +120 2>/dev/null)" ] || exit 0
    rmdir "$LOCK" 2>/dev/null; mkdir "$LOCK" 2>/dev/null || exit 0
fi
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

# уведомление, если последняя копия здесь старше STALE_DAYS дней
check_stale() {
    local last age stamp="$DEST/.stale-notified"
    last=$(ls -1 "$DEST"/irepair-*.tar.gz.gpg 2>/dev/null | sort | tail -1)
    if [ -n "$last" ]; then
        age=$(( ( $(date +%s) - $(stat -f %m "$last") ) / 86400 ))
        [ "$age" -lt "$STALE_DAYS" ] && { rm -f "$stamp"; return; }
    else
        age="?"
    fi
    [ -n "$(find "$stamp" -mmin -1440 2>/dev/null)" ] && return
    touch "$stamp"
    log "ВНИМАНИЕ: свежей копии нет (последней дней: $age)"
    osascript -e 'display notification "Свежая резервная копия сайта не получена. Журнал: backups/pull.log" with title "iRepair: резервные копии"' >/dev/null 2>&1
}

# 1. что лежит на сервере: имя, размер, возраст последнего архива
INFO=$(ssh "${SSH_OPTS[@]}" "$HOST" "f=\$(ls -1 $REMOTE_DIR/irepair-*.tar.gz.gpg 2>/dev/null | sort | tail -1); [ -n \"\$f\" ] && echo \"\$(basename \"\$f\") \$(stat -c %s \"\$f\") \$(( \$(date +%s) - \$(stat -c %Y \"\$f\") ))\"" 2>/dev/null)
if [ -z "$INFO" ]; then
    log "сервер недоступен или архива на нём нет"
    check_stale; exit 0
fi
read -r NAME SIZE AGE <<< "$INFO"
case "$NAME" in irepair-20??-??-??.tar.gz.gpg) ;; *) log "ОШИБКА: непонятное имя архива: $NAME"; check_stale; exit 1 ;; esac

# архив ещё пишется — заберём при следующем запуске
[ "$AGE" -lt 300 ] && exit 0

# 2. уже есть такой же — делать нечего
if [ -f "$DEST/$NAME" ] && [ "$(stat -f %z "$DEST/$NAME")" = "$SIZE" ]; then
    check_stale; exit 0
fi

# 3. скачиваем во временный файл, сверяем размер и контрольную сумму
log "начало: $NAME, $((SIZE / 1048576)) МБ"
rm -f "$DEST"/*.part
if ! scp -q "${SSH_OPTS[@]}" "$HOST:$REMOTE_DIR/$NAME" "$DEST/$NAME.part" 2>>"$LOG"; then
    rm -f "$DEST/$NAME.part"; log "ОШИБКА: не скачалось"; check_stale; exit 1
fi
if [ "$(stat -f %z "$DEST/$NAME.part")" != "$SIZE" ]; then
    rm -f "$DEST/$NAME.part"; log "ОШИБКА: размер не совпал с серверным"; check_stale; exit 1
fi
SUM_REMOTE=$(ssh "${SSH_OPTS[@]}" "$HOST" "sha256sum $REMOTE_DIR/$NAME" 2>/dev/null | cut -d' ' -f1)
SUM_LOCAL=$(shasum -a 256 "$DEST/$NAME.part" | cut -d' ' -f1)
if [ -z "$SUM_REMOTE" ] || [ "$SUM_REMOTE" != "$SUM_LOCAL" ]; then
    rm -f "$DEST/$NAME.part"; log "ОШИБКА: контрольная сумма не совпала с серверной"; check_stale; exit 1
fi
mv -f "$DEST/$NAME.part" "$DEST/$NAME"

# 4. оставляем KEEP последних (только после успешной загрузки новой)
ls -1 "$DEST"/irepair-*.tar.gz.gpg | sort -r | tail -n +$((KEEP + 1)) | while read -r OLD; do
    rm -f "$OLD" && log "удалён старый: $(basename "$OLD")"
done

log "готово: $NAME, копий в папке: $(ls -1 "$DEST"/irepair-*.tar.gz.gpg | wc -l | tr -d ' ')"
check_stale
