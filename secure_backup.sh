#!/usr/bin/env bash

set -euo pipefail

DATE=$(date +%Y-%m-%d_%H-%M-%S)
FILENAME="backup_$DATE.tar.gz"
BACKUP_FILE=$FILENAME

# ------------------------- HELPERS -------------------------

function usage {
  echo "Usage: $0 -s source -r destination [-e] [-k ssh_key] [-g gpg_key] [-t tmp_dir] [-c]"
  exit 1
}

function helpmessage {
  cat << EOF
Usage: $0 -s <source> -r <remote> -t <tmp_dir> [options]

Creates a compressed (and optionally encrypted) backup, transferred via rsync or rclone.

Required:
  -s  Source directory
  -r  Remote destination (rsync: user@host:/path or rclone: remote:path)
  -t  Temporary directory for working files

Optional:
  -e  Enable GPG encryption
  -g  GPG public key ID (required if -e is used)
  -k  SSH key for rsync
  -c  Use rclone instead of rsync
  -h  Display this help message
EOF
  exit 0
}

# ---------------------- CORE ACTIONS -----------------------

compress_backup() {
  echo "📦 Compressing $SRC_DIR into $TMP_DIR/$FILENAME..."
  tar -czf "$TMP_DIR/$FILENAME" -C "$(dirname "$SRC_DIR")" "$(basename "$SRC_DIR")"
}

encrypt_backup() {
  echo "🔐 Encrypting backup with GPG key: $GPG_KEY"
  gpg -r "$GPG_KEY" -e "$TMP_DIR/$FILENAME"
  FILENAME="$FILENAME.gpg"
}

transfer_backup_rsync() {
  echo "🚀 Transferring via rsync to $REMOTE_TARGET..."
  local ssh_opts="ssh -o BatchMode=yes"
  [[ -n "${SSH_KEY:-}" ]] && ssh_opts+=" -i $SSH_KEY"

  rsync -a -e "$ssh_opts" "$TMP_DIR/$FILENAME" "$REMOTE_TARGET"
}

transfer_backup_rclone() {
  echo "☁️ Transferring via rclone to $REMOTE_TARGET..."
  rclone copy "$TMP_DIR/$FILENAME" "$REMOTE_TARGET"
}

clean_up() {
  echo "🧹 Cleaning up temporary files..."
  rm -f "$TMP_DIR/$FILENAME" "$TMP_DIR/$BACKUP_FILE"
}

# ------------------------- ARG PARSING -------------------------

while getopts "s:r:k:t:g:ceh" opt; do
  case "$opt" in
    s) SRC_DIR="$OPTARG" ;;
    r) REMOTE_TARGET="$OPTARG" ;;
    k) SSH_KEY="$OPTARG" ;;
    t) TMP_DIR="$OPTARG" ;;
    g) GPG_KEY="$OPTARG" ;;
    e) ENCRYPTION=true ;;
    c) CLOUD=true ;;
    h) helpmessage ;;
    *) usage ;;
  esac
done

# --------------------- VALIDATION CHECKS ----------------------

[[ -z "${SRC_DIR:-}" || -z "${REMOTE_TARGET:-}" || -z "${TMP_DIR:-}" ]] && {
  echo "❌ Missing required options: -s, -r, -t"
  usage
}

command -v tar &>/dev/null || { echo "Error: 'tar' not found."; exit 1; }
command -v rsync &>/dev/null || { echo "Error: 'rsync' not found."; exit 1; }

if [[ "${ENCRYPTION:-}" == true ]]; then
  [[ -z "${GPG_KEY:-}" ]] && { echo "❌ GPG key (-g) is required for encryption."; exit 1; }
  command -v gpg &>/dev/null || { echo "Error: 'gpg' not found."; exit 1; }
fi

if [[ "${CLOUD:-}" == true ]]; then
  command -v rclone &>/dev/null || { echo "Error: 'rclone' not found."; exit 1; }
fi

# ------------------------- MAIN LOGIC -------------------------

compress_backup

[[ "${ENCRYPTION:-}" == true ]] && encrypt_backup

if [[ "${CLOUD:-}" == true ]]; then
  transfer_backup_rclone
else
  transfer_backup_rsync
fi

clean_up

echo "✅ Backup completed successfully."
