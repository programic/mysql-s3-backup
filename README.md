# Requirements
This script is tested on Ubuntu 20.04 LTS.

```bash
$ apt install jq mysql-client awscli
```

# Installation
1. Copy `config.example.json` to `config.json` and modify the content
2. You can now run `bash mysql-backup.sh`

## Crontab
```bash
$ crontab -e
0 */4 * * * cd /path-to-script-folder && bash mysql-backup.sh >> /dev/null 2>&1
```
