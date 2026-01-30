#!/usr/bin/env bash
# config.sh
# Файл конфигурации для nightly-maintenance.sh

SSD_MIN_FREE_SPACE=20 # минимальное свободное место на SSD (GB)
HDD_MIN_FREE_SPACE=20 # минимальное свободное место на HDD (GB)
HDD_MOUNT_POINT="/srv/hdd" # точка монтирования HDD для бэкапов


#########################
# Параметры логгирования
#########################

# УКАЗЫВАТЬ КАТАЛОГИ БЕЗ КОНЕЧНОГО СЛЕША!
LOG_FILE="/srv/sync/gitea-backups/nightly-maintenance.log"
MAX_LOG_LINES=5000
LOG_CHOWN="user:user"
LOG_CHMOD=640


################################################
# Параметры зеркалирования директории Syncthing
################################################

# УКАЗЫВАТЬ КАТАЛОГИ БЕЗ КОНЕЧНОГО СЛЕША!
SYNC_DIR="/srv/sync"
SYNC_BACKUP_DIR="/srv/hdd/backup/sync"


##################
# Параметры Gitea
##################

# УКАЗЫВАТЬ КАТАЛОГИ БЕЗ КОНЕЧНОГО СЛЕША!
GITEA_SYSTEM="linux-arm64"
GITEA_USER="gitea"
GITEA_BIN_FILE="/usr/local/bin/gitea"
GITEA_CONFIG_FILE="/etc/gitea/app.ini"
GITEA_DB_FILE="/var/lib/gitea/data/gitea.db"
GITEA_GIT_DIR="/srv/repos/git" # исходные репозитории
GITEA_LFS_DIR="/srv/repos/lfs" # исходное LFS-хранилище
GITEA_GIT_BACKUP_DIR="/srv/hdd/backup/git" # директория резервной копии Git-репозиториев
GITEA_LFS_BACKUP_DIR="/srv/hdd/backup/lfs" # директория резервной копии LFS-хранилища
GITEA_DUMP_DIR="/srv/sync/gitea-backups" # директория для дампов Gitea
GITEA_DUMP_NAME="gitea-dump" # только имя (без расширения!), таймстамп добавится автоматом
GITEA_DUMP_CHOWN="user:user"
GITEA_DUMP_CHMOD=660
GITEA_MAX_DUMPS=30
