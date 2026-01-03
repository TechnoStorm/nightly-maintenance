#!/usr/bin/env bash
# gitea-stop.sh
# Скрипт остановки сервиса Gitea

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


##########################
# Остановка сервиса Gitea
##########################

# Если сервис запущен - останавливаем его
if systemctl is-active --quiet gitea; then
    log "Остановка сервиса Gitea..."
    systemctl stop gitea
else
    return 0
fi


# Проверка остановки сервиса
MAX_WAIT=30 # максимальное время ожидания
timer=0

while systemctl is-active --quiet gitea; do
    sleep 1
    ((timer++)) || true # обязательно возвращаем true, во избежание краша

    # Проверяем: истекло-ли время ожидания?
    if (( timer >= MAX_WAIT )); then
        fail "Остановка сервиса Gitea не удалась"
    fi
done

log "Сервис Gitea успешно остановлен за ${timer} секунд"
