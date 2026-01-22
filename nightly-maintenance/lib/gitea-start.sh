#!/usr/bin/env bash
# gitea-start.sh
# Скрипт перезапуска сервиса Gitea

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


###########################
# Перезапуск сервиса Gitea
###########################

log "Перезапуск сервиса Gitea..."

# Засекаем время запуска Gitea
gitea_start_timer=$SECONDS

# Запускаем Gitea, без блокировки выполнения скрипта (что бы цикл таймаута работал)
systemctl start --no-block gitea || fail "systemctl не смог запустить сервис Gitea"

MAX_WAIT=60 # максимальное время ожидания
timer=0

# Проверка HTTP-ответа от Gitea
while ! curl -sf http://127.0.0.1:3000 >/dev/null; do
    sleep 1
    ((timer++)) || true

    # Проверяем: истекло-ли время ожидания?
    if (( timer >= MAX_WAIT )); then
        fail "Сервис Gitea не ответил в течение $MAX_WAIT секунд"
    fi
done

# Вычисляем прошедшее время
gitea_start_timer=$(( SECONDS - gitea_start_timer ))

log "Сервис Gitea успешно запущен ($gitea_start_timer сек.)"
