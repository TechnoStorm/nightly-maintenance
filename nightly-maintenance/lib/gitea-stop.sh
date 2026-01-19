#!/usr/bin/env bash
# gitea-stop.sh
# Скрипт остановки сервиса Gitea

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


##########################
# Остановка сервиса Gitea
##########################

log "Остановка сервиса Gitea..."

# Засекаем время остановки Gitea
gitea_stop_timer=$SECONDS

# Останавливаем Gitea, без блокировки выполнения скрипта (что бы цикл таймаута работал)
systemctl stop --no-block gitea

MAX_WAIT=60 # максимальное время ожидания
timer=0

# Проверка остановки сервиса
while systemctl is-active --quiet gitea; do
    sleep 1
    ((timer++)) || true # обязательно возвращаем true, во избежание краша

    # Проверяем: истекло-ли время ожидания?
    if (( timer >= MAX_WAIT )); then
        fail "Остановка сервиса Gitea не удалась"
    fi
done

# Вычисляем прошедшее время
gitea_stop_timer=$(( SECONDS - gitea_stop_timer ))

log "Сервис Gitea успешно остановлен ($gitea_stop_timer sec.)"
