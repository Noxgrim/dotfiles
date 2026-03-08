#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

source "$SCRIPT_ROOT/data/shared/local_env.sh"

cd "$WORK_LOG_DIR" || exit 1
TIME="${1-"7 hour ago"}"
DIR="$(date +%Y-%m -d"$TIME")"
[ -d  "$DIR" ] || mkdir -p "$DIR"
nvim "$(date +%Y-%m/%F -d"$TIME").md" --cmd 'au BufNewFile *.md 0r'<(cat <<<'# '"$(date -I -d"$TIME")"$'\n* Working from ')'|$d' '+norm!2G$T(gE'

[ -z "$(ls -A "$DIR" 2>/dev/null)" ] && rmdir "$DIR"
