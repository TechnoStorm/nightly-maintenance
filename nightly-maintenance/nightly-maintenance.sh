#!/usr/bin/env bash
# Скрипт ночного техобслуживания NAS

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


# Определяем абсолютный путь текущего скрипта
BASE_DIR="$(dirname "$(readlink -f "$0")")"

# Читаем конфиг
source "$BASE_DIR/config.sh"

# Принудительно создаём лог-директорию, чтобы логгировать все ошибки
if ! mkdir -p "$LOG_DIR"; then
    echo "ERROR: Не удалось создать директорию: $LOG_DIR"
    exit 1
fi


######################
# Определение функций
######################

# Функция логгирования
log() {
    local msg="[$(date '+%F %T')] $*"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg"
}


# Функция ошибки выполнения скрипта
fail() {
    log "ERROR: $*"
    log "Прерван сценарий ночного техобслуживания NAS"
    exit 1
}


# Функция обрезки лога (удаляются все строки, кроме последних $MAX_LOG_LINES)
trim_log() {
    if [[ -f "$LOG_FILE" ]]; then

        # Создаём временный файл лога, с уникальным именем
        local tmp_file
        tmp_file=$(mktemp "${LOG_FILE}.tmp.XXXXXX") || fail "Не удалось создать временный log-файл для обрезки лога"

        # Сохраняем последние $MAX_LOG_LINES строк
        if tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "$tmp_file"; then

            # Заменяем старый лог-файл на новый
            mv -f "$tmp_file" "$LOG_FILE" || fail "При обрезке лога не удалось заменить старый лог-файл обновлённым"
        else
            rm -f "$tmp_file"
            log "ERROR: Обрезка лога не удалась"

            # Не прерываем скрипт через "fail()", так-как функция всё равно выполняется в самом конце
        fi
    fi
}


##############################################
# Начало сценария ночного техобслуживания NAS
##############################################

log "Запущен сценарий ночного техобслуживания NAS"



#########################
# Стартовые перепроверки
#########################

# Проверка: запущен-ли сценарий от root?
(( EUID == 0 ))                        || fail "Скрипт запущен не от root"

# Проверка наличия необходимых утилит
command -v sqlite3 >/dev/null 2>&1     || fail "sqlite3 не установлен"
command -v rsync >/dev/null 2>&1       || fail "rsync не установлен"

# Проверка наличия необходимых директорий и файлов
[[ -f "$GITEA_BIN_FILE" ]]             || fail "Бинарный файл Gitea не найден: $GITEA_BIN_FILE"
[[ -f "$GITEA_CONFIG_FILE" ]]          || fail "Конфигурационный файл Gitea не найден: $GITEA_CONFIG_FILE"
[[ -f "$GITEA_DB_FILE" ]]              || fail "SQLite-база Gitea не найдена: $GITEA_DB_FILE"
[[ -d "$GITEA_GIT_DIR" ]]              || fail "Директория Git-репозиториев не найдена: $GITEA_GIT_DIR"
[[ -d "$GITEA_LFS_DIR" ]]              || fail "Директория LFS-хранилища не найдена: $GITEA_LFS_DIR"
[[ -d "$GITEA_DUMP_DIR" ]]             || fail "Директория для дампов Gitea не найдена: $GITEA_DUMP_DIR"
[[ -d "$GITEA_LFS_BACKUP_DIR" ]]       || fail "Директория зеркала LFS-хранилища не найдена: $GITEA_LFS_BACKUP_DIR"


##################
# Остановка Gitea
##################

log "Остановка сервиса Gitea..."

# Если сервис запущен - останавливаем его
if systemctl is-active --quiet gitea; then
    systemctl stop gitea
fi


# Проверка остановки сервиса
MAX_WAIT=30 # максимальное время ожидания
timer=0
while systemctl is-active --quiet gitea; do
    sleep 1
    ((timer++))

    # Проверяем: истекло-ли время ожидания?
    if (( timer >= MAX_WAIT )); then
        fail "Остановка сервиса Gitea не удалась"
    fi
done


# Если gitea была остановлена до выполнения скрипта, то сообщаем об этом
if (( timer == 0 )); then
    log "Сервис Gitea был уже остановлен"
else
    log "Сервис Gitea успешно остановлен за ${timer} секунд"
fi


#####################################
# Резервное копирование данных Gitea
#####################################

source "$BASE_DIR/lib/gitea-backup.sh"


###################
# Перезапуск Gitea
###################

log "Перезапуск сервиса Gitea..."

# Проверка удачности запуска на уровне systemctl
if ! systemctl start gitea; then
    fail "systemctl не смог запустить сервис Gitea"
fi


# Проверка удачности запуска на уровне сервиса
timer=0
while ! systemctl is-active --quiet gitea; do
    sleep 1
    ((timer++))

    # Проверяем: истекло-ли время ожидания?
    if (( timer >= MAX_WAIT )); then
        fail "Перезапуск сервиса Gitea не удался"
    fi
fi

log "Сервис Gitea успешно запущен за ${timer} секунд"



log "Сценарий ночного техобслуживания NAS успешно завершён"

# Напоследок, обрезаем лог
trim_log
