#!/bin/sh
#restores backup saves to their correct locations, if the prefix already exists

BAK_DIR=$HOME/Games/backups/DarkSouls
DS2_SRC=$HOME/.steam/root/steamapps/compatdata/335300/pfx/drive_c/users/steamuser/AppData/Roaming/DarkSoulsII
DS3_SRC=$HOME/.steam/root/steamapps/compatdata/374320/pfx/drive_c/users/steamuser/AppData/Roaming/DarkSoulsIII

#Backs up dark souls 2 and 3 save files.
[ -d $BAK_DIR ] || echo "Backup directory does not exist to restore from."

cp -r $BAK_DIR/DS2/* $DS2_SRC
cp -r $BAK_DIR/DS3/* $DS3_SRC

echo 'Done restoring saves...'
echo
