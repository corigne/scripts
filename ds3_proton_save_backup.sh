#!/bin/sh
#Backs up dark souls 2 and 3 save files.

BAK_DIR=$HOME/Games/backups/DarkSouls
REMOTE_DIR=ssh://traveler/harlow/games/dark_souls_backups
DS3_SRC=$HOME/.steam/root/steamapps/compatdata/374320/pfx/drive_c/users/steamuser/AppData/Roaming/DarkSoulsIII


[ -d $BAK_DIR/DS3 ] || (mkdir -p $BAK_DIR/DS3 && echo "Backup directory did not exist. Created backup directory: $BAK_DIR.")

rsync -av --exclude='*.xml' $DS3_SRC/ $BAK_DIR/DS3

unison -batch -auto $BAK_DIR $REMOTE_DIR

echo 'Done backing up saves...'
echo
