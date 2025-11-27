#!/usr/bin/env bash
# Скрипт резервного копирования данных Gitea

log "Начат этап резервного копирования данных Gitea"

#########################################
# Проверка целостности SQLite-базы Gitea
#########################################

log "Проверка целостности SQLite-базы Gitea..."

# Проверка наличия sqlite3
if ! command -v sqlite3 >/dev/null 2>&1; then
    fail "ERROR: sqlite3 не установлен"
fi


SQLITE_RESULT=$(sqlite3 "$GITEA_DB_FILE" "PRAGMA integrity_check;" 2>&1)

if [[ "$SQLITE_RESULT" != "ok" ]]; then
    log "ERROR: Целостность SQLite базы Gitea нарушена"

    # построчно выводим журнал ошибок SQLITE_RESULT
    while IFS=read -r line; do
         log "$line"
     done <<< "$SQLITE_RESULT"

     fail "Прерван сценарий ночного техобслуживания NAS"
fi


log "Целостность SQLite-базы Gitea подтверждена"


##########################################
# Проверка целостности репозиториев Gitea
##########################################

log "Проверка целостности репозиториев Gitea..."

# по очереди проверяем целостность каждого репозитория пользователей
for repo in "$GITEA_GIT_DIR"/*/*; do

    # проверяем: действительно-ли это директория?
    if [[ -d "$repo" ]]; then

        log "Проверка репозитория ${repo}..."

        if  git -C "$repo" fsck --full --strict >> "$GITEA_LOG_FILE" 2>&1; then
            log "Репозиторий ${repo} в порядке"
        else
            fail "ERROR: Репозиторий ${repo} повреждён"
        fi
    fi
done

log "Проверка Git-репозиториев завершена успешно"


#######################
# Создание дампа Gitea
#######################

log "Создание дампа Gitea..."

DUMP_TIMESTAMP=$(date +%F_%H_%M_%S)

# делаем дамп gitea, игнорируя LFS-хранилище
# логгируем весь вывод gitea dump, включая ошибки
# запускаем НЕ от root, так как root отклоняется самой gitea
if sudo -u gitea "$GITEA_BIN_FILE" dump \
    -c "$GITEA_CONFIG_FILE" \
    --skip-lfs-data \
    --file "$GITEA_DUMP_DIR"/"${GITEA_DUMP_NAME}_${DUMP_TIMESTAMP}.zip" \
    >> "$GITEA_LOG_FILE" 2>&1
then
    log "Создание дампа Gitea успешно завершено"
else
    fail "ERROR: Создание дампа Gitea не удалось"
fi


#########################################
# Зеркалирование LFS-хранилища
#########################################

log "Зеркалирование LFS-хранилища..."

# Проверка наличия rsync
if ! command -v rsync >/dev/null 2>&1; then
    fail "ERROR: rsync не установлен"
fi


# выполняем зеркалирование
if rsync -aH --delete --stats \
    "$GITEA_LFS_DIR"/ \
    "$GITEA_LFS_BACKUP_DIR"/ \
    >> "$GITEA_LOG_FILE" 2>&1; then

    log "Зеркалирование LFS-хранилища успешно завершено"
else
    fail "ERROR: rsync завершился с ошибкой -- LFS-хранилище НЕ синхронизировано"
fi

log "Этап резервного копирования данных Gitea завершён"
