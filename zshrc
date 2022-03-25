# Path to your oh-my-zsh installation.
export ZSH=/home/noxgrim/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
if [ -n "${DISPLAY+.}" ]; then
    ZSH_THEME="zsh-theme-powerlevel10k/powerlevel10k"

    POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir vcs)
    POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status root_indicator background_jobs vi_mode command_execution_time)
    DEFAULT_USER=$USER
else
    ZSH_THEME="candy"
fi

# CASE_SENSITIVE="true"
# HYPHEN_INSENSITIVE="true"
# DISABLE_AUTO_UPDATE="true"
# export UPDATE_ZSH_DAYS=13
# DISABLE_LS_COLORS="true"
# DISABLE_AUTO_TITLE="true"
# ENABLE_CORRECTION="true"
  COMPLETION_WAITING_DOTS="true"
# DISABLE_UNTRACKED_FILES_DIRTY="true"
  HIST_STAMPS="yyyy-mm-dd"
# ZSH_CUSTOM=/path/to/new-custom-folder
plugins=(git vi-mode)

# User configuration

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
export MANPATH="/usr/local/man:$MANPATH"
[ -d "$HOME/.local/share/zsh/complete" ] && fpath=( "$HOME/.local/share/zsh/complete" $fpath )

source $ZSH/oh-my-zsh.sh

source /etc/locale.conf
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source "$HOME/.zsh-key-bindings.zsh"

export EDITOR=nvim

# for tenacity
[ -d /opt/wxgtk-dev/lib ]  && export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:/opt/wxgtk-dev/lib"


alias gcd1="\git clone --recuse-submodules --depth 1"
alias glg='git log'
alias 'glg!'='git log --stat'
alias vim='\nvim'
alias lvim='\vim'
alias vimdiff='\nvim -d'
alias audio="$HOME/dotfiles/audioscripts/audio.sh -C"
alias ncmpcpp='\ncmpcpp --host=$MPD_HOST'
alias r='ranger'
# uni stuff
alias pk-cc='\gcc -std=c99 -g -Wall -Wextra -Wpedantic -Wbad-function-cast -Wconversion -Wwrite-strings -Wstrict-prototypes'
function makesmallmkv() {
    for F in "$@"; do
        local FILENAME="$(basename "$F")"
        FILENAME="${FILENAME%.*}"
        mv "$F" "___temp___$F"
        ffmpeg -i "___temp___$F" -vf scale=480:-2,setsar=1:1,fps=fps=1\
            -c:v  libx265 -crf 28 -strict -2 -c:a opus -b:a 20k\
            "$FILENAME".mkv &&
            rm "___temp___$F"
        # ffmpeg -i "___temp___$F" -vf scale=720:-2,setsar=1:1,fps=fps=1\
    done
}
function pdfc() {
    gs\
      -q -dNOPAUSE -dBATCH -dSAFER \
      -sDEVICE=pdfwrite \
      -dCompatibilityLevel=1.3 \
      -dPDFSETTINGS=/screen \
      -dEmbedAllFonts=true \
      -dSubsetFonts=true \
      -dColorImageDownsampleType=/Bicubic \
      -dColorImageResolution="$1" \
      -dGrayImageDownsampleType=/Bicubic \
      -dGrayImageResolution="$1" \
      -dMonoImageDownsampleType=/Bicubic \
      -dMonoImageResolution="$1" \
      -sOutputFile="$3" \
      "$2"
}
function mkpdf() {
    latexmk -pdf "$1"
    latexmk -c
}

function urg() {
    "$HOME/dotfiles/scripts/update_renpy_game.sh" "$@"
    cd "$PWD"
}

function discordstreamHACK() {
    "$HOME/dotfiles/audioscripts/discord_stream_hack.sh" "$@"
}


export EDITOR=nvim
export MANPAGER="nvim  --cmd 'let g:is_manpage=1' -c 'set ft=man' -c 'Man!' -"

#Load autojump
. /usr/share/autojump/autojump.zsh

if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi

#[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

function fat32copy {
    [ $# -lt 1 ] && echo 'fat32copy: missing file operand' >&2 && return 1
    [ $# -lt 2 ] && echo 'fat32copy: missing destination operand' >&2 && return 1
    [ ! -d "${@[-1]}" ] && echo "fat32copy: target '${@[-1]}' is not a directory" >&2 && return 1
    local NUM=0 DEST DIR FILE
    local TOTAL="$( find "${@:1:-1}" -type f | wc -l )"
    local COMMON="$(printf "%s/\x0" "${@:1:-1}" | sed -ze '$!{N;s/^\(.*\).*\x0\1.*$/\1\x0\1/;D;}' | sed '$s/\x0$//'|\
      tr '\000-\037|\\?*' '[_*]' |\
      sed -e 's/:/ -/g' -e 's/"/'\''/g' -e 's/>/›/g' -e 's/</‹/g' -e 's,\.\+\(/\|$\),\1,g' -e 's,\s*\+\(/\|$\),\1,g' -e 's,/[^/]*$,,')"


    find "${@:1:-1}" -type f -print0 | while IFS= read -r -d $'\0' F; do
        ((NUM++))
        DEST="$(printf "%s" "$F" | tr '\000-\037|\\?*' '[_*]' | sed -e 's/:/ -/g' -e 's/"/'\''/g' -e 's/>/›/g' -e 's/</‹/g' -e 's,\.\+\(/\|$\),\1,g' -e 's,\s*\+\(/\|$\),\1,g')"
        DIR="${DEST%/*}"
        DIR="${@[-1]}/${DIR#$COMMON}"
        FILE="$(basename "$DEST")"
        printf "\r\e[0K%3.2f%% (%d/%d): '%s'" "$(echo "scale=4; $NUM/$TOTAL*100" | bc)" $NUM $TOTAL "$FILE"
        if [ ! -d "$DIR" ]; then
            mkdir -pv "$DIR"
        fi
        cp --no-clobber "$F" "$DIR/$FILE"
    done
    echo
}

function audiolength() {
#http://www.commandlinefu.com/commands/view/13459/get-the-total-length-of-all-videos-in-the-current-dir-in-hms
    find "${1-.}" "${@:2}" -type f -not -path '*/\.*' -iregex '.*\.\(mp3\|wma\|flac\|ogg\|wav\|opus\)' -print0 |\
        xargs -0 mplayer -vo dummy -ao dummy -identify 2>/dev/null |\
        perl -nle '/ID_LENGTH=([0-9\.]+)/ && ($t +=$1) && printf "%20d d %02d:%02d:%02d\n",$t/86400,$t/3600%24,$t/60%60,$t%60' |\
        tail -n 1
}

function qbg() {
    "$@">/dev/null&disown
}
function rqbg() {
    "$@"&>/dev/null&disown
}

function qbgz() {
    zathura "$@">/dev/null&disown
}
function rqbgz() {
    zathura "$@"&>/dev/null&disown
}

function qbgx() {
    xournalpp "$@">/dev/null&disown
}
function rqbgx() {
    xournalpp "$@"&>/dev/null&disown
}

compdef qbg=time rqbg=qbg qbgz=zathura rqbgz=qbgz qbgx=xournalpp rqbgx=qbgx 2>/dev/null

function mvln() {
    if [ -d "$2" ]; then
        local NAME="$(basename "$1")"
        mv "$1" "$2"
        ln -sr "$2/$NAME" "$1"
    else
        mv "$1" "$2"
        ln -sr "$2" "$1"
    fi
}
function daysspanning() {
  # we have to round with +60*60*12  because of a funny concept called summer time
  local DAYS="$((($(date -d"${2-today}" +%s)-$(date -d"${1?"Need date."}" +%s)+60*60*12)/(60*60*24)))"
  printf '%s\n' "$((${DAYS#-}+1))"
}
function installbandcamp() {
    local MINUS_ARTIST NUM_LEN PWD_OLD A BASENAME EXT FILE NEW_NAME ALBUM_ARTIST ALBUM
    for A in "$@"; do
        case "$A" in
            -*)
                IFS=- read -r _ MINUS_ARTIST <<< "$A"
                ;;
            *)
                BASENAME="${${A##*/}%.zip}"
                DIR="$(sed 's,\(\([^-]-\)\{'"${MINUS_ARTIST:-0}"'\}[^-]*\) - ,\1/,' <<< "$BASENAME")"
                IFS=/ read -r ALBUM_ARTIST ALBUM <<< "$DIR"
                echo creating "‘$DIR’"
                mkdir -p "$DIR"
                PWD_OLD="$PWD"
                cd "$DIR" || exit 1
                unzip "$A" > /dev/null
                find . -type f -not -iname 'cover.*' -print0 | sed -z 's/.*\.//' | uniq -z |\
                    while read -r -d$'\0' EXT; do
                        NUM_LEN="$(find . -type f -name "*.$EXT" -print0 | tr -dc '\000' | wc -c | wc -c)"
                        ((NUM_LEN--))
                        find . -type f -name "*.$EXT" -print0 | cut -d/ -f2- -z |\
                        while read -r -d$'\0' FILE; do
                            NEW_NAME="${FILE#*" - $ALBUM - "}"
                            if [ "$NEW_NAME" != "$FILE" ]; then
                                mv -- "$FILE" "$NEW_NAME"
                            fi
                            if [[ "$NEW_NAME" =~ ^[0-9] ]]; then
                                mv -- "$NEW_NAME" "$(printf "%0${NUM_LEN}d. %s" \
                                  "$(cut -d\  -f1 <<< "$NEW_NAME")" "$(cut -d\  -f2- <<< "$NEW_NAME")")"
                            fi
                        done
                    done
                MINUS_ARTIST=
                cd "$PWD_OLD" || exit
                ;;
        esac
    done
}
