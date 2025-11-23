#!/usr/bin/env bash
# Скрипт резервного копирования данных Gitea

log "Запущен скрипт резервного копирования Gitea..."


######################
# Останавливаем Gitea
######################

log "Останавливаем Gitea..."

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
        log "Прерывание сценария резервного копирования Gitea"
        exit 1
    fi
done


# если gitea была остановлена до выполнения скрипта, то сообщаем об этом
if (( timer == 0 )); then
    log "Gitea была уже остановлена"
else
    log "Gitea успешно остановлена за ${timer} секунд"
fi


###################################
# Проверка целостности SQLite-базы
###################################

log "Проверка целостности SQLite-базы Gitea..."

# Проверка наличия sqlite3
if [[ -f "$GITEA_DB_FILE" ]]; then

    SQLITE_RESULT=$(sqlite3 "$GITEA_DB_FILE" "PRAGMA integrity_check;" 2>&1)

    if [[ "$SQLITE_RESULT" != "ok" ]]; then
        log "ОШИБКА: Целостность SQLite базы Gitea нарушена"

        # построчно выводим журнал ошибок SQLITE_RESULT
        while IFS=read -r line; do
             log "$line"
        done <<< "$SQLITE_RESULT"

        log "Прерывание сценария резервного копирования Gitea"
        exit 1
    fi
else
    log "ОШИБКА: Файл SQLite-базы данных Gitea не найден"
    log "Прерывание сценария резервного копирования Gitea"
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

        if  git -C "$repo" fsck --full --strict >> "$LOG_FILE" 2>&1; then
            log "Репозиторий ${repo} в порядке"
        else
            log "ОШИБКА: Репозиторий ${repo} повреждён"
            log "Прерывание сценария резервного копирования Gitea"
            exit 1
        fi
    fi
done

log "Проверка Git-репозиториев завершена успешно"
