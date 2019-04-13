#!/bin/bash
# based on http://crunchbang.org/forums/viewtopic.php?id=38748#p414992

# m4bronto
#     Chapter #0:0: START 0.000000, END 1290.013333
#       first   _     _     START    _     END

echo "$0"

BASEDIR="$( dirname "$0" )"
# Audible Secret
SECRET="$(head -n1 < "$BASEDIR/audible.secrets" | grep -o '[0-9a-f]*$')"

# if secret is not given, try to extract it from AudibleActivation.sys
# you may find this file on your rooted Android phone
# in /data/data/com.audible.application/files)
# or on your audible activated MP3 player (e.g. Sandisk Clip, Sandisk Sports)

if [[ -z $SECRET ]] ; then
    if [[ -e "$BASEDIR/AudibleActivation.sys" ]] ; then
        SECRET="$( hexdump "$BASEDIR"/AudibleActivation.sys | head -n 1 | sed -r 's/^.{8}(.{4}) (.{4}).*/\2\1/' )"
        echo "Your secret: $SECRET"
    else
        echo "no secret";
        exit
    fi
fi

while [[ $# -gt 0 ]] ; do

    TMP="$( mktemp /tmp/audibleXXXXX )"
    TMP2=${TMP}2

    ffmpeg -i "$1" 2> "$TMP"
    if [ "$2" = '--lang' ]; then
        case "$3" in
            en)
                START=2
                END=4
                ;;
            de)
                START=4
                END=3
                ;;
            *)
                echo 'Unknown language!'
                exit 1
        esac

        sed -i "s/\\(Chapter #0:0: start \\)0.000000/\\1$START.00/" "$TMP"

        LINE="$( grep '^\s*Chapter' "$TMP" | tail -n 1 )"
        VAL="$( echo "$LINE" | grep -oP '(?<=end )\d+')"
        ((VAL2=VAL-END))
        LINE2=${LINE/$VAL/$VAL2}
        sed -i "s/$LINE/$LINE2/" "$TMP"
    fi

    sed 's/^\s*// ; 1,/Metadata/d ; /Duration/,$d' < "$TMP" > "$TMP2"

    TITLE="$( grep "^title" "$TMP2" | sed 's/^.*:.//' )"
    ARTIST="$( grep "^artist" "$TMP2" | sed 's/^.*:.//' )"

    DIR="$ARTIST - $TITLE"

    mkdir "$DIR"
    ffmpeg -i "$1" "$DIR/cover.jpg"

    TRACK=1

    while read -r FIRST _ _ START _ END; do
        if [[ $FIRST = Chapter ]]; then
            read -r  # discard line with Metadata:
            read -r _ _ CHAPTER

            # converting options and output file
            OUTFMT=( -c:a libmp3lame )
            OUTFILE="$DIR/$( printf "%02d" $TRACK ) - ${CHAPTER}.mp3"
            ffmpeg -activation_bytes "$SECRET" -i "$1" \
                -ss "${START%?}" -to "$END" -vn \
                -metadata title="$CHAPTER" -metadata track="$TRACK" \
                "${OUTFMT[@]}" "$OUTFILE" </dev/null
                ((TRACK=TRACK+1))
        fi
    done < "$TMP"

    rm -f "$TMP" "$TMP2"
    if [ "$2" = '--lang' ]; then
        shift 3
    else
        shift
    fi
done
