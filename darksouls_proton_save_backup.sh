#!/bin/sh

BAK_DIR=$HOME/games/backups/DarkSouls

#Backs up dark souls 2 and 3 save files.
[ -d $BAK_DIR ] || mkdir -p $BAK_DIR && echo "Backup directory did not exist. Created backup directory: $BAK_DIR."

cp $HOME/.steam/root/steamapps/compatdata/335300/pfx/drive_c/users/steamuser/AppData/Roaming/DarkSoulsII/0110000104dfa8c1/* $HOME/backup_saves
cp $HOME/.steam/root/steamapps/compatdata/374320/pfx/drive_c/users/steamuser/AppData/Roaming/DarkSoulsIII/0110000104dfa8c1/* $HOME/backup_saves
scp $HOME/backup_saves/* nexus@misfits.rip:Documents/backup_saves

echo 'Done backing up saves...'
echo
