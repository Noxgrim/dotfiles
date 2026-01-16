#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'


step() {
  [ -d "/tmp/$USER/mouse" ] || mkdir -p "/tmp/$USER/mouse"
  "$SCRIPT_ROOT/externallibs/wl-find-cursor" -p >> "/tmp/$USER/mouse/drag"
}
cancel() {
  rm -f "/tmp/$USER/mouse/drag"
}
perform() {
  "$SCRIPT_ROOT/externallibs/wl-find-cursor" -p >> "/tmp/$USER/mouse/drag"
  local lx='' ly='' dist cx cy
  while IFS=' ' read -r x y; do
    if [ -n "$lx" ]; then
      dist=$(bc <<< "sqrt(($x- $lx)^2+($x- $lx)^2)")
      [ "$dist" = 0 ] && continue
      cx="$lx" cy="$ly"
      lx=$(bc -l <<< "($x- $lx)/$dist")
      ly=$(bc -l <<< "($y- $ly)/$dist")
      for ((i=0;i<dist;++i)); do
        cx=$(bc -l <<< "$cx+ $lx")
        cy=$(bc -l <<< "$cy+ $ly")
        swaymsg seat - cursor set -- "${cx%.*}" "${cy%.*}"
      done
      swaymsg seat - cursor set -- "$x" "$y"
    else
      swaymsg seat - cursor set -- "$x" "$y"
      "$SCRIPT_ROOT/externallibs/wl-find-cursor"
      swaymsg seat - cursor press button"$1"
      # ydotool click "4${1}"
    fi
    lx="$x" ly="$y"
  done < "/tmp/$USER/mouse/drag"
  # ydotool click "8${1}"
  swaymsg seat - cursor release button"$1"
  cancel
}

case "$1" in
  record) step;;
  perform) perform "${2-1}";;
  cancel) cancel;;
esac
