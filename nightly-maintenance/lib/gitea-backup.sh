#!/usr/bin/env bash
# gitea-backup.sh
# Скрипт резервного копирования данных Gitea

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


log "Начало резервного копирования Gitea..."

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
DOCTOR_CHECK_RESULT=$(sudo -u "$GITEA_USER" "$GITEA_BIN_FILE" doctor check -c "$GITEA_CONFIG_FILE")

# Парсим вывод docktor check на наличие ошибок: [E]
if grep -Eq "\[E\]" <<< "$DOCTOR_CHECK_RESULT"; then
    log "$DOCTOR_CHECK_RESULT"
    fail "Проверка \"gitea doctor check\" вернула ошибки или предупреждения"
fi

# Парсим вывод docktor check на наличие предупреждений: [W]
if grep -Eq "\[W\]" <<< "$DOCTOR_CHECK_RESULT"; then
    log "$DOCTOR_CHECK_RESULT"
fi

log "Проверка общей согласованности данных Gitea успешно завершена"


##########################################
# Проверка целостности репозиториев Gitea
##########################################

# Получаем массив путей всех репозиториев (если они есть)
shopt -s nullglob
repos=("$GITEA_GIT_DIR"/*/*)
shopt -u nullglob

log "Проверка целостности репозиториев Gitea..."

if (( ${#repos[@]} > 0 )); then

    # Засекаем время проверки репозиториев
    git_fsck_timer=$SECONDS

    all_repos_ok=true # флаг целостности всех репозиториев

    # Запускаем цикл проверки
    for repo in "${repos[@]}"; do

        # Если это директория, то...
        if [[ -d "$repo" ]]; then

            # ...проверяем, что это bare-репозиторий
            if sudo -u "$GITEA_USER" git -C "$repo" rev-parse --is-bare-repository &>/dev/null; then

                log "Проверка репозитория: $repo"

                # Проверяем целостность текущего репозитория
                if sudo -u "$GITEA_USER" git -C "$repo" fsck --full >> "$LOG_FILE" 2>&1; then
                    log "Репозиторий $repo в порядке"
                else
                    log "[ERROR]: Репозиторий $repo повреждён"
                    all_repos_ok=false
                fi
            fi
        fi
    done

    # Итог проверки
    if [[ $all_repos_ok = true ]]; then

        # Вычисляем время проверки
        git_fsck_timer=$(( SECONDS - git_fsck_timer )) # общее количество секунд ушедших на проверку
        git_fsck_minutes=$(( git_fsck_timer / 60 ))
        git_fsck_seconds=$(( git_fsck_timer % 60 ))

        if (( git_fsck_minutes == 0 )); then
            log "Проверка репозиториев Gitea успешно завершена ($git_fsck_seconds сек.)"
        else
            log "Проверка репозиториев Gitea успешно завершена ($git_fsck_minutes мин. $git_fsck_seconds сек.)"
        fi
    else
        fail "Обнаружены повреждённые репозитории Gitea"
    fi
else
    log "Репозитории Gitea не обнаружены"
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

# Переназначаем владельца и группу созданного дамп-файла
chown "$GITEA_DUMP_CHOWN" "$GITEA_DUMP_DIR/${GITEA_DUMP_NAME}_${DUMP_TIMESTAMP}.zip" ||
    fail "Не удалось изменить владельца и группу для $GITEA_DUMP_DIR/${GITEA_DUMP_NAME}_${DUMP_TIMESTAMP}.zip"

# Переназначаем права созданного дамп-файла
chmod "$GITEA_DUMP_CHMOD" "$GITEA_DUMP_DIR/${GITEA_DUMP_NAME}_${DUMP_TIMESTAMP}.zip" ||
    fail "Не удалось изменить права доступа для $GITEA_DUMP_DIR/${GITEA_DUMP_NAME}_${DUMP_TIMESTAMP}.zip"

# Выполняем ротацию дампов
dump_rotate


##################################
# Зеркалирование Git-репозиториев
##################################

log "Зеркалирование Git-репозиториев..."

# Выполняем зеркалирование
if rsync -aH --delete --numeric-ids --stats \
    "$GITEA_GIT_DIR"/ \
    "$GITEA_GIT_BACKUP_DIR"/ \
    >> "$LOG_FILE" 2>&1; then

    echo "" >> "$LOG_FILE" # отступ
    log "Зеркалирование Git-репозиториев успешно завершено"
else
    fail "Ошибка выполнения зеркалирования средствами rsync"
fi


###############################
# Зеркалирование LFS-хранилища
###############################

log "Зеркалирование LFS-хранилища..."

# Выполняем зеркалирование
if rsync -aH --delete --numeric-ids --stats \
    "$GITEA_LFS_DIR"/ \
    "$GITEA_LFS_BACKUP_DIR"/ \
    >> "$LOG_FILE" 2>&1; then

    echo "" >> "$LOG_FILE" # отступ
    log "Зеркалирование LFS-хранилища успешно завершено"
else
    fail "Ошибка выполнения зеркалирования средствами rsync"
fi

log "Резервное копирование данных Gitea успешно завершено"
