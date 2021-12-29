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
# ln -sfr vimperator    $HOME/.vimperator
# ln -sfr vimperatorrc  $HOME/.vimperatorrc

if [ ! -d $HOME/.config ]; then mkdir $HOME/.config; fi
ln -sfr rofi $HOME/.config/rofi
ln -sfr paru $HOME/.config/paru
ln -sfr alacritty/ $HOME/.config/alacritty
ln -sfr zathura $HOME/.config/zathura
ln -sfr neovim $HOME/.config/nvim
ln -sfr latexmkrc $HOME/.latexmkrc

if [ ! -d $HOME/.config/dunst/ ]; then mkdir $HOME/.config/dunst/; fi
ln -sfr dunstrc       $HOME/.config/dunst/dunstrc

ln -sfr passmenu "$HOME/.local/bin/"

ln -sfr .git-precommit '.git/hooks/pre-commit' # The censorer

# Configure Mpd
ln -sfr mpd.conf $HOME/.mpdconf
mkdir $HOME/.mpd
mkdir $HOME/.mpd/playlists
ln -sfr ncmpcpp $HOME/.ncmpcpp
