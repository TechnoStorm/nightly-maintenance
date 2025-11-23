#!/usr/bin/env bash
# Скрипт резервного копирования данных Gitea

log "Начато резервное копирование Gitea..."


### Останавливаем Gitea ###

# если сервис запущен - останавливаем его
if systemctl is-active --quiet gitea; then
    systemctl stop gitea
fi


# проверка остановки сервиса
MAX_WAIT=30 # макс. время ожидания остановки gitea
timer=0
while systemctl is-active --quiet gitea; do
    sleep 1
    ((timer++))
    # проверяем: истекло-ли время ожидания?
    if (( timer >= MAX_WAIT )); then
        log "ОШИБКА: Остановка Gitea не удалась"
        log "Прерывание сценария резервного копирования Gitea"
        exit 1
    fi
done

# если gitea была остановлена до выполнения скрипта, то сообщаем об этом
if (( timer == 0 )); then
    log "Gitea была уже остановлена"
else
    log "Gitea успешно остановлена за ${timer} секунд"
fi
