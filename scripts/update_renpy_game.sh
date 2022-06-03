#!/bin/bash
set -eu -o pipefail

CURR_DIR="$PWD"
DATE=( --date "${1?"Expected version date as first argument (may be empty if \`git\` isn't used)."}" )
UPDATEPACKAGE="$(readlink -f "${2:?"Expected packge containing update as second argument."}")"
[ -f "$UPDATEPACKAGE" ] || { echo "package must exist!" >&2 && exit 1; }
TARGET_DIR="$(readlink -m "${3:?"Expected target dir as third argument."}")"
[ -d "$TARGET_DIR" ] || mkdir -p "$TARGET_DIR"
( shopt -s nullglob dotglob; f=( "$TARGET_DIR"/* ); ((! ${#f[@]})) ) &&
    echo 'Directory is empty. You may want to introduce a git repo later.'

TEMP_DIR="$(mktemp -d)"

echo 'Unpacking game…'
case "$(tr '[:upper:]' '[:lower:]' <<< "$UPDATEPACKAGE")" in
    *"-pc.zip") # probably pc package
        unzip -q "$UPDATEPACKAGE" -d "$TEMP_DIR"
        WORKING_DIR="$TEMP_DIR/$(basename "$UPDATEPACKAGE" '.zip')"
        # Remove the files we don't need to save space
        [ -d "$WORKING_DIR/lib/windows-i686" ] && rm -r "$WORKING_DIR/lib/windows-i686"
        [ -d "$WORKING_DIR/lib/windows-x86_64" ] && rm -r "$WORKING_DIR/lib/windows-x86_64"
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
    *"-linux.tar.bz2") # probably linux package
        tar -xf "$UPDATEPACKAGE" --one-top-level="$TEMP_DIR"
        WORKING_DIR="$TEMP_DIR/$(basename "$UPDATEPACKAGE" '.tar.bz2')"
        # Remove the files we don't need to save space
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
    *"-win.zip") # probably windows package
        echo 'Installing a game build for windows. This may not work…'
        unzip -q "$UPDATEPACKAGE" -d "$TEMP_DIR"
        WORKING_DIR="$TEMP_DIR/$(basename "$UPDATEPACKAGE" '.zip')"
        if [ -d "$TARGET_DIR/lib" ]; then
            rm -r "${WORKING_DIR:?"Temp dir empty?!"}/lib"
            mv "$TARGET_DIR/lib" "$WORKING_DIR/lib"
            find "$TARGET_DIR" -maxdepth 1 -type f -iname '*.sh' -exec cp '{}' "$WORKING_DIR" \;
        elif [ -n "${4:+set}" ]; then
            # Try to use a reference
            REFERENCE="$(readlink -f "$4")"
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
        echo "Unknown package type: $3" >&2
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

if [ -d "$TARGET_DIR/.bu" ]; then # Copy backups
    mv "$TARGET_DIR/.bu" "$WORKING_DIR"
fi

if [ -d "$TARGET_DIR/icons" ]; then # RDG stuff
    mv "$TARGET_DIR/icons" "$WORKING_DIR/icons"
elif [ -d "$TARGET_DIR/.renpydeskgen-icons" ]; then
    mv "$TARGET_DIR/.renpydeskgen-icons" "$WORKING_DIR/.renpydeskgen-icons"
fi

find "$TARGET_DIR" -maxdepth 1 -type f -iname 'screenshot[0-9][0-9][0-9][0-9].png' -exec mv  '{}' "$WORKING_DIR" \;
find "$TARGET_DIR" -maxdepth 1 -type f -iname 'note*' -exec mv  '{}' "$WORKING_DIR" \;
find "$TARGET_DIR" -maxdepth 1 -type f -iname '*.patch' -exec mv  '{}' "$WORKING_DIR" \;

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
    GIT=(git --git-dir "$WORKING_DIR/.git" --work-tree "$WORKING_DIR")
    "${GIT[@]}" add "$WORKING_DIR/."
    (
        cd "$WORKING_DIR" || exit 1
        find "$WORKING_DIR" -maxdepth 1 -type f -iname '*.patch' -print0 | sort -z | xargs -r0n 1 git apply --allow-empty || true
    )

    # Add new files
    "${GIT[@]}" add "$WORKING_DIR/."

    if [ -n "$("${GIT[@]}" status --porcelain 2>&1)" ]; then
        # Get some data we could pre-instert (requires rdg/renpy_desktop_generator.sh)
        cat > "$WORKING_DIR/.git/hooks/prepare-commit-msg" << "EOF"
#!/usr/bin/env bash
set -eu -o pipefail
DIR="$(readlink -e ".")"
if command -v rdg > /dev/null; then
    eval "$(RENPYDESKGEN_CHECK_OPTIONAL_DEPENDENCIES=false rdg -qQ \
        -\! find_renpy_root_dir "$DIR" \
        -\! find_game_name "$DIR/game" \
        -\! read_renpy_config_string "$DIR/game" 'config.version' GAME_VERSION \
        -\? O+GAME_NAME,GAME_VERSION)"
else
    GAME_NAME="GAME_NAME"
    GAME_VERSION="$(sed -z 's/.*-\([^-]*\)-[^-]*$/\1/' <<< "$DIR")"
fi
COMMENT="$(git config --get core.commentChar || echo '#')"

if head -n1 "$1" | grep -q '^\s*$'; then
    sed -i '1s/^.*$/&'"$GAME_NAME $GAME_VERSION"'\n/' "$1"
fi

# Insert lines to hide or move potential spoilers in diff or changed files out of the way
INSERT_BEFORE="$(grep "^$COMMENT"' Changes to be committed:$' "$1" -n | cut -d: -f1 || echo 0)"
[ "$INSERT_BEFORE" = 0 ] && exit 0 # No status to hide
TMP="$(mktemp)"
{
    head -n "$(bc <<< "${INSERT_BEFORE/%/-1}")" "$1"
    echo "$COMMENT SPOILER{{{"
    echo "$COMMENT SPOILERBUMPER{{{" # Insert this if vim isn't used, just to be sure
    set +o pipefail # For some reason this SIGPIPEs otherwise
    yes "$COMMENT" | head -n "$(tput lines || printf 100)"
    set -o pipefail
    echo "$COMMENT / SPOILERBUMPER}}}"
    tail -n+"$INSERT_BEFORE" "$1"
    echo "$COMMENT / SPOILER}}}"
    echo "$COMMENT vim: foldmethod=marker"
} > "$TMP"
mv "$TMP" "$1"
EOF
        chmod u+x "$WORKING_DIR/.git/hooks/prepare-commit-msg"
        case "$EDITOR" in
            *vim|*'vim '*)
                # force to ignore changes by runtime plugin
                export EDITOR="$EDITOR -c 'set foldmethod=marker' --cmd 'set foldmethod=marker'" ;;
            *) ;;
        esac
        "${GIT[@]}" commit "${DATE[@]}" -vq || true
        "${GIT[@]}" tag -f "$("${GIT[@]}" show --no-patch --oneline | grep -o '\S*$' | sed 's/^[0-9]/b&/')"
    fi
fi

echo 'Installing new version…'
rm -r "$TARGET_DIR"
mv "$WORKING_DIR" "$TARGET_DIR"
rm -r "$TEMP_DIR"
cd "$CURR_DIR" || exit 1
