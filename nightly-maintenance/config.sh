#!/usr/bin/env bash
# Файл конфигурации для nightly-maintenance.sh


#########################
# Параметры логгирования
#########################

LOG_DIR="/home/user/sync/nas-backup/"
LOF_FILE="$LOG_DIR/"
MAX_LOG_LINES=200


##################
# Параметры Gitea
##################

GITEA_DB_FILE="/var/lib/gitea/gitea.db"
GITEA_GIT_DIR="/var/lib/gitea/git"
GITEA_LFS_DIR="/var/lib/gitea/lfs"
