#!/usr/bin/env bash
# config.sh
# Файл конфигурации для nightly-maintenance.sh


HDD_MOUNT_POINT="/var/hdd" # точка монтирования HDD для бэкапов


#########################
# Параметры логгирования
#########################

# УКАЗЫВАТЬ КАТАЛОГИ БЕЗ КОНЕЧНОГО СЛЕША!
LOG_DIR="/srv/sync/gitea-backup"
LOG_FILE="nightly_maintenance.log"
MAX_LOG_LINES=5000
LOG_CHOWN="user:user"
LOG_CHMOD="640"


##################
# Параметры Gitea
##################

# УКАЗЫВАТЬ КАТАЛОГИ БЕЗ КОНЕЧНОГО СЛЕША!
GITEA_SYSTEM="linux-arm64"
GITEA_USER="gitea"
GITEA_BIN_FILE="/usr/local/bin/gitea"
GITEA_CONFIG_FILE="/etc/gitea/app.ini"
GITEA_DB_FILE="/var/lib/gitea/gitea.db"
GITEA_GIT_DIR="/srv/repos/git" # исходные репозитории
GITEA_LFS_DIR="/srv/repos/lfs" # исходное LFS-хранилище
GITEA_LFS_BACKUP_DIR="/var/hdd/backup/git-lfs" # директория резервной копии LFS-хранилища
GITEA_DUMP_DIR="/srv/sync/gitea-backup"
GITEA_DUMP_NAME="gitea-dump" # только имя (без расширения!), таймстамп добавится автоматом
GITEA_DUMP_CHOWN="user:gitea"
GITEA_DUMP_CHMOD="660"
