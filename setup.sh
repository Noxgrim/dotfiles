for F in home/*; do
  ln -nsfr "$F" "$HOME/.${F#*/}"
done

[ ! -d "$HOME"/.config ] && mkdir "$HOME"/.config
for F in config/*; do
  ln -nsfr "$F" "$HOME/.$F"
done

ln -sfr .git-precommit '.git/hooks/pre-commit' # The censorer

[ -d "$HOME/.mpd/playlists" ] || mkdir -p "$HOME/.mpd/playlists"

# Do we have a battery?
if [ -n "$(find /sys/class/power_supply -iname 'BAT*' -print -quit)"  ]; then
  sudo cp scripts/{battery,notify}.sh /root
  sudo cp systemd/system/battery.{service,timer} /etc/systemd/system
  sudo pacman -Syu acpid
  sudo systemctl daemon-reload
  sudo systemctl enable battery.timer
  sudo systemctl start battery.timer
  [ -d '/etc/udev/rules.d' ] || sudo mkdir -p '/etc/udev/rules.d'
  sudo cp -a {,/etc/}udev/rules.d/61-charging.rules
fi
