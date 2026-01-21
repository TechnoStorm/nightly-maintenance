#!/usr/bin/env bash
# functions.sh
# Скрипт определения функций

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


######################
# Определение функций
######################

# Функция логгирования
log() {
    local msg="[$(date '+%F %T')] $*"
    echo "$msg" >> "$LOG_FILE"
    echo "$msg"
}


# Функция ошибки выполнения скрипта
fail() {
    log "[ERROR]: $*"
    log "Сценарий ночного техобслуживания NAS прерван"
    exit 1
}


# Функция проверки свободного места
check_free_space() {

    local storage_type="${1-}"
    local path="${2-}" # путь проверки свободного места
    local min_gb="${3-}" # минимальное свободное место (GB)

    # Проверки аргументов
    [[ -z "$storage_type" || -z "$path" || -z "$min_gb" ]] && \
        fail "В функцию check_free_space() переданы не все аргументы"
    [[ -e "$path" ]] || \
        fail "Путь переданный в функцию check_free_space() не существует"

    # Определяем свободное место
    local free_gb
    free_gb=$(LC_ALL=C df -BG "$path" | awk 'NR==2 {gsub("G","",$4); print $4}')

    [[ -n "$free_gb" ]] || fail "Не удалось определить свободное место на $storage_type"

    # Проверяем: достаточно-ли свободного места для продолжения выполнения сценария?
    if (( free_gb < min_gb )); then
        fail "Недостаточно свободного места на $storage_type: $free_gb GB"
    fi

    log "Оставшееся свободное место на $storage_type: $free_gb GB"
}


# Функция ротации дамп-файлов
dump_rotate() {

    log "Ротация дампов..."

    [[ -d "$TMP_DIR" ]] || fail "Ротация дампов не удалась - $TMP_DIR не обнаружена"

    # Формируем массив имён дампов
    mapfile -t dumps < <(
        find "$GITEA_DUMP_DIR" \
            -maxdepth 1 \
            -type f \
            -name 'gitea-dump_*' \
            -printf '%f\n' \
        | sort
    )

     # Получаем количество найденных файлов
    local dump_count="${#dumps[@]}"

    # Вычисляем, сколько дампов нужно удалить
    local remove_count=$(( dump_count - GITEA_MAX_DUMPS ))

    # Проверяем, что количество дампов не нулевое
    # Проверяем, что выражение "dump_count - GITEA_MAX_DUMPS" не стало отрицательным
    if (( dump_count == 0 || remove_count <=0 )); then
        log "Ротация дампов не требуется"
        return 0
    fi

    # Удаляем старые дампы
    for (( i=0; i<remove_count; i++ )); do
        local dump_to_remove="$GITEA_DUMP_DIR/${dumps[i]}"
        rm -f -- "$dump_to_remove" || fail "Не удалось удалить: $dump_to_remove"
        log "Удалён дамп: ${dumps[i]}"
    done

    log "Ротация дампов успешно завершена"
}

# Функция ротации лога (удаляются все строки, кроме последних $MAX_LOG_LINES)
log_rotate() {
    if [[ -f "$LOG_FILE" ]]; then

        # Отменяем ротацию, если лог не длинней $MAX_LOG_LINES
        (( $(wc -l < "$LOG_FILE") > $MAX_LOG_LINES )) || return 0

        [[ -d "$TMP_DIR" ]] || fail "Ротация лога не удалась - $TMP_DIR не обнаружена"

        # Создаём временный файл лога, с уникальным именем
        local tmp_log
        tmp_log=$(mktemp "$TMP_DIR/temp_log.XXXXXX") || fail "Не удалось создать временный log-файл для обрезки лога"

        # Сохраняем последние $MAX_LOG_LINES строк во временный файл
        if tail -n "$MAX_LOG_LINES" "${LOG_FILE}" > "$tmp_log"; then

            # Переназначаем владельца и права лог-файла
            chown "$LOG_CHOWN" "$tmp_log" || fail "Не удалось переназначить владельца и группу временного лог-файла"
            chmod "$LOG_CHMOD" "$tmp_log" || fail "Не удалось переназначить права доступа временного лог-файла"

            # Заменяем старый лог-файл на новый
            mv -f "$tmp_log" "${LOG_FILE}" || fail "При обрезке лога не удалось заменить старый лог-файл обновлённым"
        else
            # Удаляем временный лог
            rm -f "$tmp_log"
            fail "Обрезка лога не удалась"
        fi
    fi
}
