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
if ! systemctl start gitea; then
    fail "systemctl не смог запустить сервис Gitea"
fi


# Проверка удачности запуска на уровне сервиса
timer=0
while ! systemctl is-active --quiet gitea; do
    sleep 1
    ((timer++))

    # Проверяем: истекло-ли время ожидания?
    if (( timer >= MAX_WAIT )); then
        fail "Перезапуск сервиса Gitea не удался"
    fi
done

log "Сервис Gitea успешно запущен за ${timer} секунд"
