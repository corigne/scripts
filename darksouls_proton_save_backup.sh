#!/bin/sh
#Backs up dark souls 2 and 3 save files.

BAK_DIR=$HOME/Games/backups/DarkSouls
DS2_SRC=$HOME/.steam/root/steamapps/compatdata/335300/pfx/drive_c/users/steamuser/AppData/Roaming/DarkSoulsII
DS3_SRC=$HOME/.steam/root/steamapps/compatdata/374320/pfx/drive_c/users/steamuser/AppData/Roaming/DarkSoulsIII

[ -d $BAK_DIR ] || mkdir -p $BAK_DIR && echo "Backup directory did not exist. Created backup directory: $BAK_DIR."
[ -d $BAK_DIR/DS2 ] || mkdir -p $BAK_DIR/DS2 && echo "Backup directory did not exist. Created backup directory: $BAK_DIR."
[ -d $BAK_DIR/DS3 ] || mkdir -p $BAK_DIR/DS3 && echo "Backup directory did not exist. Created backup directory: $BAK_DIR."

cp -r $DS2_SRC/* $BAK_DIR/DS2
cp -r $DS3_SRC/* $BAK_DIR/DS3

echo 'Done backing up saves...'
echo
