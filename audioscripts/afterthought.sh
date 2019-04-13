#! /bin/zsh
# Use zsh because bash's non-built-in printf does
# not support argument indices

DEF_LANG='en'
NAME_NO_CHAP='%1$s%2$0$MAXd'
NAME_CHAP='%1$s%2$0$MAXd: %3$s'
NAME_CHAP_PARTS='%1$s%2$0$MAXd.%3$0$MAXPd: %4$s'

CHAPTER_FILE=
CHAPTER_PREFIX=
CHAPTER_PARTS=0
CHAPTER_LENGTHS=()

TAG_ARGS=()
TAG_IDX=1

set_option() {
    case "$1" in
        -L)
            case "$2" in
                en)
                    TAG_ARGS[TAG_IDX++]='-g'
                    TAG_ARGS[TAG_IDX++]='audio book'
                    CHAPTER_PREFIX='Chapter '
                    ;;
                de)
                    TAG_ARGS[TAG_IDX++]='-g'
                    TAG_ARGS[TAG_IDX++]='Hörbuch'
                    CHAPTER_PREFIX='Kapitel '
                    ;;
                *)
                    echo 'Unknown language!'
                    exit 1
            esac
            ;;
        -l)
            TAG_ARGS[TAG_IDX++]='-l'
            TAG_ARGS[TAG_IDX++]="$2"
            ;;
        -a)
            TAG_ARGS[TAG_IDX++]='-a'
            TAG_ARGS[TAG_IDX++]="$2"
            ;;
        -y)
            TAG_ARGS[TAG_IDX++]='-y'
            TAG_ARGS[TAG_IDX++]="$2"
            ;;
        -c)
            TAG_ARGS[TAG_IDX++]='-c'
            TAG_ARGS[TAG_IDX++]="$2"
            ;;

        -d)
            cd "$2"
            ;;
        -f)
            CHAPTER_FILE="$2"
            ;;
        -p)
            CHAPTER_PREFIX="$2"
            ;;
        *)
            echo 'Unknown option:' "$1"
            exit 1
    esac
}

while [ $# -gt 0 ]; do
    if [ -z "$2" ]; then
        echo 'Expected argument!'
        exit 1
    fi
    set_option "$1" "$2"
    shift 2
done

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
        THIS=0
        CHAP_IDX=0
        MAXPARTS=0
        TOTAL=$(( $(ls *.mp3|wc -l) + 1 ))

        while read -r LINE; do
            VAL="$(grep -oP '^\.\K\d+')" <<< "$LINE"
            if [ -z "$VAL" ]; then
                VAL=$((LAST+1))
            fi
            THIS=$VAL
            if [ $CHAP_IDX -gt 0 ]; then
                PARTS=$((THIS-LAST))
                if [ $PARTS -le 0 ]; then
                    echo "Something's not right: non-positive parts number for chapter $CHAP_IDX"
                elif [ $PARTS -gt $MAXPARTS ]; then
                    MAXPARTS=$PARTS
                fi
                CHAPTER_LENGTHS[CHAP_IDX++]=$PARTS
            else
                ((CHAP_IDX++))
            fi
            LAST=$THIS
        done < "$CHAPTER_FILE"
        PARTS=$((TOTAL-LAST))
        if [ $PARTS -gt $MAXPARTS ]; then
            MAXPARTS=$PARTS
        fi
        CHAPTER_LENGTHS[CHAP_IDX++]=$PARTS


        MAXP=$(($(wc -m <<< "$MAXPARTS")-1))
        MAX=$(($(wc -l < "$CHAPTER_FILE" | wc -m )-1))
    fi
fi

if [ -z  "$CHAPTER_PREFIX" ]; then
    echo 'Warning: No language set!'
    if [ -n "$DEF_LANG" ]; then
        echo "(Default to $DEF_LANG)"
        set_option '-L' "$DEF_LANG"
    fi
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
for F in *.mp3; do
    echo "$F..."
    ((++NUM))
    if [ -n "$CHAPTER_FILE" ]; then
        if [ ! $CHAPTER_PARTS ]; then
            CHAP="$( sed "${NUM}q;d" "$CHAPTER_FILE" )"
            id3 "${TAG_ARGS[@]}" -n "$NUM" -t "$( printf "$NAME_T_CHAP" "$CHAPTER_PREFIX" "$NUM" "$CHAP" )" "$F"
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
            id3 "${TAG_ARGS[@]}" -n "$NUM" -t "$( printf "$NAME_T_CHAP" "$CHAPTER_PREFIX" "$CHAPNUM" "$CHAP" )" "$F"
            if [ ${CHAPTER_LENGTHS[CHAPLINE]} = 1 ]; then
                mv "$F" "$( printf "$NAME_F_CHAP" "$CHAPTER_PREFIX" "$CHAPNUM" "$CHAP" ).mp3"
            else
                mv "$F" "$( printf "$NAME_F_CHAP_PART" "$CHAPTER_PREFIX" "$CHAPNUM"  "$PART" "$CHAP" ).mp3"
            fi
            if [ $PART -ge ${CHAPTER_LENGTHS[CHAPLINE]} ]; then
                PART=0
            fi
        fi
    else
        id3 "${TAG_ARGS[@]}" -n "$NUM" -t "$( printf "$NAME_T_NO_CHAP" "$CHAPTER_PREFIX" "$NUM" )" "$F"
        mv "$F" "$( printf "$NAME_F_NO_CHAP" "$CHAPTER_PREFIX" "$NUM" ).mp3"
    fi
done

