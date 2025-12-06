#!/usr/bin/env bash
# config.sh
# Файл конфигурации для nightly-maintenance.sh


HDD_MOUNT_POINT="/var/hdd"


#########################
# Параметры логгирования
#########################

# УКАЗЫВАТЬ КАТАЛОГИ БЕЗ КОНЕЧНОГО СЛЕША!
LOG_DIR="/home/user/sync/gitea-dumps"
LOG_FILE="nightly_maintenance.log"
MAX_LOG_LINES=200


##################
# Параметры Gitea
##################

# УКАЗЫВАТЬ КАТАЛОГИ БЕЗ КОНЕЧНОГО СЛЕША!
GITEA_USER="gitea"
GITEA_BIN_FILE="/usr/local/bin/gitea"
GITEA_CONFIG_FILE="/etc/gitea/app.ini"
GITEA_DB_FILE="/var/lib/gitea/gitea.db"
GITEA_GIT_DIR="/var/lib/gitea/git"
GITEA_LFS_DIR="/var/lib/gitea/lfs"
GITEA_LFS_BACKUP_DIR="git-lfs"
GITEA_DUMP_DIR="/home/user/sync/gitea-dumps"
GITEA_DUMP_NAME="gitea-dump" # только имя (без расширения!), таймстамп добавится автоматом
