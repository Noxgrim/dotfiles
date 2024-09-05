if [ -e "/tmp/$USER/audio_control/BLOCKING" ]; then
    mpc status '%currenttime%/%totaltime%*'
else
    mpc status '%currenttime%/%totaltime%'
fi
