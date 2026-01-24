#!/usr/bin/env bash
# cleaner.sh
# Скрипт очистки бэкапов NAS

# Принудительно прерываем скрипт при ошибках, и неинициализированных переменных
set -euo pipefail


#############################
# Скрипт очистки бэкапов NAS
#############################


# Определяем абсолютный путь текущего скрипта
BASE_DIR="$(dirname "$(readlink -f "$0")")"

# Читаем конфиг
source "$BASE_DIR/config.sh"


###############
# Меню скрипта
###############

# Функция вычисления разницы по весу
size_diff() {
    local src="$1"
    local bcp="$2"
    local type="$3"

    if [[ ! -d "$src" ]]; then
        echo "[ERROR]: Исходная директория не найдена: $src"
        exit 1
    fi

    if [[ ! -d "$bcp" ]]; then
        echo "[ERROR]: Директория бэкапа не найдена: $bcp"
        exit 1
    fi

    local src_size bcp_size size_diff
    src_size=$(du -sb "$src" | awk '{print $1}')
    bcp_size=$(du -sb "$bcp" | awk '{print $1}')
    size_diff=$(( src_size - bcp_size ))

    echo "$type-исходник   : $src_size байт ($(numfmt --to=iec $src_size))"
    echo "$type-бэкап      : $bcp_size байт ($(numfmt --to=iec $bcp_size))"
    echo "Мусор          : $size_diff байт ($(numfmt --to=iec $size_diff))"
}

clear

echo "Скрипт очистки бэкапов NAS"
echo
echo "-----------------------------------"
size_diff "$GITEA_GIT_DIR" "$GITEA_GIT_BACKUP_DIR" "Git"
echo "-----------------------------------"
size_diff "$GITEA_LFS_DIR" "$GITEA_LFS_BACKUP_DIR"  "LFS"
echo "-----------------------------------"
echo
echo "Выберите цель очистки:"
echo "1 - Git-репозитории"
echo "2 - LFS-хранилище"
echo "3 - Выход"
echo
echo

read -rp "Введите номер: " choice

case "$choice" in
    1) TARGET="GIT" ;;
    2) TARGET="LFS" ;;
    3) TARGET="EXIT" ;;
    *) echo; echo "[ERROR]: Неверный выбор"; exit 1 ;;
esac

if [[ "$TARGET" == "EXIT" ]]; then
    echo
    echo "Выход из скрипта"
    exit 0
fi

echo
echo "Вы выбрали: $TARGET"
echo

read -rp "Вы уверены, что хотите начать очистку (N/y)?" confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo
    echo "Очистка отменена"
    exit 0
fi


##########################
# Процесс очистки бэкапов
##########################

# Функция очистки
clean() {
    local src="$1"
    local bcp="$2"

    if [[ ! -d "$src" ]]; then
        echo "[ERROR]: Исходная директория не найдена: $src"
        exit 1
    fi

    if [[ ! -d "$bcp" ]]; then
        echo "[ERROR]: Директория бэкапа не найдена: $bcp"
        exit 1
    fi

    echo "Начат процесс очиски: $bcp"

    if ! rsync -aH --ignore-existing --delete --stats --dry-run "$src/" "$bcp/"; then
        echo "[ERROR]: Ошибка выполнения Rsync"
        exit 1
    fi
}

case "$TARGET" in
    GIT) clean "$GITEA_GIT_DIR" "$GITEA_GIT_BACKUP_DIR";;
    LFS) clean "$GITEA_LFS_DIR" "$GITEA_LFS_BACKUP_DIR";;
esac

echo "Процесс очистки завершён"
echo
