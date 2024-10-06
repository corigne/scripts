#!/bin/bash

BACKGROUNDS="/usr/share/backgrounds"
SLIDESHOW="/usr/share/backgrounds/slideshow"
FILE=$(ls $SLIDESHOW | shuf -n 1)
FILE2=$(ls $SLIDESHOW | shuf -n 1)

cp "$SLIDESHOW/$FILE" "$BACKGROUNDS/background.jpg"

#cp "$SLIDESHOW/$FILE2" "$BACKGROUNDS/background2.jpg"

#FILE=$BACKGROUNDS/background.jpg
# FILE2=$BACKGROUNDS/background2.jpg

# for file in $FILE $FILE2; do
#   magick convert $file -gravity center -crop 16:9 out.jpg
#   magick convert out.jpg -resize 2560x1440 $file
# done
