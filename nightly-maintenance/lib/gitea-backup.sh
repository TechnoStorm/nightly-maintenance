#!/usr/bin/env bash
# gitea-backup.sh
# Скрипт резервного копирования данных Gitea


#########################################
# Проверка целостности базы данных Gitea
#########################################

log "Проверка целостности SQLite-базы Gitea..."

SQLITE_RESULT=$(sqlite3 "$GITEA_DB_FILE" "PRAGMA integrity_check;" 2>&1)

if [[ "$SQLITE_RESULT" != "ok" ]]; then

    # Построчно выводим журнал ошибок $SQLITE_RESULT
    while IFS=read -r line; do
        log "$line"
    done <<< "$SQLITE_RESULT"

    fail "SQLite-база данных Gitea нарушена"
fi

log "Целостность SQLite-базы Gitea не нарушена"


##############################################
# Проверка общей согласованности данных Gitea
##############################################

log "Проверка общей согласованности данных Gitea..."

# Выполняем docktor check, сохраняя его вывод
output=$(sudo -u "$GITEA_USER" "$GITEA_BIN_FILE" doctor check -c "$GITEA_CONFIG_FILE")
echo "$output"

# Парсим вывод docktor check на наличие ошибок и предупреждений
if echo "$output" | grep -Eq "\[E\]|\[W\]"; then
    fail "docktor check вернул ошибки или предупреждения (перезапустить скрипт вручную и проверить вывод в терминал)"
fi

log "Проверка общей согласованности данных Gitea успешно завершена"


##########################################
# Проверка целостности репозиториев Gitea
##########################################

log "Проверка целостности репозиториев Gitea..."

all_repos_ok=true # флаг целостности всех репозиториев

for repo in "$GITEA_GIT_DIR"/*/*; do

    # Если это директория, то...
    if [[ -d "$repo" ]]; then

        # ...проверяем, что это bare-репозиторий
        if sudo -u "$GITEA_USER" git -C "$repo" rev-parse --is-bare-repository &>/dev/null; then

            log "Проверка репозитория: $repo"

            # Проверяем целостность текущего репозитория
            if sudo -u "$GITEA_USER" git -C "$repo" fsck --full --strict >> "$LOG_DIR/$LOG_FILE" 2>&1; then
                log "Репозиторий $repo в порядке"
            else
                log "ERROR: Репозиторий $repo повреждён"
                all_repos_ok=false
            fi
        fi
    fi
done

# Итог проверки
if [[ $all_repos_ok = true ]]; then
    log "Проверка репозиториев Gitea успешно завершена"
else
    fail "Обнаружены повреждённые репозитории Gitea"
fi


#######################
# Создание дампа Gitea
#######################

log "Создание дампа Gitea..."

DUMP_TIMESTAMP=$(date +%F_%H_%M_%S)

# Делаем дамп gitea, игнорируя LFS-хранилище
# Логгируем только ошибки ошибки
# Запускаем НЕ от root, так как root отклоняется самой gitea
if sudo -u "$GITEA_USER" "$GITEA_BIN_FILE" dump \
    -c "$GITEA_CONFIG_FILE" \
    --skip-lfs-data \
    --quiet \
    --file "$GITEA_DUMP_DIR/${GITEA_DUMP_NAME}_${DUMP_TIMESTAMP}.zip"
then
    log "Создание дампа Gitea успешно завершено"
else
    fail "Создание дампа Gitea не удалось"
fi


###############################
# Зеркалирование LFS-хранилища
###############################

log "Зеркалирование LFS-хранилища..."

# Выполняем зеркалирование
if rsync -aH --delete --stats \
    "$GITEA_LFS_DIR"/ \
    "$GITEA_LFS_BACKUP_DIR"/ \
    >> "$LOG_DIR/$LOG_FILE" 2>&1; then

    log "Зеркалирование LFS-хранилища успешно завершено"
else
    fail "rsync завершился с ошибкой -- LFS-хранилище НЕ синхронизировано"
fi
