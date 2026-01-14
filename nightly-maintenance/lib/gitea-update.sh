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
GITEA_CURRENT_VERSION="$(
    "$GITEA_BIN_FILE" --version |
    grep -oE 'gitea version [0-9]+\.[0-9]+\.[0-9]+' |
    awk '{print $3}'
)"

[[ -n "$GITEA_CURRENT_VERSION" ]] || fail "Не удалось определить версию Gitea"

log "Получение JSON последней версии Gitea..."

JSON=$(curl -fsSL \
    --retry 3 \
    --retry-delay 10 \
    -H "User-Agent: nightly-maintenance-script" \
    "https://api.github.com/repos/go-gitea/gitea/releases/latest") ||
    fail "GitHub API недоступен"


jq -e 'length > 0' <<< "$JSON" >/dev/null 2>&1 ||
    fail "GitHub API вернул пустой или некорректный JSON"

log "Парсинг JSON..."

# Парсим тег версии и проверяем формат "x.x.x"
GITEA_LATEST_VERSION=$(
    echo "$JSON" | jq -r '
    .tag_name
    | ltrimstr("v")
    | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
    '
)

# Проверяем наличие результата парсинга
[[ -n "$GITEA_LATEST_VERSION" ]] || fail "JSON-парсер вернул пустое значение"

# Сверяем версии
if [[ "$GITEA_CURRENT_VERSION" == "$GITEA_LATEST_VERSION" ]]; then
    log "Обновление не требуется"
    return 0
fi

log "Доступно обновление Gitea: $GITEA_CURRENT_VERSION -> $GITEA_LATEST_VERSION"


########################
# Загрузка файлов Gitea
########################

# Формируем имена файлов и ссылки
GITEA_NEW_BIN_FILE="gitea-$GITEA_LATEST_VERSION-$GITEA_SYSTEM"
GITEA_BIN_URL="https://github.com/go-gitea/gitea/releases/download/v$GITEA_LATEST_VERSION/gitea-$GITEA_LATEST_VERSION-$GITEA_SYSTEM"
GITEA_SHA256_URL="$GITEA_BIN_URL.sha256"

log "Загрузка нового бинарного файла Gitea: $GITEA_NEW_BIN_FILE..."

curl -fsSL "$GITEA_BIN_URL" -o "$GITEA_NEW_BIN_FILE" ||
    fail "Не удалось загрузить новый бинарный файл: $GITEA_NEW_BIN_FILE"

log "Загрузка контрольной суммы: $GITEA_NEW_BIN_FILE.sha256..."

curl -fsSL "$GITEA_SHA256_URL" -o "$GITEA_NEW_BIN_FILE.sha256" ||
    fail "Не удалось загрузить контрольную сумму: $GITEA_NEW_BIN_FILE.sha256"

log "Загрузка файлов успешно завершена"


#############################
# Проверка контрольной суммы
#############################

log "Проверка контрольной суммы для: $GITEA_NEW_BIN_FILE..."

sha256sum -c "$(basename "$GITEA_NEW_BIN_FILE.sha256")" >/dev/null ||
    fail "Неудачная проверка контрольной суммы для: $GITEA_NEW_BIN_FILE"

log "Проверка контрольной суммы успешно завершена"


#######################
# Обновление бинарника
#######################

log "Установка рабочего нового бинарного файла в рабочую директорию..."

# Создаём копию нового бинарника в рабочей директории Gitea
install -m 755 "$GITEA_NEW_BIN_FILE" "$GITEA_BIN_FILE.new"

# Атомарно обновляем старый бинарник новым
mv -f "$GITEA_BIN_FILE.new" "$GITEA_BIN_FILE"

log "Свежий бинарный файл успешно установлен в рабочую директорию"

# Перепроверяем версию обновлённого бинарника
GITEA_CURRENT_VERSION="$(
    "$GITEA_BIN_FILE" --version |
    grep -oE 'gitea version [0-9]+\.[0-9]+\.[0-9]+' |
    awk '{print $3}'
)"

[[ -n "$GITEA_CURRENT_VERSION" ]] ||
    fail "Не удалось определить версию обновлённого бинарного файла Gitea"

[[ "$GITEA_CURRENT_VERSION" == "$GITEA_LATEST_VERSION" ]] ||
    fail "Версия обновлённого бинарного файла Gitea ($GITEA_CURRENT_VERSION) не соответствует актуальной ($GITEA_LATEST_VERSION)"

log "Обновление Gitea до версии $GITEA_LATEST_VERSION успешно завершено"
