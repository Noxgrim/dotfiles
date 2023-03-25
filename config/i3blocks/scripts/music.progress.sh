export MPD_HOST="$(grep -Po '(?<=^password ")[^@]*' "$HOME/.mpdconf")@localhost"
mpc status  | sed "2q;d" | grep -o '[0-9]*:[0-9:/]*'
