#!/usr/bin/env bash
DATE=$(date +%Y-%m-%d_%H-%M-%S)
FILE="backup_$DATE.tar.gz"
BACKUP_FILE=$FILE
function usage
 {
  echo "Usage: $0 -s source -r destination [-e] [-k ssh_key] [-g gpg_key] [-t tmp_dir] [-c]"
  exit 1
}

function helpmessage
 {
  echo "This script creates compressed and optionally encrypted backups, then sends them using rsync or rclone (for cloud)."
  echo "Options:"
  echo "  -s  Source path (required)"
  echo "  -r  Remote destination in the format user@host:/path or provider:path for cloud (required)"
  echo "  -e  Encrypt the backup using GPG (optional)"
  echo "  -k  Path to SSH key for rsync (optional)"
  echo "  -g  GPG public key ID (optional)"
  echo "  -t  Temporary working directory (required)" 
  echo "  -c  Use cloud transfer (rclone) instead of rsync (optional)"
  echo "  -h  Show this help message"
  exit 0
}


function compression
{
    if ! tar -czf "$TMP_DIR/$FILE" -C "$(dirname "$SRC_DIR")" "$(basename "$SRC_DIR")";
    then
        echo "-----The script failed at the compression stage, please check the directories names-----"
    fi
}

function encryption 
{
    if ! gpg -r "$GPG_KEY" -e "$TMP_DIR/$FILE";
    then
        echo "-----The script failed at the encryption stage-----"
        exit 1
    fi
    FILE="$FILE.gpg"
}

function backup_on_remote
{
    if [ -z "$SSH_KEY" ]; 
    then
       if  rsync -a -e "ssh -o BatchMode=yes" "$TMP_DIR"/"$FILE" "$REMOTE_TARGET";
       then
            echo "-----operation successful-----"
        else 
            echo "-----The script failed at the transfer stage-----"
            exit 1
        fi
    else
       if  rsync -a -e "ssh -i $SSH_KEY -o BatchMode=yes" "$TMP_DIR"/"$FILE" "$REMOTE_TARGET";
        then
            echo "-----operation successful-----"
        else 
            echo "-----The script failed at the transfer stage-----"
            exit 1
        fi
    fi 
}

function backup_on_cloud 
{
   if  rclone copy "$TMP_DIR"/"$FILE" "$REMOTE_TARGET";
   then
        echo "-----operation successful-----"
    else 
        echo "-----The script failed at the transfer stage-----"
            exit 1
    fi
}

function clean_up
{
    [ -f "$TMP_DIR"/"$FILE" ] && rm "$TMP_DIR"/"$FILE"
    [ -f "$TMP_DIR"/"$BACKUP_FILE"  ] && rm "$TMP_DIR"/"$BACKUP_FILE"
}

#Start Menu
while getopts "s:r:k:t:g:ceh" opt; do
  case "$opt" in
    s) SRC_DIR="$OPTARG" ;;      
    r) REMOTE_TARGET="$OPTARG" ;;  
    k) SSH_KEY="$OPTARG" ;; 
    t) TMP_DIR="$OPTARG" ;; 
    g) GPG_KEY="$OPTARG" ;;
    e) ENCRYPTION=TRUE ;;
    c) CLOUD=TRUE ;;
    h) helpmessage ;;
    \?) usage ;;
  esac
done

# Check requirements
for cmd in tar rsync; do
  command -v $cmd >/dev/null 2>&1 || { echo "Error: $cmd is not installed."; exit 1; }
done

if [ "$ENCRYPTION" = "TRUE" ]; then
  command -v gpg >/dev/null 2>&1 || { echo "Error: gpg is not installed."; exit 1; }
fi

if [ "$CLOUD" = "TRUE" ]; then
  command -v rclone >/dev/null 2>&1 || { echo "Error: rclone is not installed."; exit 1; }
fi

# Start the main function

if [ -z "$1" ]; then
    usage
fi
if [ -z "$SRC_DIR" ] || [ -z "$REMOTE_TARGET" ] || [ -z "$TMP_DIR" ]; then
  echo "Error: -s, -r and -t are required"
  exit 1
fi

# Calling the compression funtion
compression

# Check the encryption flag and call the function if needed
if [ "$ENCRYPTION" = "TRUE" ]; then
    if [ -n "$GPG_KEY" ]; then
        encryption
    else
        echo "Encryption requested but GPG key (-g) is missing."
        exit 1
    fi
fi

# Sending the files
 if [ "$CLOUD" = "TRUE" ]; then
    backup_on_cloud
else
    backup_on_remote
fi
# Cleaning the temporal working directory
clean_up
