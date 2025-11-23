#!/usr/bin/env bash
# Скрипт ночного техобслуживания NAS

# принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


# читаем конфиг
source ./config.sh


######################
# Определение функций
######################

# функция логгирования
log() {

    local msg="[$(date '+%F %T')] $*"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg"
}


# функция обрезки лога
# (удаляются все строки, кроме последних $MAX_LOG_LINES)
trim_log() {
    if [[ -f "$LOG_FILE" ]]; then

        # создаём временный файл лога, с уникальным именем
        local tmp_file="${LOG_FILE}.tmp.$$"

        if tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "$tmp_file"; then
            mv -f "$tmp_file" "$LOG_FILE"
        else
            rm -f "$tmp_file"
            log "ОШИБКА: Обрезка лога не удалась"

            # не прерываем скрипт через "exit 1",
            # так-как функция всё равно выполняется в самом конце
        fi
    fi
}
