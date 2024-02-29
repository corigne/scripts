#!/bin/sh
#Backs up dark souls 2 proton save files.

BAK_DIR=$HOME/Games/backups/DarkSouls
REMOTE_DIR=ssh://traveler/harlow/games/dark_souls_backups
DS2_SRC=$HOME/.steam/root/steamapps/compatdata/335300/pfx/drive_c/users/steamuser/AppData/Roaming/DarkSoulsII

[ -d $BAK_DIR ] || (mkdir -p $BAK_DIR && echo "Backup directory did not exist. Created backup directory: $BAK_DIR.")
[ -d $BAK_DIR/DS2 ] || (mkdir -p $BAK_DIR/DS2 && echo "Backup directory did not exist. Created backup directory: $BAK_DIR.")

rsync -av --exclude='*.xml' $DS2_SRC/ $BAK_DIR/DS2

unison -batch -auto $BAK_DIR $REMOTE_DIR
echo 'Done backing up saves...'
echo
