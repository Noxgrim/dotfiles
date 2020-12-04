# Path to your oh-my-zsh installation.
export ZSH=/home/noxgrim/.oh-my-zsh

# Set name of the theme to load.
# Look in ~/.oh-my-zsh/themes/
# Optionally, if you set this to "random", it'll load a random theme each
# time that oh-my-zsh is loaded.
if [[ "$TTY" != /dev/tty[0-9] ]]; then
    ZSH_THEME="powerlevel10k/powerlevel10k"

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

source $ZSH/oh-my-zsh.sh

source /etc/locale.conf
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source "$HOME/.zsh-key-bindings.zsh"

export EDITOR=nvim


alias gcd1="\git clone --depth 1"
alias vim='\nvim'
alias lvim='\vim'
alias vimdiff='\nvim -d'
alias audio="$HOME/dotfiles/audioscripts/audio.sh -C"
alias ncmpcpp='\ncmpcpp --host=$MPD_HOST'
# uni stuff
alias pk-cc='\gcc -std=c99 -g -Wall -Wextra -Wpedantic -Wbad-function-cast -Wconversion -Wwrite-strings -Wstrict-prototypes'
function makesmallmkv() {
    for F in "$@"; do
        FILENAME="$(basename "$F")"
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


export EDITOR=nvim
export MANPAGER="nvim  --cmd 'let g:is_manpage=1' -c 'set ft=man' -"


#Load autojump
. /usr/share/autojump/autojump.zsh

if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi

#[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

function fat32copy {
    NUM=0
    TOTAL="$( find "$1" -type f | wc -l )"
    AC_DIR="$( dirname "$1" )"

    find "$1" -type f -print0 | while IFS= read -r -d $'\0' F; do
        ((NUM++))
        DEST="$(echo "$F" | sed -e 's/:/ -/g' -e 's/"/'\''/g' -e 's/>/›/g' -e 's/</‹/g' -e 's/[|\?*]/_/g' -e 's,\.\+\(/\|$\),\1,g' -e 's,\s*\+\(/\|$\),\1,g')"
        DIR="$(dirname "$DEST")"
        DIR="$2/${DIR#$AC_DIR}"
        FILE="$(basename "$DEST")"
        printf "\r\e[0K%3.2f%% (%d/%d): '%s'" "$(echo "scale=4; $NUM/$TOTAL*100" | bc)" $NUM $TOTAL "$FILE"
        if [ ! -d "$DIR" ]; then
            mkdir -p "$DIR"
        fi
        #echo Copy from "'$F'" to "'$DEST'"
        cp --no-clobber "$F" "$DIR/$FILE"
    done
    echo
}

function audiolength() {
#http://www.commandlinefu.com/commands/view/13459/get-the-total-length-of-all-videos-in-the-current-dir-in-hms
    [ -z "$1" ] && 1='.'
    find "$1" -type f -not -path '*/\.*' -iregex '.*\.\(mp3\|wma\|flac\|ogg\|wav\|opus\)' -print0 |\
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

function mvln() {
    if [ -d "$2" ]; then
        NAME="$(basename "$1")"
        mv "$1" "$2"
        ln -sr "$2/$NAME" "$1"
    else
        mv "$1" "$2"
        ln -sr "$2" "$1"
    fi
}
