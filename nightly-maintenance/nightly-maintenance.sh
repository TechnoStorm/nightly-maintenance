#!/usr/bin/env bash
# nightly-maintenance.sh
# Скрипт ночного техобслуживания NAS

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail

# Засекаем время исполнения скрипта
SECONDS=0

# Определяем абсолютный путь текущего скрипта
BASE_DIR="$(dirname "$(readlink -f "$0")")"

# Читаем конфиг
source "$BASE_DIR/config.sh"

# Подключаем функции
source "$BASE_DIR/lib/functions.sh"

# Работаем с lock-файлом
exec 200>"$BASE_DIR/lock" || fail "Не удалось открыть lock-файл для чтения"
flock -n 200 || fail "Предыдущий сценарий ночного техобслуживания NAS не завершил выполнение"

# Принудительно создаём лог-директорию, чтобы логгировать все ошибки
if ! mkdir -p "$LOG_DIR"; then
    echo "ERROR: Не удалось создать директорию: $LOG_DIR"
    exit 1
fi

# Переназначаем владельца и права лог-файла
chown "$LOG_CHOWN" "$LOG_DIR/$LOG_FILE" || fail "Не удалось переназначить владельца и группу лог-файла"
chmod "$LOG_CHMOD" "$LOG_DIR/$LOG_FILE" || fail "Не удалось переназначить права доступа лог-файла"

# Создаём временную директорию
TMP_DIR=$(mktemp -d /tmp/nightly-maintenance.XXXXXX 2>/dev/null) ||
    fail "Неудалось создать временную директорию"

cd "$TMP_DIR" || fail "Не удалось сменить рабочую директорию на TMP_DIR".

# Принудительно удаляем $DIR_TEMP даже в случае прерывания скрипта
trap 'rm -rf "$TMP_DIR"' EXIT


##############################################
# Начало сценария ночного техобслуживания NAS
##############################################

log "" # пустая строка, для разделения лога
log "Запущен сценарий ночного техобслуживания NAS"

# Проверяем: запущен-ли сценарий от root?
(( EUID == 0 ))                        || fail "Скрипт запущен не от root"

# Проверяем: смонтирован-ли HDD на точку монтирования?
mountpoint -q "$HDD_MOUNT_POINT"       || fail "$HDD_MOUNT_POINT не является точкой монтирования"

# Проверяем наличие необходимых утилит
command -v sqlite3 >/dev/null 2>&1     || fail "sqlite3 не установлен"
command -v rsync >/dev/null 2>&1       || fail "rsync не установлен"
command -v jq >/dev/null 2>&1          || fail "jq не установлен"
command -v curl >/dev/null 2>&1        || fail "curl не установлен"

# Проверяем наличие необходимых директорий и файлов
[[ -f "$GITEA_BIN_FILE" ]]             || fail "Бинарный файл Gitea не найден: $GITEA_BIN_FILE"
[[ -x "$GITEA_BIN_FILE" ]]             || fail "Бинарный файл Gitea не является исполняемым: $GITEA_BIN_FILE"
[[ -f "$GITEA_CONFIG_FILE" ]]          || fail "Конфигурационный файл Gitea не найден: $GITEA_CONFIG_FILE"
[[ -f "$GITEA_DB_FILE" ]]              || fail "SQLite-база Gitea не найдена: $GITEA_DB_FILE"
[[ -d "$GITEA_GIT_DIR" ]]              || fail "Директория Git-репозиториев не найдена: $GITEA_GIT_DIR"
[[ -d "$GITEA_LFS_DIR" ]]              || fail "Директория LFS-хранилища не найдена: $GITEA_LFS_DIR"
[[ -d "$GITEA_DUMP_DIR" ]]             || fail "Директория для дампов Gitea не найдена: $GITEA_DUMP_DIR"
[[ -d "$GITEA_LFS_BACKUP_DIR" ]]       || fail "Директория зеркала LFS-хранилища не найдена: $GITEA_LFS_BACKUP_DIR"


#####################
# Обслуживание Gitea
#####################

log "Начат этап обслуживания Gitea"

# Остановка сервиса Gitea
source "$BASE_DIR/lib/gitea-stop.sh"

log "Начало резервного копирования Gitea..."

# Резервное копирование данных Gitea
source "$BASE_DIR/lib/gitea-backup.sh"

log "Резервное копирование данных Gitea успешно завершено"

# Проверяем, что сегодня понедельник
if [[ "$(date +%u)" -eq 1 ]]; then

    log "Начало обновления Gitea..."

    #Запускаем процесс обновления Gitea
    source "$BASE_DIR/lib/gitea-update.sh"
fi


# Перезапуск сервиса Gitea
source "$BASE_DIR/lib/gitea-start.sh"

log "Этап обслуживания Gitea успешно завершён"


############################################
# Резервное копирования папок синхронизации
############################################

# Резервное копирование директорий Syncthing
# source "$BASE_DIR/lib/sync-backup.sh"


# Вычисляем прошедшее время
minutes=$((SECONDS / 60))
seconds=$((SECONDS % 60))
log "Сценарий ночного техобслуживания NAS успешно завершён за $minutes:$seconds секунд"


# Обрезаем лог
trim_log
