#!/usr/bin/env bash
# Скрипт резервного копирования данных Gitea

log "Запущен сценарий резервного копирования Gitea..."


######################
# Останавливаем Gitea
######################

log "Остановка Gitea..."

# если сервис запущен - останавливаем его
if systemctl is-active --quiet gitea; then
    systemctl stop gitea
fi


# проверка остановки сервиса
MAX_WAIT=30 # макс. время ожидания остановки gitea
timer=0
while systemctl is-active --quiet gitea; do
    sleep 1
    ((timer++))
    # проверяем: истекло-ли время ожидания?
    if (( timer >= MAX_WAIT )); then
        log "ОШИБКА: Остановка Gitea не удалась"
        log "Сценарий резервного копирования Gitea прерван"
        exit 1
    fi
done


# если gitea была остановлена до выполнения скрипта, то сообщаем об этом
if (( timer == 0 )); then
    log "Gitea была уже остановлена"
else
    log "Gitea успешно остановлена за ${timer} секунд"
fi


#########################################
# Проверка целостности SQLite-базы Gitea
#########################################

log "Проверка целостности SQLite-базы Gitea..."

# Проверка наличия sqlite3
if ! command -v sqlite3 >/dev/null 2>&1; then
    log "ОШИБКА: sqlite3 не установлен"
    log "Сценарий резервного копирования Gitea прерван"
    exit 1
fi

# если файл БД существует, то проверяем целостность
if [[ -f "$GITEA_DB_FILE" ]]; then

    SQLITE_RESULT=$(sqlite3 "$GITEA_DB_FILE" "PRAGMA integrity_check;" 2>&1)

    if [[ "$SQLITE_RESULT" != "ok" ]]; then
        log "ОШИБКА: Целостность SQLite базы Gitea нарушена"

        # построчно выводим журнал ошибок SQLITE_RESULT
        while IFS=read -r line; do
             log "$line"
        done <<< "$SQLITE_RESULT"

        log "Сценарий резервного копирования Gitea прерван"
        exit 1
    fi
else
    log "ОШИБКА: Файл SQLite-базы данных Gitea не найден"
    log "Сценарий резервного копирования Gitea прерван"
    exit 1
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
            log "ОШИБКА: Репозиторий ${repo} повреждён"
            log "Сценарий резервного копирования Gitea прерван"
            exit 1
        fi
    fi
done

log "Проверка Git-репозиториев завершена успешно"


#######################
# Создание дампа Gitea
#######################

log "Создание дампа Gitea..."

# делаем дамп gitea, игнорируя LFS-хранилище
# логгируем весь вывод gitea dump, включая ошибки
# запускаем НЕ от root, так как root отклоняется самой gitea
if sudo -u gitea "$GITEA_BIN_FILE" dump \
    -c "$GITEA_CONFIG_FILE" \
    --skip-lfs-data \
    --file "$GITEA_DUMP_DIR"/"$GITEA_DUMP_NAME" \
    >> "$GITEA_LOG_FILE" 2>&1
then
    log "Создание дампа Gitea успешно завершено"
else
    log "ОШИБКА: Создание дампа Gitea не удалось"
    log "Сценарий резервного копирования Gitea прерван"
    exit 1
fi
