#!/usr/bin/env bash
# nightly-maintenance.sh
# Скрипт резервного копирования директории Syncthing

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


log "Зеркалирование директории Syncthing..."

# Выполняем зеркалирование
if sudo rsync -aH --delete --numeric-ids --stats \
    "$SYNC_DIR"/ \
    "$SYNC_BACKUP_DIR"/ \
    >> "$LOG_FILE" 2>&1; then

    echo "" >> "$LOG_FILE" # отступ
    log "Зеркалирование директории Syncthing успешно завершено"
else
    fail "Ошибка выполнения зеркалирования средствами rsync"
fi
