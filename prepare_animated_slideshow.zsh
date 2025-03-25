#!/bin/zsh

setopt nullglob
setopt nonomatch

VERBOSE=false
POS_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -v||--verbose)
      VERBOSE=true
      shift
      ;;
    -*||--*)
      echo "Unknown Option"
      exit 1
      ;;
    *)
      POS_ARGS+=("$1")
      shift
      ;;
  esac
done

slideshow=$HOME'/Pictures/animated_slideshow/'
pics=$HOME'/Pictures/'

dirs=($(find $pics -type d -name animated -not -path "**/nsfw/**"))
echo '//////// CLEANING UP' $slideshow '////////'
let i=0; let k=0
for file in $slideshow/*
do
  if [[ $i -eq ($(tput cols) - 1) ]]
  then
    echo
    i=0
  fi
  [ -e "$file" ] && rm $file && i=i+1 && k=k+1 && printf "-"
done
printf '\n%d files cleaned up...\n' $k
echo

echo '///////// TRANSFERRING //////////'
let i=0; let k=0
for dir in $dirs
do
  $VERBOSE && echo '\n////////  '$dir'  //////////'
  $VERBOSE && i=0
  for file in $dir/*(N.)
  do
    if [[ $i -eq ($(tput cols) - 1) ]]
    then
      echo
      i=0
    fi
    [ -e "$file" ] && cp $file $slideshow && i=i+1 && k=k+1 && printf "+"
  done
done
printf '\n%d files transferred...\n' $k

DUPES="$(diff <(find "$slideshow" -type f -exec basename {} \; | sort) <(for dir in $dirs; do find "$dir" -type f -exec basename {} \; ; done | sort))"
[ $DUPES == ""] || echo "Possible duplicates in filesystem:" $DUPES
echo
