#!/usr/bin/env bash
#gitea-update.sh
# Скрипт ообновления Gitea

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


####################################
# Проверка наличия обновлений Gitea
####################################

log "Проверка наличия обновлений Gitea..."

log "Определение текущей версии Gitea..."

# Узнаём версию текущего бинарника Gitea
GITEA_CURRENT_VERSION="$("$GITEA_BIN_FILE" --version | awk '{print $3}')"

if [[ -n "$GITEA_CURRENT_VERSION" ]]; then
    log "Текущая версия Gitea: $GITEA_CURRENT_VERSION"
else
    fail "\"gitea --version\" вернула пустой результат"
fi


log "Проверка наличия обновлений Gitea..."

log "Получение JSON-файла latest-версии Gitea..."

JSON=$(curl -fsSL "https://api.github.com/repos/go-gitea/gitea/releases/latest")

log "Парсинг JSON-файла..."

# Парсим тег версии и проверяем формат "x.x.x"
GITEA_LATEST_VERSION=$(
    echo "$JSON" | jq -r '
    .tag_name
    | ltrimstr("v")
    | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
    '
)

# Проверка наличия результата парсинга
[[ -n "$GITEA_LATEST_VERSION" ]] || fail "Парсинг JSON-файла вернул пустое значение"

echo "$GITEA_LATEST_VERSION"
