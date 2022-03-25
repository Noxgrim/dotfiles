#! /bin/zsh
# Use zsh because bash's non-built-in printf does
# not support argument indices

DEF_LANG='en'
NAME_NO_CHAP='%1$s%2$0$MAXd'
NAME_CHAP='%1$s%2$0$MAXd: %3$s'
NAME_CHAP_PARTS='%1$s%2$0$MAXd.%3$0$MAXPd: %4$s'
INFO_COMMENT='%1$s%2$s; %3$s'
NARRATOR=
NARRATOR_PREFIX=
COPYRIGHT=

COVER_FILE=
CHAPTER_FILE=
CHAPTER_PREFIX=
CHAPTER_PARTS=0
CHAPTER_LENGTHS=()
CURRENT_CHAPTER_PARTS=()

TAG_ARGS=()
TAG_IDX=1
LANG_SET=''
CONNECT_CHAPTERS_PARTS=''
SHIFT_AMOUNT=''

set_option() {
    case "$1" in
        -L|--language)
            case "$2" in
                en)
                    TAG_ARGS[TAG_IDX++]='-g'
                    TAG_ARGS[TAG_IDX++]='audio book'
                    CHAPTER_PREFIX='Chapter '
                    NARRATOR_PREFIX='Narrated by '
                    LANG_SET=1
                    SHIFT_AMOUNT=2
                    ;;
                de)
                    TAG_ARGS[TAG_IDX++]='-g'
                    TAG_ARGS[TAG_IDX++]='Hörbuch'
                    CHAPTER_PREFIX='Kapitel '
                    NARRATOR_PREFIX='Gelesen von '
                    LANG_SET=1
                    SHIFT_AMOUNT=2
                    ;;
                *)
                    >&2 echo 'Unknown language!'
                    exit 1
            esac
            ;;
        -i|--cover)
            COVER_FILE="$2"
            SHIFT_AMOUNT=2
            ;;
        -l|--title)
            TAG_ARGS[TAG_IDX++]='-l'
            TAG_ARGS[TAG_IDX++]="$2"
            SHIFT_AMOUNT=2
            ;;
        -a|--author)
            TAG_ARGS[TAG_IDX++]='-a'
            TAG_ARGS[TAG_IDX++]="$2"
            SHIFT_AMOUNT=2
            ;;
        -y|--year)
            TAG_ARGS[TAG_IDX++]='-y'
            TAG_ARGS[TAG_IDX++]="$2"
            SHIFT_AMOUNT=2
            ;;
        -c|--comment)
            TAG_ARGS[TAG_IDX++]='-c'
            TAG_ARGS[TAG_IDX++]="$2"
            SHIFT_AMOUNT=2
            ;;
        -n|--narrator)
            NARRATOR="$2"
            SHIFT_AMOUNT=2
            ;;
        -r|--copyright)
            COPYRIGHT="$2"
            SHIFT_AMOUNT=2
            ;;

        -d|--directory)
            cd "$2"
            SHIFT_AMOUNT=2
            ;;
        -f|--chapter-file)
            CHAPTER_FILE="$2"
            SHIFT_AMOUNT=2
            ;;
        -C|--connect)
            CONNECT_CHAPTERS_PARTS=1
            SHIFT_AMOUNT=1
            ;;
        -p|--prefix)
            CHAPTER_PREFIX="$2"
            SHIFT_AMOUNT=2
            ;;
        -h|--help)
            less -F << 'EOF'
Tool for mass tagging MP3 audio books in the current working directory (by
default).
It needs `id3`, `mp3splt`, `mp3wrap` and `python` with the `mutagen` library to
be installed.
The script creates a backup of your files before any excetion. If anything is
as expected you may delete it with e.g. `rm *.bak`

Options:
-l TITLE, --title TITLE
        Set the title of the book (as the album tag)
-a AUTHOR, --author AUTHOR
        Set the author name (as the artist tag)
-y YEAR, --year YEAR
        Set the release year
-c COMMENT, --comment COMMENT
        Set the comment information
        Deprecated if only the narrator and copyright information should be
        inserted. Have a look at ‘--narrator’ and ‘--copyright’.
-n NARRATOR, --narrator NARRATOR
        Set the narrator(s)
        This option should be used together with the copyright information.
        This will generate a comment with the following format:
        “<Narrated by> NARRATOR; <copyright>”
-r COPYRIGHT, --copyright COPYRIGHT
        Set the copyright information
        This option should be used together with the narrator information.
        This will generate a comment with the following format:
        “<Narrated by> <narrator>; COPYRIGHT”
        The content could for example be “<production year> <producer/studio>”
-i COVER, --cover COVER
        Set the cover that should be written to the audio files
-p PREFIX, --prefix PREFIX
        Set a custom chapter prefix
        Keep in mind that ‘--language’ also sets the prefix so you have to
        specify this option after ‘--language’. The chapter prefix can be
        disabled by setting an empty string.

-L, --language
        Set the language of the audio book and related tags.
        Possible languages are (feel free to add your own…):
            en: English (default)
            de: German

-f FILE, --chapter-file FILE
        Use a chapter file

        A chapter file contains the name of a chapter on each line.
        If multiple files belong to the same chapter, a special syntax can be
        used:

        .<FILE_NO>(<SPLIT>)#<CHAPTER_NO> A lovely chapter title
        .<FILE_NO>#<CHAPTER_NO> The next lovely chapter title
        .<FILE_NO>(<SPLIT>) A lovely chapter that starts after a split in a file
        .<FILE_NO> A lovely but simple chapter title
        An even simpler title that increases FILE_NO by one

        The line has to start with a dot `.`. If it doesn't, the whole line is
        used as the chapter name and the file counter is increased by 1.
        A `.` is followed by the file number FILE_NO of the audio file. This
        number starts with one. The files are sorted numerically so they should
        start with a number or be already naturally sorted beforehand. File
        numbers have be to strictly monotonically increasing (if no split
        points are used).
        Optionally, a SPLIT point can specified directly after the file number
        in parentheses. This tells the script that the chapter only starts after
        the specified split time stamp. The splits do not affect FILE_NO in any
        way.
        SPLIT has the following format:
         m.s[.h]
        With the minutes m being unlimited 0-∞, the seconds s being 0-59 and
        optional hundredths h being 0-99 (see the `mp3splt` man page).
        Another optional CHAPTER_NO component is the chapter counter number that
        can be defined after a hash sign `#`. The number has to be non-negative
        and strictly monotonically increasing.
        A single space is used to separate the chapter number definition from
        the chapter name.

        Each line defines where a chapter starts, so a chapter will contain the
        files from the start it defines until the start of the next chapter or
        the rest of the files if there is no next chapter.
-C, --connect
        Instead of encoding multiple files as
         <Chapter> CHAP_NO.PART: A lovely chapter title
        for each file (i.e. the files will stay as they are except from splits
        and contain a counter for each file)
        they will be combined into one file using `mp3wrap`.
-d, --directory DIR
        Define the directory in which the script operates in instead of the
        current working directory
EOF
exit
            ;;
        *)
            >&2 echo 'Unknown option:' "$1"
            exit 1
    esac
}

while [ $# -gt 0 ]; do
    set_option "$1" "$2" "$3"
    shift "$SHIFT_AMOUNT"
done

declare -A SPLIT_FILES

if [ -n "$CHAPTER_FILE" ]; then
    if [ ! -f "$CHAPTER_FILE" ]; then
        echo 'Chapter file does not exist!'
        exit 1
    fi

    if grep -q '^\.' "$CHAPTER_FILE"; then
        CHAPTER_PARTS=1
    fi

    if [ $CHAPTER_PARTS ]; then
        LAST=0
        SPLIT_LAST='0.0.0'
        THIS=0
        MAXPARTS=0
        FILES=()
        while IFS= read -r -d$'\0' FILE; do
            FILES+=( "$FILE" )
        done < <(find . -type f -iname '*.mp3' -print0 | sort -znt/ -k2,2)
        CHAPTERS="$(($(wc -l < "$CHAPTER_FILE")+1))" # +sentinel

        for (( i = 1; i <= $CHAPTERS; i++ )); do
            LINE="$(sed -n "${i}p" "$CHAPTER_FILE")"
            if [ -z "$LINE" ]; then
                LINE=".$((${#FILES[@]}+1))"
            fi

            THIS="$(grep -oP '^\.0*\K\d+' <<< "$LINE")"
            SPLIT="$(grep -oP '^\.\d*\(\K[^)]*' <<< "$LINE")"
            if [ -z "$THIS" ]; then
                THIS=$((LAST+1))
            fi
            if [ "$THIS" = "$LAST" ] && [ -z "$SPLIT" ]; then
                echo "$i: There already was a line with the same file number; line must define a split point!" >&2
                exit 1
            fi
            if [ -z "$SPLIT" ]; then
                SPLIT='0.0.0'
            fi
            if ! grep -qE '^[0-9]+\.0*[1-5]?[0-9](\.0*[1-9]?[0-9])?$' <<< "$SPLIT"; then
                echo "$i: Split malformed. Expected 0-.0-59[.0-99], got $SPLIT" >&2
                exit
            fi
            # bring the split into canonical form
            SPLIT="$(sed -E '/^[^.]*\.[^.]*$/s/$/.0/;s/^0*([1-9]?[0-9]+)\.0*([1-5]?[0-9])\.0*([1-9]?[0-9])$/\1.\2.\3/' <<< "$SPLIT")"
            if [ "$THIS" = "$LAST" ]; then
                if [ "$SPLIT_LAST" = "$SPLIT" ] || ! sort -Vc <<< "$SPLIT_LAST"$'\n'"$SPLIT"; then
                    echo "$i: Splits are not successive! $SPLIT ≤ $SPLIT_LAST" >&2
                    exit 1
                fi
            fi


            if [ $i -gt 1 ]; then
                PARTS=$((THIS-LAST))

                if [ $PARTS -lt 0 ]; then
                    echo "$i: Something's not right: non-positive parts number for chapter $i"
                    exit 1
                fi
                FILE_LAST="${FILES[$LAST]}"
                if [ "$PARTS" = 0 ]; then # same file
                    SPLIT_FILES[$FILE_LAST]=
                    echo "Splitting $FILE_LAST at $SPLIT_LAST-$SPLIT..."
                    mp3splt "$FILE_LAST" "$SPLIT_LAST" "$SPLIT" &>/dev/null
                    ((PARTS++))
                else
                    if [ "$SPLIT_LAST" != '0.0.0' ]; then # last half of previous file
                        SPLIT_FILES[$FILE_LAST]=
                        echo "Splitting $FILE_LAST at $SPLIT_LAST-EOF..."
                        mp3splt "$FILE_LAST" "$SPLIT_LAST" 'EOF' &>/dev/null
                    fi
                    if [ "$SPLIT" != '0.0.0' ]; then # first half of first file
                        FILE="${FILES[$THIS]}"
                        SPLIT_FILES[$FILE]=
                        echo "Splitting $FILE at 0.0-$SPLIT..."
                        mp3splt "$FILE" "0.0.0" "$SPLIT" &>/dev/null
                        ((PARTS++))
                    fi
                fi

                if [ $PARTS = 0 ]; then
                    echo "$i: Something's not right: non-positive parts number for chapter $i"
                    exit 1
                elif [ $PARTS -gt $MAXPARTS ]; then
                    MAXPARTS=$PARTS
                fi
                CHAPTER_LENGTHS[i-1]="$PARTS"
            fi
            LAST="$THIS"
            SPLIT_LAST="$SPLIT"
        done
        MAXP=$(($(wc -m <<< "$MAXPARTS")-1))
        MAX=$(($(wc -l < "$CHAPTER_FILE" | wc -m )-1))
    fi
fi

if [ -z  "$LANG_SET" ]; then
    echo 'Warning: No language set!'
    if [ -n "$DEF_LANG" ]; then
        echo "(Default to $DEF_LANG)"
        set_option '-L' "$DEF_LANG"
    fi
fi
COMMENT=''
if [ -n "$NARRATOR" ] || [ -n "$COPYRIGHT" ]; then
    COMMENT="$(printf "$INFO_COMMENT" "$NARRATOR_PREFIX" "$NARRATOR" "$COPYRIGHT")"
fi
if [ -n "$COMMENT" ]; then
    TAG_ARGS[TAG_IDX++]='-c'
    TAG_ARGS[TAG_IDX++]="$COMMENT"
fi




[ -z "$MAX" ] && MAX=$(( $(ls *.mp3 | wc -l | wc -m )-1 ))
NAME_F_NO_CHAP=$( echo "$NAME_NO_CHAP" | sed 's/\$MAX/'"$MAX"'/' )
NAME_F_CHAP_PART=$( echo "$NAME_CHAP_PARTS" | sed 's/\$MAXP/'"$MAXP"'/;s/$MAX/'"$MAX"'/' )
NAME_F_CHAP=$( echo "$NAME_CHAP" | sed 's/\$MAX/'"$MAX"'/' )
NAME_T_NO_CHAP=$( echo "$NAME_NO_CHAP" | sed 's/\$MAX//' )
NAME_T_CHAP=$( echo "$NAME_CHAP" | sed 's/\$MAX//' )

NUM=0
CHAPLINE=0
CHAPNUM=-1
CHAP=
PART=0
for F in "${(k)SPLIT_FILES[@]}"; do
    mv "$F" "$F".bak
done
while IFS= read -r -d$'\0' F; do
    echo "$F..."
    cp "$F" "$F".bak
    python - "$F" << EOF
import mutagen.easyid3 as mid3
import sys
f = mid3.Open(sys.argv[1])
f.clear()
f.save()
EOF
    id3 -d -c '' "$F"
    if [ -n "$CHAPTER_FILE" ]; then
        if [ ! $CHAPTER_PARTS ]; then
            ((++NUM))
            CHAP="$( sed "${NUM}q;d" "$CHAPTER_FILE" )"
            id3 -2 "${TAG_ARGS[@]}" -n "$NUM" -t "$( printf "$NAME_T_CHAP" "$CHAPTER_PREFIX" "$NUM" "$CHAP" )" "$F"
            mv "$F" "$( printf "$NAME_F_CHAP" "$CHAPTER_PREFIX" "$NUM" "$CHAP" ).mp3"
        else
            if [ $PART -le 0 ]; then
                ((++CHAPLINE))
                LINE="$( sed "${CHAPLINE}q;d" "$CHAPTER_FILE" )"
                NEWCHAP=$(grep -oP '^.*#\K\d+' <<< "$LINE")
                if [ -n "$NEWCHAP" ]; then
                    TCHAPNUM=$((NEWCHAP))
                    if [ $TCHAPNUM -le $CHAPNUM ]; then
                        echo "To esure right file sorting, chapter numbers must be strictly monotonically increasing!"
                        exit 1
                    fi
                    CHAPNUM=$TCHAPNUM
                elif [ $CHAPNUM -le 0 ]; then
                    CHAPNUM=1;
                else
                    ((++CHAPNUM))
                fi
                CHAP="$(grep -oP '^.*? \K.*' <<< "$LINE")"
                if [ -z "$CHAP" ]; then
                    CHAP=$LINE
                fi
            fi

            ((++PART))
            if [ -z "$CONNECT_CHAPTERS_PARTS" ]; then
                ((++NUM))
                id3 -2 "${TAG_ARGS[@]}" -n "$NUM" -t "$( printf "$NAME_T_CHAP" "$CHAPTER_PREFIX" "$CHAPNUM" "$CHAP" )" "$F"
                if [ ${CHAPTER_LENGTHS[CHAPLINE]} = 1 ]; then
                    mv "$F" "$( printf "$NAME_F_CHAP" "$CHAPTER_PREFIX" "$CHAPNUM" "$CHAP" ).mp3"
                else
                    mv "$F" "$( printf "$NAME_F_CHAP_PART" "$CHAPTER_PREFIX" "$CHAPNUM"  "$PART" "$CHAP" ).mp3"
                fi
            else
                CURRENT_CHAPTER_PARTS[PART]="$F"
            fi

            if [ $PART -ge ${CHAPTER_LENGTHS[CHAPLINE]} ]; then
                if [ -n "$CONNECT_CHAPTERS_PARTS" ]; then
                    ((++NUM))
                    DEST_FILE="$( printf "$NAME_F_CHAP" "$CHAPTER_PREFIX" "$CHAPNUM" "$CHAP" ).mp3"
                    if [ ${CHAPTER_LENGTHS[CHAPLINE]} != 1 ]; then
                        echo "Combining ${CHAPTER_LENGTHS[CHAPLINE]} chapter parts to chapter..."
                        mp3wrap "temp.mp3" "${CURRENT_CHAPTER_PARTS[@]}" &> /dev/null
                        mv "temp_MP3WRAP.mp3" "$DEST_FILE"
                    else
                        mv "$F" "$DEST_FILE"
                    fi
                    python - "$DEST_FILE" << EOF
import mutagen.easyid3 as mid3
import sys
f = mid3.Open(sys.argv[1])
f.clear()
f.save()
EOF
                    id3 -c '' -d "$DEST_FILE"
                    id3 -2 "${TAG_ARGS[@]}" -n "$NUM" -t "$( printf "$NAME_T_CHAP" "$CHAPTER_PREFIX" "$CHAPNUM" "$CHAP" )" "$DEST_FILE"

                    if [ ${CHAPTER_LENGTHS[CHAPLINE]} != 1 ]; then
                        rm "${CURRENT_CHAPTER_PARTS[@]}"
                    fi
                fi

                PART=0
                CURRENT_CHAPTER_PARTS=()
            fi
        fi
    else
        ((++NUM))
        id3 -2 "${TAG_ARGS[@]}" -n "$NUM" -t "$( printf "$NAME_T_NO_CHAP" "$CHAPTER_PREFIX" "$NUM" )" "$F"
        mv "$F" "$( printf "$NAME_F_NO_CHAP" "$CHAPTER_PREFIX" "$NUM" ).mp3"
    fi
done < <(find . -type f -iname '*.mp3' -print0 | sort -znt/ -k2,2)
if [ -n "$COVER_FILE" ]; then
    echo 'Writing cover...'
    FILES=()
    while IFS= read -r -d$'\0' FILE; do
        FILES+=( "$FILE" )
    done < <(find . -type f -iname '*.mp3' -print0 | sort -znt/ -k2,2)
    python - "$COVER_FILE" ${FILES[@]} << EOF
# https://stackoverflow.com/questions/42473832/embed-album-cover-to-mp3-with-mutagen-in-python-3
# it's to late to figure that out on my own
import mutagen
from mutagen.id3 import ID3, APIC
import sys
import os.path

cover = sys.argv[1]

with open(cover, 'rb') as albumart:
    for afile in sys.argv[2:]:
        audio = ID3(afile)
        audio['APIC'] = APIC(
                          encoding=3,
                          mime='image/' + os.path.splitext(cover)[1][1:],
                          type=3, desc=u'cover',
                          data=albumart.read()
                        )
        audio.save()
        albumart.seek(0)
EOF
fi
