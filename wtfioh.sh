#!/bin/sh

if [[ $# -ne 2 ]]; then
  printf "░██╗░░░░░░░██╗████████╗███████╗██╗░█████╗░██╗░░██╗\n"
  printf "░██║░░██╗░░██║╚══██╔══╝██╔════╝██║██╔══██╗██║░░██║\n"
  printf "░╚██╗████╗██╔╝░░░██║░░░█████╗░░██║██║░░██║███████║\n"
  printf "░░████╔═████║░░░░██║░░░██╔══╝░░██║██║░░██║██╔══██║\n"
  printf "░░╚██╔╝░╚██╔╝░░░░██║░░░██║░░░░░██║╚█████╔╝██║░░██║\n"
  printf "░░░╚═╝░░░╚═╝░░░░░╚═╝░░░╚═╝░░░░░╚═╝░╚════╝░╚═╝░░╚═╝\n"
  printf "==================================================\n"
  printf "what the fuck is on here by N. Jodoin\n"
  printf "Usage:\twtfioh targetdir/ [numLines]\n"
  printf "Description: Print list of folders/files >= 1GB, sorted desc.\n"
  printf "Starts in targetdir. Truncated after numLines of output.\n"
  printf "Useful du alias.\n"
  exit 666;
fi

sudo du -aBG $1 2>/dev/null | sort -nr | head -$2

exit 0
