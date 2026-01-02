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

[[ -n "$GITEA_CURRENT_VERSION" ]] || fail "\"gitea --version\" вернула пустой результат"

log "Получение содержимого JSON-файла последней версии Gitea с GitHub..."

JSON=$(curl -fsSL "https://api.github.com/repos/go-gitea/gitea/releases/latest")

[[ -n "$JSON" ]] || fail "Не удалось получить содержимое JSON-файла"

log "Парсинг содержимого JSON-файла..."

# Парсим тег версии и проверяем формат "x.x.x"
GITEA_LATEST_VERSION=$(
    echo "$JSON" | jq -r '
    .tag_name
    | ltrimstr("v")
    | select(test("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
    '
)

# Проверяем наличие результата парсинга
[[ -n "$GITEA_LATEST_VERSION" ]] || fail "Парсинг содержимого JSON-файла вернул пустое значение"

# Сверяем версии
if [[ "$GITEA_CURRENT_VERSION" == "$GITEA_LATEST_VERSION" ]]; then

    log "Обновление не требуется"
    return 0
fi

log "Доступно обновление Gitea: $GITEA_CURRENT_VERSION -> $GITEA_LATEST_VERSION"


#########################################
# Загрузка свежего бинарного файла Gitea
#########################################

# Формируем имена файлов и ссылки
GITEA_NEW_BIN_FILE="gitea-$GITEA_LATEST_VERSION-$GITEA_SYSTEM"
GITEA_BIN_URL="https://github.com/go-gitea/gitea/releases/download/v$GITEA_LATEST_VERSION/gitea-$GITEA_LATEST_VERSION-$GITEA_SYSTEM"
GITEA_SHA256_URL="$GITEA_BIN_URL.sha256"

log "Загрузка свежего бинарного файла..."
curl -fsSL "$GITEA_BIN_URL" -o "$GITEA_NEW_BIN_FILE"

log "Загрузка контрольной суммы для бинарного файла..."
curl -fsSL "$GITEA_SHA256_URL" -o "$GITEA_NEW_BIN_FILE.sha256"

log "Загрузка файлов успешно завершена"


#############################
# Проверка контрольной суммы
#############################

log "Проверка контрольной суммы для $GITEA_NEW_BIN_FILE..."

sha256sum -c "$(basename "$GITEA_SHA256_URL")" >/dev/null \
    || fail "Неудачная проверка контрольной суммы $GITEA_NEW_BIN_FILE"

log "Проверка контрольной суммы успешно завершена"


#######################
# Обновление бинарника
#######################

# Переименовываем бинарник в "gitea"
mv "$GITEA_NEW_BIN_FILE" gitea || \
    fail "Не удалось переименовать бинарный файл gitea-$GITEA_NEW_BIN_FILE в \"gitea\""

# Определяем рабочий каталог бинарника Gitea
GITEA_DIR=$(dirname "$GITEA_BIN_FILE")

# Коируем свежую версию бинарника из $TMP_DIR в рабочую директорию
mv -f "$TMP_DIR/gitea" "$GITEA_DIR" || fail "Не удалось установить свежий бинарный файл в рабочую директорию"

# Делаем бинарник исполняемым
chmod +x "$GITEA_BIN_FILE" || fail "Не удалось сделать бинарный файл исполняемым"

log "Свежий бинарный файл успешно установлен в рабочую директорию"

# Перепроверяем версию обновлённого бинарника
GITEA_CURRENT_VERSION="$("$GITEA_BIN_FILE" --version | awk '{print $3}')"

[[ -n "$GITEA_CURRENT_VERSION" ]] || fail "\"gitea --version\" вернула пустой результат"

[[ "$GITEA_CURRENT_VERSION" == "$GITEA_LATEST_VERSION" ]] || \
    fail "Версия обновлённого бинарного файла Gitea ($GITEA_CURRENT_VERSION) не соответствует актуальной ($GITEA_LATEST_VERSION)"

log "Обновление Gitea до версии $GITEA_LATEST_VERSION успешно завершено"
