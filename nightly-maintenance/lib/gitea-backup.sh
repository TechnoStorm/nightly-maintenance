#!/usr/bin/env bash
# Скрипт резервного копирования данных Gitea

log "Запущен сценарий резервного копирования Gitea..."


###############################################
# Проверка наличия целевых директорий и файлов
###############################################

[[ -f "$GITEA_BIN_FILE" ]]             || fail "ОШИБКА: Бинарный файл Gitea не найден: $GITEA_BIN_FILE"
[[ -f "$GITEA_CONFIG_FILE" ]]          || fail "ОШИБКА: Конфигурационный файл Gitea не найден: $GITEA_CONFIG_FILE"
[[ -f "$GITEA_DB_FILE" ]]              || fail "ОШИБКА: SQLite-база Gitea не найдена: $GITEA_DB_FILE"
[[ -d "$GITEA_GIT_DIR" ]]              || fail "ОШИБКА: Директория Git-репозиториев не найдена: $GITEA_GIT_DIR"
[[ -d "$GITEA_LFS_DIR" ]]              || fail "ОШИБКА: Директория LFS-хранилища не найдена: $GITEA_LFS_DIR"
[[ -d "$GITEA_LFS_BACKUP_DIR" ]]       || fail "ОШИБКА: Директория зеркала LFS-хранилища не найдена: $GITEA_LFS_BACKUP_DIR"


######################
# Останавливаем Gitea
######################

log "Остановка сервиса Gitea..."

# если сервис запущен - останавливаем его
if systemctl is-active --quiet gitea; then
    systemctl stop gitea
fi


# проверка остановки сервиса
MAX_WAIT=30 # максимальное время ожидания
timer=0
while systemctl is-active --quiet gitea; do
    sleep 1
    ((timer++))

    # проверяем: истекло-ли время ожидания?
    if (( timer >= MAX_WAIT )); then
        log "ОШИБКА: Остановка сервиса Gitea не удалась"
        log "Сценарий резервного копирования Gitea прерван"
        exit 1
    fi
done


# если gitea была остановлена до выполнения скрипта, то сообщаем об этом
if (( timer == 0 )); then
    log "Сервис Gitea был уже остановлен"
else
    log "Сервис Gitea успешно остановлен за ${timer} секунд"
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
    log "ОШИБКА: Файл SQLite-базы Gitea не найден"
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


#########################################
# Зеркалирование LFS-хранилища
#########################################

log "Зеркалирование LFS-хранилища..."

# Проверка наличия rsync
if ! command -v rsync >/dev/null 2>&1; then
    log "ОШИБКА: rsync не установлен"
    log "Сценарий резервного копирования Gitea прерван"
    exit 1
fi


# выполняем зеркалирование
if rsync -aH --delete --stats \
    "$GITEA_LFS_DIR"/ \
    "$GITEA_LFS_BACKUP_DIR"/ \
    >> "$GITEA_LOG_FILE" 2>&1; then

    log "Зеркалирование LFS-хранилища успешно завершено"
else
    log "ОШИБКА: rsync завершился с ошибкой -- LFS-хранилище НЕ синхронизировано"
    exit 1
fi


###################
# Перезапуск Gitea
###################

log "Перезапуск сервиса Gitea..."

systemctl start gitea

timer=0

# проверка запуска сервиса
while ! systemctl is-active --quiet gitea; do
    sleep 1
    ((timer++))

    #проверяем: истекло-ли время ожидания?
    if (( timer >= MAX_WAIT )); then
        log "ОШИБКА: Перезапуск сервиса Gitea не удался"
        log "Сценарий резервного копирования Gitea прерван"
        exit 1
    fi
fi

log "Сервис Gitea успешно запущен за ${timer} секунд"
