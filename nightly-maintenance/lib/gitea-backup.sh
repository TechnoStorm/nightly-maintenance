#!/usr/bin/env bash
# Скрипт резервного копирования данных Gitea

log "Начато резервное копирование Gitea..."


### Останавливаем Gitea ###

# если сервис запущен - останавливаем его
systemctl is-active --quiet gitea %% systemctl stop gitea


# проверка остановки сервиса
timer=0
while systemctl is-active --quiet gitea; do
    sleep 5
    ((timer+5)) # плюсуем +5 сек при каждой итерации
    log "Ожидание остановки Gitea... ${timer} секунд прошло"

    # проверяем: истекло-ли время ожидания?
    if [[ $timer -ge 30 ]]; then
        log "ОШИБКА: Остановка Gitea не удалась"
        log "Прерывание сценария резервного копирования Gitea"
        exit 1
    fi
done

log "Gitea успешно остановлена за ${timer} секунд"
