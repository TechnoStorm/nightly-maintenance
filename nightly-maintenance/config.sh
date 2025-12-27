#!/usr/bin/env bash
# config.sh
# Файл конфигурации для nightly-maintenance.sh


HDD_MOUNT_POINT="/var/hdd"


#########################
# Параметры логгирования
#########################

# УКАЗЫВАТЬ КАТАЛОГИ БЕЗ КОНЕЧНОГО СЛЕША!
LOG_DIR="/srv/sync/gitea-dumps"
LOG_FILE="nightly_maintenance.log"
MAX_LOG_LINES=5000


##################
# Параметры Gitea
##################

# УКАЗЫВАТЬ КАТАЛОГИ БЕЗ КОНЕЧНОГО СЛЕША!
GITEA_SYSTEM="linux-amd64"
GITEA_USER="gitea"
GITEA_BIN_FILE="/usr/local/bin/gitea"
GITEA_CONFIG_FILE="/etc/gitea/app.ini"
GITEA_DB_FILE="/var/lib/gitea/gitea.db"
GITEA_GIT_DIR="/srv/repos/git"
GITEA_LFS_DIR="/srv/repos/lfs"
GITEA_LFS_BACKUP_DIR="/var/hdd/backup/git-lfs"
GITEA_DUMP_DIR="/srv/sync/gitea-dumps"
GITEA_DUMP_NAME="gitea-dump" # только имя (без расширения!), таймстамп добавится автоматом
GITEA_BIN_BACKUP_DIR="/srv/sync/gitea-dumps"
