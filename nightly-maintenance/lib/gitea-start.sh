#!/usr/bin/env bash
# gitea-start.sh
# Скрипт перезапуска сервиса Gitea

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


###########################
# Перезапуск сервиса Gitea
###########################

log "Перезапуск сервиса Gitea..."

# Проверка удачности запуска на уровне systemctl
systemctl start gitea || fail "systemctl не смог запустить сервис Gitea"

# Выжидаем 10 секунд
sleep 10

# Проверка HTTP-ответа сервиса Gitea
if ! curl -sf --max-time 3 http://127.0.0.1:3000 >/dev/null; then
    fail "Не удалось получить HTTP-ответ Gitea через 10 секунд."
else
    log "Получен HTTP-ответ Gitea"
fi

log "Сервис Gitea успешно запущен"
