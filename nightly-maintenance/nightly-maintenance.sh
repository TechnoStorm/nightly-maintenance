#!/usr/bin/env bash
# Скрипт ночного техобслуживания NAS

# принудительно прерываем скрипт при ERRORх, и неинициализированных переменных
set -euo pipefail


# определяем абсолютный путь текущего скрипта
BASE_DIR="$(dirname "$(readlink -f "$0")")"

# читаем конфиг
source "$BASE_DIR/config.sh"


######################
# Определение функций
######################

# функция логгирования
log() {
    local msg="[$(date '+%F %T')] $*"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg"
}


# функция прерывания сценария при отсутствии целевых директорий и файлов
fail() {
    log "ERROR: $*"
    log "Прерван сценарий ночного техобслуживания NAS"
    exit 1
}


# функция обрезки лога
# (удаляются все строки, кроме последних $MAX_LOG_LINES)
trim_log() {
    if [[ -f "$LOG_FILE" ]]; then

        # создаём временный файл лога, с уникальным именем
        local tmp_file="${LOG_FILE}.tmp.$$"

        if tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "$tmp_file"; then
            mv -f "$tmp_file" "$LOG_FILE"
        else
            rm -f "$tmp_file"
            log "ERROR: Обрезка лога не удалась"

            # не прерываем скрипт через "fail()",
            # так-как функция всё равно выполняется в самом конце
        fi
    fi
}


##############################################
# Начало сценария ночного техобслуживания NAS
##############################################

log "Запущен сценарий ночного техобслуживания NAS"


###############################################
# Проверка наличия целевых директорий и файлов
###############################################

[[ -f "$GITEA_BIN_FILE" ]]             || fail "ERROR: Бинарный файл Gitea не найден: $GITEA_BIN_FILE"
[[ -f "$GITEA_CONFIG_FILE" ]]          || fail "ERROR: Конфигурационный файл Gitea не найден: $GITEA_CONFIG_FILE"
[[ -f "$GITEA_DB_FILE" ]]              || fail "ERROR: SQLite-база Gitea не найдена: $GITEA_DB_FILE"
[[ -d "$GITEA_GIT_DIR" ]]              || fail "ERROR: Директория Git-репозиториев не найдена: $GITEA_GIT_DIR"
[[ -d "$GITEA_LFS_DIR" ]]              || fail "ERROR: Директория LFS-хранилища не найдена: $GITEA_LFS_DIR"
[[ -d "$LOG_DIR" ]]                    || fail "ERROR: Директория лог-файла не найдена: $LOG_DIR"
[[ -d "$GITEA_DUMP_DIR" ]]             || fail "ERROR: Директория для дампов Gitea не найдена: $GITEA_DUMP_DIR"
[[ -d "$GITEA_LFS_BACKUP_DIR" ]]       || fail "ERROR: Директория зеркала LFS-хранилища не найдена: $GITEA_LFS_BACKUP_DIR"


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
        fail "ERROR: Остановка сервиса Gitea не удалась"
    fi
done


# если gitea была остановлена до выполнения скрипта, то сообщаем об этом
if (( timer == 0 )); then
    log "Сервис Gitea был уже остановлен"
else
    log "Сервис Gitea успешно остановлен за ${timer} секунд"
fi


###########################################
# Этап резервного копирования данных Gitea
###########################################

source "$BASE_DIR/lib/gitea-backup.sh"


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
        fail "ERROR: Перезапуск сервиса Gitea не удался"
    fi
fi

log "Сервис Gitea успешно запущен за ${timer} секунд"



log "Сценарий ночного техобслуживания NAS успешно завершён"

# напоследок, обрезаем лог
trim_log
