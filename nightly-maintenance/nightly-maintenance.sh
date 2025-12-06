#!/usr/bin/env bash
# nightly-maintenance.sh
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

# Подключаем функции
source "$BASE_DIR/lib/functions.sh"


##############################################
# Начало сценария ночного техобслуживания NAS
##############################################

log "Запущен сценарий ночного техобслуживания NAS"


#####################
# Стартовые проверки
#####################

# Проверяем: запущен-ли сценарий от root?
(( EUID == 0 ))                                       || fail "Скрипт запущен не от root"

# Проверяем наличие необходимых утилит
command -v sqlite3 >/dev/null 2>&1                    || fail "sqlite3 не установлен"
command -v rsync >/dev/null 2>&1                      || fail "rsync не установлен"

# Проверяем наличие необходимых директорий и файлов
[[ -f "$GITEA_BIN_FILE" ]]                            || fail "Бинарный файл Gitea не найден: $GITEA_BIN_FILE"
[[ -f "$GITEA_CONFIG_FILE" ]]                         || fail "Конфигурационный файл Gitea не найден: $GITEA_CONFIG_FILE"
[[ -f "$GITEA_DB_FILE" ]]                             || fail "SQLite-база Gitea не найдена: $GITEA_DB_FILE"
[[ -d "$GITEA_GIT_DIR" ]]                             || fail "Директория Git-репозиториев не найдена: $GITEA_GIT_DIR"
[[ -d "$GITEA_LFS_DIR" ]]                             || fail "Директория LFS-хранилища не найдена: $GITEA_LFS_DIR"
[[ -d "$GITEA_DUMP_DIR" ]]                            || fail "Директория для дампов Gitea не найдена: $GITEA_DUMP_DIR"
[[ -d "$HDD_MOUNT_POINT"/"$GITEA_LFS_BACKUP_DIR" ]]   || fail "Директория зеркала LFS-хранилища не найдена: $HDD_MOUNT_POINT/$GITEA_LFS_BACKUP_DIR"


#####################
# Обслуживание Gitea
#####################

log "Начат этап обслуживания Gitea"

# Остановка сервиса Gitea
source "$BASE_DIR/lib/gitea-stop.sh"

log "Начало резервного копирования Gitea..."

# Резервное копирование данных Gitea
source "$BASE_DIR/lib/gitea-backup.sh"

log "Этап резервного копирования данных Gitea успешно завершён"

# Перезапуска сервиса Gitea
source "$BASE_DIR/lib/gitea-start.sh"

# Обновление Gitea
# source "$BASE_DIR/lib/gitea-update.sh"

log "Этап обслуживания Gitea успешно завершён"





log "Сценарий ночного техобслуживания NAS успешно завершён"

# Напоследок, обрезаем лог
trim_log
