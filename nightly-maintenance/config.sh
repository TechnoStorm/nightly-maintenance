#!/usr/bin/env bash
# Файл конфигурации для nightly-maintenance.sh


#########################
# Параметры логгирования
#########################

# УКАЗЫВАТЬ КАТАЛОГИ БЕЗ КОНЕЧНОГО СЛЕША!
LOG_DIR="/home/user/sync/gitea-backup"
LOG_FILE="$LOG_DIR"
MAX_LOG_LINES=200


##################
# Параметры Gitea
##################

# УКАЗЫВАТЬ КАТАЛОГИ БЕЗ КОНЕЧНОГО СЛЕША!
#GITEA_DIR="/var/lib/gitea"
GITEA_BIN_FILE="/usr/local/bin/gitea"
GITEA_CONFIG_FILE="/etc/gitea/app.ini"
GITEA_DB_FILE="/var/lib/gitea/gitea.db"
GITEA_GIT_DIR="/var/lib/gitea/git"
GITEA_LFS_DIR="/var/lib/gitea/lfs"
GITEA_LFS_BACKUP_DIR="/var/hdd/git-lfs"
GITEA_DUMP_DIR="/home/user/sync/gitea-backup"
GITEA_DUMP_NAME="gitea-dump"$(date +"%F_%H_%M_%S")".zip"
