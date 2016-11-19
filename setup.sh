# Set up simple links
echo "Starting setting up..."
ln -sfr zshrc         $HOME/.zshrc
ln -sfr bashrc        $HOME/.bashrc
ln -sfr Xresources    $HOME/.Xresources
ln -sfr xbindkeysrc   $HOME/.xbindkeysrc

ln -sfr tmux.conf     $HOME/.tmux.conf
ln -sfr i3            $HOME/.i3
ln -sfr i3blocks.conf $HOME/.i3blocks.conf

echo "Setting up Vim and Vim-esque programs..."
ln -sfr vim           $HOME/.vim
ln -sfr vimrc         $HOME/.vimrc
ln -sfr vimperator    $HOME/.vimperator
ln -sfr vimperatorrc  $HOME/.vimperatorrc

if [ ! -d $HOME/.config/dunst/ ]; then mkdir $HOME/.config/dunst/ fi
ln -sfr dunstrc       $HOME/.config/dunst/dunstrc

# Configure Mpd
ln -sfr mpd.conf ../.mpdconf
mkdir $HOME/.mpd
mkdir $HOME/.mpd/playlists
