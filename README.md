# backup.sh

Simple bash script I wrote to backup my files to a remote server or cloud storage. Does compression, optional GPG encryption, and sends everything via rsync or rclone.

## What it does

- Makes a tar.gz of whatever directory you point it at
- Can encrypt it with GPG if you want (I usually do) - that's encryption at rest
- Sends it to a remote server via rsync/ssh OR to cloud storage with rclone - encrypted in transit too
- Cleans up the temp files when done

## Requirements

You need these installed:
- `tar` 
- `rsync` (for SSH backups)
- `rclone` (for cloud backups)
- `gpg` (only if you want encryption)

## Usage

Basic usage:
```bash
./backup.sh -s /home/myuser/documents -r user@myserver.com:/backups -t /tmp
```

With encryption:
```bash
./backup.sh -s /home/myuser/documents -r user@myserver.com:/backups -t /tmp -e -g mykey@email.com
```

With custom SSH key:
```bash
./backup.sh -s /home/myuser/documents -r user@myserver.com:/backups -t /tmp -k ~/.ssh/backup_key
```

Cloud backup (needs rclone configured):
```bash
./backup.sh -s /home/myuser/documents -r mydrive:/backups -t /tmp -c
```

Cloud backup with encryption:
```bash
./backup.sh -s /home/myuser/documents -r mydrive:/backups -t /tmp -c -e -g mykey@email.com
```

### Options

- `-s` - Source directory (requiered)
- `-r` - Where to send it, like `user@host:/path` for SSH or `remote:/path` for cloud (requiered)  
- `-t` - Temp directory to work in (requiered)
- `-e` - Turn on GPG encryption
- `-g` - GPG key ID to use for encryption
- `-k` - SSH key file if you don't want to use the default
- `-c` - Use cloud mode (rclone instead of rsync)
- `-h` - Show help

## Notes

- Files get timestamped so you won't overwrite old backups
- For SSH: make sure your SSH keys are set up properly for the remote server
- For cloud: make sure rclone is configured with your provider first (`rclone config`)
- If you use encryption, make sure you can decrypt with the same GPG key later!
- The script will exit if something goes wrong instead of continuing
- You can throw this in a cronjob if you want automatic backups

## Why I made this

I was tired of manually creating backups and wanted something simple that would compress, encrypt, and send my files automatically to either my server or cloud storage. Nothing fancy, just gets the job done.

Feel free to modify it for your needs.
