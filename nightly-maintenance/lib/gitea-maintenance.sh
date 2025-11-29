#!/usr/bin/env bash
# Скрипт ночного техобслуживания Gitea

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


##################
# Остановка Gitea
##################

log "Остановка сервиса Gitea..."

# Если сервис запущен - останавливаем его
if systemctl is-active --quiet gitea; then
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
if (( timer == 0 )); then
    log "Сервис Gitea был уже остановлен"
else
    log "Сервис Gitea успешно остановлен за $timer секунд"
fi


##################################################
# Резервное копирование данных и обновление Gitea
##################################################

source "$BASE_DIR/lib/gitea-backup.sh"

source "$BASE_DIR/lib/gitea-update.sh"


###################
# Перезапуск Gitea
###################

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
fi

log "Сервис Gitea успешно запущен за $timer секунд"
