#!/bin/bash
set -eu -o pipefail

CURR_DIR="$PWD"
UPDATEPACKAGE="$(readlink -f "${1:?"Expected packge containing update as first argument."}")"
[ -f "$UPDATEPACKAGE" ] || { echo "package must exist!" >&2 && exit 1; }
TARGET_DIR="$(readlink -m "${2:?"Expected target dir as second argument."}")"
[ -d "$TARGET_DIR" ] || mkdir -p "$TARGET_DIR"
find "$TARGET_DIR" -mindepth 1 | grep -qo . || echo 'Directory is empty. You may want to introduce a git repo later.'
TEMP_DIR="$(mktemp -d)"

echo 'Unpacking game…'
case "$(tr '[:upper:]' '[:lower:]' <<< "$UPDATEPACKAGE")" in
    *"-pc.zip") # probably pc package
        unzip -q "$UPDATEPACKAGE" -d "$TEMP_DIR"
        WORKING_DIR="$TEMP_DIR/$(basename "$UPDATEPACKAGE" '.zip')"
        # Remove the files we don't need to save space
        rm -r "$WORKING_DIR/lib/windows-i686"
        find "$WORKING_DIR" -maxdepth 1 -type f -iname '*.exe' -delete
        case "$(uname -m)" in # Platform specific libraries
            x86_64)
                rm -r "$WORKING_DIR/lib/linux-i686"
                ;;
            i686)
                rm -r "$WORKING_DIR/lib/linux-x86_64"
                ;;
            *)
                echo "Unknown architecture: $(uname -m)" >&2
        esac
        ;;
    *"-linux.tar.bz2") # probably linux package
        tar -xf "$UPDATEPACKAGE" --one-top-level="$TEMP_DIR"
        WORKING_DIR="$TEMP_DIR/$(basename "$UPDATEPACKAGE" '.tar.bz2')"
        # Remove the files we don't need to save space
        case "$(uname -m)" in # Platform specific libraries
            x86_64)
                rm -r "$WORKING_DIR/lib/linux-i686"
                ;;
            i686)
                rm -r "$WORKING_DIR/lib/linux-x86_64"
                ;;
            *)
                echo "Unknown architecture: $(uname -m)" >&2
        esac
        ;;
    *"-win.zip") # probably windows package
        echo 'Installing a game build for windows. This may not work…'
        unzip -q "$UPDATEPACKAGE" -d "$TEMP_DIR"
        WORKING_DIR="$TEMP_DIR/$(basename "$UPDATEPACKAGE" '.zip')"
        if [ -d "$TARGET_DIR/lib" ]; then
            rm -r "${WORKING_DIR:?"Temp dir empty?!"}/lib"
            mv "$TARGET_DIR/lib" "$WORKING_DIR/lib"
            find "$TARGET_DIR" -maxdepth 1 -type f -iname '*.sh' -exec cp '{}' "$WORKING_DIR" \;
        elif [ -n "${3:+set}" ]; then
            # Try to use a reference
            REFERENCE="$(readlink -f "$3")"
            if [ -d "$REFERENCE/lib" ]; then
                OUR_BUILD_NAME="$(find "$WORKING_DIR" -maxdepth 1 -type f -iname '*.exe' -print0 | head -zn 1 | sed -z 's|.*/\([^/]*\)\.exe$|\1|i' | tr -d '\0'; printf '_')"
                OUR_BUILD_NAME="${OUR_BUILD_NAME%_}"
                if [ -z "$OUR_BUILD_NAME" ]; then
                    rm -rf "$TEMP_DIR"
                    echo "Couldn't determine our build name!" >&2 && exit 1
                fi

                REF_BUILD_NAME="$(find "$REFERENCE" -maxdepth 1 -type f -iname '*.sh' -print0 | head -zn 1 | sed -z 's|.*/\([^/]*\)\.sh$|\1|i' | tr -d '\0'; printf '_')"
                REF_BUILD_NAME="${REF_BUILD_NAME%_}"
                if [ -z "$REF_BUILD_NAME" ]; then
                    rm -rf "$TEMP_DIR"
                    echo "Couldn't determine reference build name!" >&2 && exit 1
                fi

                rm -r "${WORKING_DIR:?"Temp dir empty?!"}/lib"
                cp -r "$REFERENCE/lib" "$WORKING_DIR/lib"
                find "$REFERENCE" -maxdepth 1 -type f -name "$REF_BUILD_NAME"'.sh' -exec cp '{}' "$WORKING_DIR/$OUR_BUILD_NAME.sh" \; # This file seems to always have the same content
                # This tries to rename the binary so it can be found by the start script
                find "${WORKING_DIR:?"Temp dir enpry?!"}/lib" -type f -name "$REF_BUILD_NAME" -exec bash -c '
                for FILE do
                    mv "$FILE" "$(dirname "$FILE")"/'"'${OUR_BUILD_NAME//"'"/"'\\''"}'"'
                done
                ' bash '{}' \;
            else
                rm -rf "$TEMP_DIR"
                echo 'Cannot install windows build: reference missing libraries!' >&2 && exit 1
            fi
        else
            rm -rf "$TEMP_DIR"
            echo 'Cannot install windows build: thrid argument (reference) not a directory!' >&2 && exit 1
        fi
        # Remove the files we don't need to save space
        [ -d  "$WORKING_DIR/lib/windows-i686" ] && rm -r "$WORKING_DIR/lib/windows-i686"
        find "$WORKING_DIR" -maxdepth 1 -type f -iname '*.exe' -delete
        case "$(uname -m)" in # Platform specific libraries
            x86_64)
                [ -d "$WORKING_DIR/lib/linux-i686" ] && rm -r "$WORKING_DIR/lib/linux-i686"
                ;;
            i686)
                [ -d "$WORKING_DIR/lib/linux-x86_64" ] && rm -r "$WORKING_DIR/lib/linux-x86_64"
                ;;
            *)
                echo "Unknown architecture: $(uname -m)" >&2
        esac
        ;;
    *)
        echo "Unknown package type: $1" >&2
        rm -rf "$TEMP_DIR"
        exit 1
esac

echo 'Moving files…'
if [ -d "$TARGET_DIR/.git" ]; then # If this is versioned, move repo
    mv "$TARGET_DIR/.git" "$WORKING_DIR"
fi

if [ -d "$TARGET_DIR/game/saves" ]; then # Copy saves
    mv "$TARGET_DIR/game/saves" "$WORKING_DIR/game"
fi

if [ -d "$TARGET_DIR/icons" ]; then # RDG stuff
    mv "$TARGET_DIR/icons" "$WORKING_DIR/icons"
elif [ -d "$TARGET_DIR/.renpydeskgen-icons" ]; then
    mv "$TARGET_DIR/.renpydeskgen-icons" "$WORKING_DIR/.renpydeskgen-icons"
fi

find "$TARGET_DIR" -maxdepth 1 -type f -iname 'screenshot[0-9][0-9][0-9][0-9].png' -exec mv  '{}' "$WORKING_DIR" \;
find "$TARGET_DIR" -maxdepth 1 -type f -iname 'note*' -exec mv  '{}' "$WORKING_DIR" \;

if [ -d "$WORKING_DIR/.git" ]; then
    echo 'Managing git…'
    # If we are versioned, unpack to improve git's compression? IDK
    command -v 'unrpa' > /dev/null &&
    find "$WORKING_DIR/game" -type f -iname '*.rpa' -print0 |\
        while IFS= read -r -d $'\0' RPA; do
            RPA_DIR="$(dirname "$RPA")"
            cd "$RPA_DIR" || exit 1
            unrpa "$RPA"
            rm "$RPA"
            cd "$CURR_DIR" || exit 1
    done
    # If we are versioned, decompile if necessary (git is optimized for plain text)
    if command -v 'unrpyc' > /dev/null; then unrpyc "$WORKING_DIR/game" | grep -oE 'Decompilation of [0-9]+( script)? files successful' || true; fi

    # Add new files
    git --git-dir "$WORKING_DIR/.git" --work-tree "$WORKING_DIR" add "$WORKING_DIR/."

    if [ -n "$(git --git-dir "$WORKING_DIR/.git" --work-tree "$WORKING_DIR" status --porcelain 2>&1)" ]; then
    # Prepare a commit message (let the hacking begin!)

    # Get the file that we would edit
    EDITOR='cat' git --git-dir "$WORKING_DIR/.git" --work-tree "$WORKING_DIR" commit -v > "$TEMP_DIR/COMMIT_FILE" 2> /dev/null || true # “Aborting due to empty commit message” returns error
    # Get some data we could pre-instert (requires rdg/renpy_desktop_generator.sh)
    if command -v rdg > /dev/null; then
        GAME_NAME="$(
            export RENPYDESKGEN_IS_SOURCED='true'
            source "$(which rdg)"
            CHECK_OPTIONAL_DEPENDENCIES='false'
            LOG_LEVEL=0
            DISPLAY_NAME=''

            check_dependencies
            find_renpy_root_dir "$WORKING_DIR"
            find_game_name
            echo "$GAME_NAME"
        )"
    else
        GAME_NAME="GAME_NAME"
    fi
    GAME_VERSION="$(sed -z 's/.*-\([^-]*\)-[^-]*$/\1/' <<< "$WORKING_DIR")"

    sed -i '1s/^.*$/&'"$GAME_NAME $GAME_VERSION"'\n'"$(git --git-dir "$WORKING_DIR/.git" --work-tree "$WORKING_DIR" config --get core.commentChar || echo '#'
    )"' ------------------------ >8 ------------------------\n# Comments are not supported. Do not change the line above!\n#/' "$TEMP_DIR/COMMIT_FILE"

    # Insert lines to hide or move potential spoilers in diff or changed files out of the way
    {
        INSERT_BEFORE="$(grep '^# Changes to be committed:$' "$TEMP_DIR/COMMIT_FILE" -n | cut -d: -f1)"
        head -n "$(bc <<< "${INSERT_BEFORE/%/-1}")" "$TEMP_DIR/COMMIT_FILE"
        echo '# SPOILER{{{'
        echo '# SPOILERBUMPER{{{' # Insert this if vim isn't used, just to be sure
        set +eu # For some reason this SIGPIPEs otherwise
        yes '#' | head -n "$(tput lines)"
        set -eu
        echo '# / SPOILERBUMPER}}}'
        tail -n+"$INSERT_BEFORE" "$TEMP_DIR/COMMIT_FILE"
        echo '# / SPOILER}}}'
        echo "# vim: foldmethod=marker"
    } > "$TEMP_DIR/COMMIT_EDITMSG"
    case "$EDITOR" in
        *vim)
            # force to ignore changes by runtime plugin
            EDITOR="$EDITOR -c 'set modeline modelines=1 foldmethod=marker' --cmd 'set modeline modelines=1 foldmethod=marker'"\
                git --git-dir "$WORKING_DIR/.git" --work-tree "$WORKING_DIR" commit --no-status -q -t "$TEMP_DIR/COMMIT_EDITMSG" --cleanup=scissors < /dev/tty
            ;;
        *)
            git --git-dir "$WORKING_DIR/.git" --work-tree "$WORKING_DIR" commit --no-status -q -t "$TEMP_DIR/COMMIT_EDITMSG" --cleanup=scissors < /dev/tty
            ;;
    esac || # if we didn't edit anything
        git --git-dir "$WORKING_DIR/.git" --work-tree "$WORKING_DIR" commit -q -F <(cat <<< "$GAME_NAME $GAME_VERSION") || true
    fi
fi

echo 'Installing new version…'
rm -r "$TARGET_DIR"
mv "$WORKING_DIR" "$TARGET_DIR"
rm -r "$TEMP_DIR"
