#!/usr/bin/env bash
#gitea-update.sh
# Скрипт обновления Gitea

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


####################################
# Проверка наличия обновлений Gitea
####################################

log "Проверка наличия обновлений Gitea..."

# Узнаём версию текущего бинарника Gitea
GITEA_CURRENT_VERSION="$("$GITEA_BIN_FILE" --version | awk '{print $3}')"

if [[ -n "$GITEA_CURRENT_VERSION" ]]; then
    log "Текущая версия Gitea: $GITEA_CURRENT_VERSION"
else
    fail "\"gitea --version\" вернула пустой результат"
fi


log "Получение JSON-файла latest-версии Gitea с Github..."

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

# Проверяем наличие результата парсинга
[[ -n "$GITEA_LATEST_VERSION" ]] || fail "Парсинг JSON-файла вернул пустое значение"

# Сверяем версии
if [[ "$GITEA_CURRENT_VERSION" == "$GITEA_LATEST_VERSION" ]]; then

    log "Обновление не требуется"
    return 0
else
    log "Доступная новая версия Gitea: $GITEA_LATEST_VERSION"
fi


###########################
# Процесс обновления Gitea
###########################

# Формируем имена файлов и ссылки
GITEA_NEW_BIN_FILE="gitea-$GITEA_LATEST_VERSION-$GITEA_SYSTEM"
GITEA_BIN_URL="https://github.com/go-gitea/gitea/releases/download/$GITEA_LATEST_VERSION/gitea-$GITEA_LATEST_VERSION-$GITEA_SYSTEM"
GITEA_SHA256_URL="$GITEA_BIN_URL.sha256"


log "Загрузка актуальной версии бинарного файла и sha256..."

# Загружаем бинарник и контрольную сумму
curl -fsSL "$GITEA_BIN_URL" -o "$TMP_DIR/$GITEA_NEW_BIN_FILE"
curl -fsSL "$GITEA_SHA256_URL" -o "$TMP_DIR/$GITEA_NEW_BIN_FILE.sha256"
