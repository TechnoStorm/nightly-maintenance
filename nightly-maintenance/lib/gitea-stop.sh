#!/usr/bin/env bash
# gitea-stop.sh
# Скрипт остановки сервиса Gitea

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


##########################
# Остановка сервиса Gitea
##########################

log "Остановка сервиса Gitea..."

service_was_active=false # флаг начального стостояния сервиса

# Если сервис запущен - останавливаем его
if systemctl is-active --quiet gitea; then
    service_was_active=true
    systemctl stop gitea
fi


# Проверка остановки сервиса
MAX_WAIT=30 # максимальное время ожидания
timer=0
while systemctl is-active --quiet gitea; do
    sleep 1
    ((timer++))

    # Проверяем: истекло-ли время ожидания?
    if (( timer >= MAX_WAIT )); then
        fail "Остановка сервиса Gitea не удалась"
    fi
done


# Если gitea была остановлена до выполнения скрипта, то сообщаем об этом
if [[ "$service_was_active" = true ]]; then
    log "Сервис Gitea успешно остановлен за ${timer} секунд"
else
    log "Сервис Gitea был уже остановлен"
fi
