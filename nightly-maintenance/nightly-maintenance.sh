#!/usr/bin/env bash
# nightly-maintenance.sh
# Скрипт ночного техобслуживания NAS

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


# Определяем абсолютный путь текущего скрипта
BASE_DIR="$(dirname "$(readlink -f "$0")")"

# Читаем конфиг
source "$BASE_DIR/config.sh"

# Подключаем функции
source "$BASE_DIR/lib/functions.sh"

# Принудительно создаём лог-директорию, чтобы логгировать все ошибки
if ! mkdir -p "$LOG_DIR"; then
    echo "ERROR: Не удалось создать директорию: $LOG_DIR"
    exit 1
fi


##############################################
# Начало сценария ночного техобслуживания NAS
##############################################

log "Запущен сценарий ночного техобслуживания NAS"


#####################
# Стартовые проверки
#####################


# Проверяем: запущен-ли сценарий от root?
(( EUID == 0 ))                        || fail "Скрипт запущен не от root"

# Проверяем наличие необходимых утилит
command -v sqlite3 >/dev/null 2>&1     || fail "sqlite3 не установлен"
command -v rsync >/dev/null 2>&1       || fail "rsync не установлен"

# Проверяем наличие необходимых директорий и файлов
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
