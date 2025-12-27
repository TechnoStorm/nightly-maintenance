#!/usr/bin/env bash
#gitea-update.sh
# Скрипт ообновления Gitea

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


####################################
# Проверка наличия обновлений Gitea
####################################

log "Проверка наличия обновлений Gitea..."

# Узнаём текущую версию бинарника Gitea
GITEA_CURRENT_VERSION="$("$GITEA_BIN_FILE" --version | awk '{print $3}')" || fail "\"gitea --version\" завершилась с ошибкой"


if [ -n "$GITEA_CURRENT_VERSION" ]; then
    log "Текущая версия Gitea: $GITEA_CURRENT_VERSION"
else
    fail "\"gitea --version\" вернула пустой результат"
fi


