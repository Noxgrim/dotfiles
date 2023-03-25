for F in home/*; do
  ln -nsfr "$F" "$HOME/.${F#*/}"
done

[ ! -d "$HOME"/.config ] && mkdir "$HOME"/.config
for F in config/*; do
  ln -nsfr "$F" "$HOME/.$F"
done

ln -sfr passmenu "$HOME/.local/bin/"

ln -sfr .git-precommit '.git/hooks/pre-commit' # The censorer

[ -d "$HOME/.mpd/playlists" ] || mkdir -p "$HOME/.mpd/playlists"
