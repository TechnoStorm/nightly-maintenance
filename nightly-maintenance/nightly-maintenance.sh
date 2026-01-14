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

# Создаём в лог-файле строки-разделители
echo "" >> "$LOG_FILE" # отступ
echo "=============== $(date '+%F %T') ===============" >> "$LOG_FILE"
echo "" >> "$LOG_FILE" # отступ

log "Запущен сценарий ночного техобслуживания NAS"


# Принудительно создаём лог-файл, если он ещё не создан
if [[ ! -f "$LOG_FILE" ]]; then

    # Создаём лог-файл
    if ! touch "$LOG_FILE"; then
    echo "[ERROR]: Неудалось создать лог-файл"
    exit 1
    fi

    chown "$LOG_CHOWN" "$LOG_FILE" || fail "Не удалось переназначить владельца и группулог-файла"
    chmod "$LOG_CHMOD" "$LOG_FILE" || fail "Не удалось переназначить права доступа лог-файла"
fi

# Создаём временную директорию
TMP_DIR=$(mktemp -d /tmp/nightly-maintenance.XXXXXX 2>/dev/null) ||
    fail "Неудалось создать временную директорию"

# Меняем текущую директорию на $TMP_DIR
cd "$TMP_DIR" || fail "Не удалось сменить директорию на TMP_DIR"

# Работаем с lock-файлом
exec 200>"$BASE_DIR/lock" || fail "Не удалось открыть lock-файл для чтения"
flock -n 200 || fail "Предыдущий сценарий ночного техобслуживания NAS не завершил выполнение"

# Принудительно удаляем $DIR_TEMP даже в случае прерывания скрипта
trap 'rm -rf "$TMP_DIR"' EXIT


##############################################
# Начало сценария ночного техобслуживания NAS
##############################################

# Проверяем: запущен-ли сценарий от root?
(( EUID == 0 ))                               || fail "Скрипт запущен не от root"

# Проверяем наличие необходимых утилит
command -v sqlite3 >/dev/null 2>&1            || fail "sqlite3 не установлен"
command -v rsync >/dev/null 2>&1              || fail "rsync не установлен"
command -v jq >/dev/null 2>&1                 || fail "jq не установлен"
command -v curl >/dev/null 2>&1               || fail "curl не установлен"

# Проверяем: смонтирован-ли HDD на точку монтирования?
mountpoint -q "$HDD_MOUNT_POINT"              || fail "$HDD_MOUNT_POINT не является точкой монтирования"

# С помощью файла-маркера проверяем: точно-ли смонтирован правильный диск?
[[ -f "$HDD_MOUNT_POINT"/nas-hdd-marker ]]    || fail "Файл-маркер (\"nas-hdd-marker\") отсутствует на $HDD_MOUNT_POINT"

# Проверяем наличие пользователя Gitea
id "$GITEA_USER" &>/dev/null                  || fail "Пользователь Gitea не существует"

# Проверяем наличие необходимых директорий и файлов
[[ -f "$GITEA_BIN_FILE" ]]                    || fail "Бинарный файл Gitea не найден: $GITEA_BIN_FILE"
[[ -x "$GITEA_BIN_FILE" ]]                    || fail "Бинарный файл Gitea не является исполняемым: $GITEA_BIN_FILE"
[[ -f "$GITEA_CONFIG_FILE" ]]                 || fail "Конфигурационный файл Gitea не найден: $GITEA_CONFIG_FILE"
[[ -f "$GITEA_DB_FILE" ]]                     || fail "SQLite-база Gitea не найдена: $GITEA_DB_FILE"
[[ -d "$GITEA_GIT_DIR" ]]                     || fail "Директория Git-репозиториев не найдена: $GITEA_GIT_DIR"
[[ -d "$GITEA_LFS_DIR" ]]                     || fail "Директория LFS-хранилища не найдена: $GITEA_LFS_DIR"
[[ -d "$GITEA_DUMP_DIR" ]]                    || fail "Директория для дампов Gitea не найдена: $GITEA_DUMP_DIR"
[[ -d "$GITEA_LFS_BACKUP_DIR" ]]              || fail "Директория зеркала LFS-хранилища не найдена: $GITEA_LFS_BACKUP_DIR"



############################################
# Резервное копирования папок синхронизации
############################################

# Резервное копирование директории Syncthing
source "$BASE_DIR/lib/sync-backup.sh"


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

    log "Проверка доступности GitHub API..."

    # Проверка доступности Github Api
    if curl -fsS \
        --connect-timeout 5 \
        --max-time 10 \
        -H "User-Agent: nightly-maintenance-script" \
        "https://api.github.com/rate_limit" \
        >/dev/null 2>&1; then

        # Запускаем процесс обновления Gitea
        source "$BASE_DIR/lib/gitea-update.sh"
    else
        # Получаем код ошибки
        CURL_CODE=$?
        log "[WARNING]: GitHub API недоступен, этап обновления Gitea пропущен (curl code: $CURL_CODE)"
    fi
fi

# Перезапуск сервиса Gitea
source "$BASE_DIR/lib/gitea-start.sh"

log "Этап обслуживания Gitea успешно завершён"


#####################
# Завершение скрипта
#####################

# Вычисляем прошедшее время
hours=$((SECONDS / 3600))
minutes=$(((SECONDS % 3600) / 60))
seconds=$((SECONDS % 60))

log "Сценарий ночного техобслуживания NAS успешно завершён ($(printf '%02d:%02d:%02d' $hours $minutes $seconds))"


# Обрезаем лог
trim_log
