# Don't wait the first time we're started
if [ "$(pgrep i3blocks)" == "$(cat '/tmp/'"$USER"'/audio_control/I3BLOCKS_PID')" ]; then
    mpc -q idle player &> /dev/null
else
    pgrep i3blocks > '/tmp/'"$USER"'/audio_control/I3BLOCKS_PID'
fi
mpc -qf "[[[%artist% • ][%album% • ][%title%]]|[%file%]]" current
mpc -qf "[[%title%]|[%file%]]" current
