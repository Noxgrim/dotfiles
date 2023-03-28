#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'
cd "$(dirname "$(readlink -f "$0")")" || exit 1

install_override() {
  if [ -d "/etc/$1" ]; then
    [ -e "/etc/$1/override.conf" ] && echo "Overwriting $(basename "$1" .d) override!"
    sudo cp -a {,/etc/}"$1"/override.conf
  else
    sudo cp -ar {,/etc/}"$1"
  fi
}

for F in home/*; do
  ln -nsfr "$F" "$HOME/.${F#*/}"
done

[ ! -d "$HOME"/.config ] && mkdir "$HOME"/.config
for F in config/*; do
  ln -nsfr "$F" "$HOME/.$F"
done

[ ! -d "$HOME"/.local/bin ] && mkdir "$HOME"/.local/bin
for F in bin/*; do
  ln -Lsfr {,"$HOME/.local/"}"$F"
done

ln -sfr .git-precommit '.git/hooks/pre-commit' # The censorer

[ -d "$HOME/.mpd/playlists" ] || mkdir -p "$HOME/.mpd/playlists"

# Do we have a battery?
if [ -n "$(find /sys/class/power_supply -iname 'BAT*' -print -quit)"  ]; then
  sudo cp scripts/{battery,notify}.sh /root
  sudo sed -i 's,\$(id -u "\$USER"),1000,g' /root/notify.sh # send messages to user
  sudo cp systemd/system/battery.{service,timer} /etc/systemd/system
  pacman -Qi acpid >/dev/null || sudo pacman -Sy acpid
  sudo systemctl daemon-reload
  sudo systemctl enable battery.timer
  sudo systemctl start battery.timer
  [ -d '/etc/udev/rules.d' ] || sudo mkdir -p '/etc/udev/rules.d'
  sudo cp -a {,/etc/}udev/rules.d/61-charging.rules
fi

# Setup auto-locking and -hibernation
install_override 'systemd/logind.conf.d'
install_override 'systemd/sleep.conf.d'
install_override 'systemd/system/getty@tty1.service.d'
# Do we have a backlight?
if [ -n "$(find /sys/class/backlight -mindepth 1 -iname '*' -print -quit)"  ]; then
  pacman -Qi acpilight >/dev/null || sudo pacman -Sy acpilight
  [ -d '/etc/udev/rules.d' ] || mkdir -p '/etc/udev/rules.d'
  sudo cp -a {,/etc/}'udev/rules.d/90-backlight.rules'
  sudo usermod -aG video "$USER"
  sudo udevadm control --reload
fi
sudo cp systemd/system/delayed-hibernation.service /etc/systemd/system
sudo killall -HUP systemd-logind
sudo systemctl daemon-reload
sudo systemctl enable delayed-hibernation.service
