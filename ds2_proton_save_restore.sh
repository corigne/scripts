#!/bin/sh
#restores backup saves to their correct locations, if the prefix already exists

BAK_DIR=$HOME/Games/backups/DarkSouls
REMOTE_DIR=ssh://traveler/harlow/games/dark_souls_backups
DS2_SRC=$HOME/.steam/root/steamapps/compatdata/335300/pfx/drive_c/users/steamuser/AppData/Roaming/DarkSoulsII

[ -d $BAK_DIR ] || (echo "Backup directory does not exist to restore from." && exit 1)

unison -batch -auto $BAK_DIR $REMOTE_DIR

cp -r $BAK_DIR/DS2/* $DS2_SRC

echo 'Done restoring saves...'
echo
