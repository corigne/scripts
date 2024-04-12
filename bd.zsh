#!/bin/zsh

URL="https://github.com/BetterDiscord/Installer/releases/latest/download/BetterDiscord-Linux.AppImage"
FILE=better_discord.AppImage
ERR=(curl -sL --fail $URL -o $FILE)

if ( $ERR -ne 22 )
then
  printf "[INFO] Better Discord Installer retieved.\n"
  killall Discord && printf "[INFO] Killed existing discord sessions to facilitate install.\n"
  chmod +x $FILE
  ./$FILE
  rm $FILE
else
  printf "Unable to retrieve BetterDiscord AppImage. Please check your internet connection.\n"
fi
