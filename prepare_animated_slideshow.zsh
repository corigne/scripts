#!/bin/zsh
setopt nonomatch
slideshow=$HOME'/Pictures/animated_slideshow/'
pics=$HOME'/Pictures/'
dirs=($(find $pics -type d -name animated -not -path "**/nsfw/**"))
echo '//////// CLEANING UP' $slideshow '////////'
let i=0; let k=0
for file in $slideshow/*
do
  if [[ $i -eq 80 ]]
  then
    echo
    i=0
  fi
  echo -n '.'
  [ -f "$file" ] && rm $file && i=i+1 && k=k+1
done
i=0
echo '\n'; echo $k 'files cleaned up...\n'; k=0;

echo '///////// TRANSFERRING //////////\n'
for dir in $dirs
do
  echo '////////  '$dir'  //////////'
  for file in $dir/*
  do
    if [[ $i -eq 80 ]]
    then
      echo
      i=0
    fi
    echo -n '.'
    [ -f "$file" ] && cp $file $slideshow && i=i+1 && k=k+1
  done
  echo '\n'
  i=0
done
echo $k 'files transferred...\n';k=0;
