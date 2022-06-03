#!/bin/bash
# based on http://crunchbang.org/forums/viewtopic.php?id=38748#p414992

# m4bronto
#     Chapter #0:0: START 0.000000, END 1290.013333
#       first   _     _     START    _     END

echo "$0"

BASEDIR="$( dirname "$0" )"
SECRET_FILE="$BASEDIR/audible.secrets"
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

START=0.0
END=0.0
FMT='mp3'
OUTFMT=( -c:a libmp3lame )

while [[ $# -gt 0 ]] ; do
    case "$1" in
        --format|--fmt|-f)
            case "$2" in
                mp3)
                    FMT='mp3'
                    OUTFMT=( -c:a libmp3lame )
                    ;;
                flac)
                    FMT='flac'
                    OUTFMT=( -c:a flac )
                    ;;
                ogg)
                    FMT='ogg'
                    OUTFMT=( -c:a libvorbis )
                    ;;
                custom)
                    FMT="$3"
                    OUTFMT=( -c:a "$4" )
                    shift 2
                    ;;
                *)
                    echo 'Unknown format, use `custom <file extension> <codec>` for custom values!'
                    exit 1
            esac
            shift 2
            continue
            ;;
        --language|--lang|-L)
            case "$2" in
                en)
                    START=2.0
                    END=4.0
                    ;;
                de_old)
                    START=4.0
                    END=3.0
                    ;;
                de)
                    START=7.5
                    END=4.0
                    ;;
                custom)
                    START="$3"
                    END="$4"
                    shift 2
                    ;;
                none)
                    START=0.0
                    END=0.0
                    ;;
                *)
                    echo 'Unknown language, use `custom <start_offset> <end_offset>` for custom values!'
                    exit 1
            esac
            shift 2
            continue
            ;;
        --secret-file|-s)
            SECRET="$(head -n1 "$2" | grep -o '[0-9a-f]*$')"
            shift 2
            continue
            ;;
        --secret|-S)
            SECRET="$2"
            shift 2
            continue
            ;;
        --output-dir|-d|-o|-O)
            DIR="$2"
            shift 2
            continue
            ;;
    esac

    TMP="$( mktemp /tmp/audebilXXXXX )"


    ffprobe -v quiet \
        -show_entries chapter=start_time,end_time:chapter_tags=title -of csv \
        "$1" | cut -d, -f2- > "$TMP"
    TITLE="$(ffprobe -v quiet \
        -show_entries format_tags=title -of csv "$1" | cut -d, -f2-)"

    sed -i '1s/^\([^,]*,\)[^,]*/\1'"$START/" "$TMP"
    VAL="$(tail -n1 "$TMP" | cut -d, -f 2)"
    NEW_VAL="$(bc <<< "$VAL-$END")"
    sed -i '$s/^\([^,]*,\){2}[^,]*/\1'"$NEW_VAL/" "$TMP"

    DIR="${DIR-:"$TITLE"}"

    mkdir -p "$DIR"
    ffmpeg -v quiet -i "$1" "$DIR/cover.jpg"

    NO_FILES="$(bc <<< "$(wc -l < "$TMP" | wc -c)-1")"
    if command -v "${FMT}splt" > /dev/null; then
        echo "Docoding…"
        TMP_CONV="$( mktemp "$BASEDIR"/audebilXXXXX --suffix ".$FMT")"
        ffmpeg -v error -stats -y -activation_bytes "$SECRET" -i "$1" \
            -vn -metadata title="$CHAP_TITLE" \
            "${OUTFMT[@]}" "$TMP_CONV"
        echo "Splitting…"
        "${FMT}splt" -d "$DIR" -A <(awk '
            {split($0,a,",");sub(/^[^,]*,[^,]*,/,"",$0);
             printf("%s\t%s\t%0'"$NO_FILES"'d - %s\n",a[1],a[2],NR,$0)}' "$TMP") "$TMP_CONV"
        rm -r "$TMP_CONV" "$TMP_SPLTS"
    else
        TRACK=1
        while IFS=, read -r START_TIME END_TIME CHAP_TITLE; do
            OUTFILE="$DIR/$(printf "%0${NO_FILES}d" $TRACK ). ${CHAP_TITLE}.$FMT"
            echo "$OUTFILE"
            ffmpeg -v error -stats -activation_bytes "$SECRET" -i "$1" \
                -ss "${START_TIME%?}" -to "$END_TIME" -vn \
                -metadata title="$CHAP_TITLE" -metadata track="$TRACK" \
                "${OUTFMT[@]}" "$OUTFILE" </dev/null
                ((TRACK=TRACK+1))
        done < "$TMP"
    fi

    rm -f "$TMP"
    unset DIR
    shift
done
