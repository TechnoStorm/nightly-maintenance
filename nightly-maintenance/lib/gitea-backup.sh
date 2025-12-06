#!/usr/bin/env bash
# gitea-backup.sh
# Скрипт резервного копирования данных Gitea

log "Начат этап резервного копирования данных Gitea"

#########################################
# Проверка целостности SQLite-базы Gitea
#########################################

log "Проверка целостности SQLite-базы Gitea..."

SQLITE_RESULT=$(sqlite3 "$GITEA_DB_FILE" "PRAGMA integrity_check;" 2>&1)

if [[ "$SQLITE_RESULT" != "ok" ]]; then

    # Построчно выводим журнал ошибок $SQLITE_RESULT
    while IFS=read -r line; do
         log "$line"
     done <<< "$SQLITE_RESULT"

     fail "Целостность SQLite базы Gitea нарушена"
fi

log "Целостность SQLite-базы Gitea подтверждена"


##########################################
# Проверка целостности репозиториев Gitea
##########################################

log "Проверка целостности репозиториев Gitea..."

# По очереди проверяем целостность каждого репозитория пользователей
for repo in "$GITEA_GIT_DIR"/*/*; do

    # Проверяем: действительно-ли это директория?
    if [[ -d "$repo" ]]; then

        log "Проверка репозитория $repo..."

        if  git -C "$repo" fsck --full --strict >> "$LOG_DIR"/"$GITEA_LOG_FILE" 2>&1; then
            log "Репозиторий $repo в порядке"
        else
            fail "Репозиторий $repo повреждён"
        fi
    fi
done

log "Проверка Git-репозиториев завершена успешно"


#######################
# Создание дампа Gitea
#######################

log "Создание дампа Gitea..."

DUMP_TIMESTAMP=$(date +%F_%H_%M_%S)

# Делаем дамп gitea, игнорируя LFS-хранилище
# Логгируем весь вывод gitea dump, включая ошибки
# Запускаем НЕ от root, так как root отклоняется самой gitea
if sudo -u "$GITEA_USER" "$GITEA_BIN_FILE" dump \
    -c "$GITEA_CONFIG_FILE" \
    --skip-lfs-data \
    --file "$GITEA_DUMP_DIR"/"${GITEA_DUMP_NAME}_${DUMP_TIMESTAMP}.zip" \
    >> "$LOG_DIR"/"$GITEA_LOG_FILE" 2>&1
then
    log "Создание дампа Gitea успешно завершено"
else
    fail "Создание дампа Gitea не удалось"
fi


#########################################
# Зеркалирование LFS-хранилища
#########################################

log "Зеркалирование LFS-хранилища..."

# Выполняем зеркалирование
if rsync -aH --delete --stats \
    "$GITEA_LFS_DIR"/ \
    "$GITEA_LFS_BACKUP_DIR"/ \
    >> "$LOG_DIR"/"$GITEA_LOG_FILE" 2>&1; then

    log "Зеркалирование LFS-хранилища успешно завершено"
else
    fail "rsync завершился с ошибкой -- LFS-хранилище НЕ синхронизировано"
fi

log "Этап резервного копирования данных Gitea завершён"
