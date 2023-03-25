export MPD_HOST="$(grep -Po '(?<=^password ")[^@]*' "$HOME/.mpdconf")@localhost"
