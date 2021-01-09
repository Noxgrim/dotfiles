#!/bin/bash
# This script should make it possible to stream an application in Discord with
# audio which does not seem possible at the time of writing.
# This is archived by routing the application audio through the users microphone
# so that other participants can hear it too. While by far not as elegant as
# Discord's native audio feature, it shall suffice until the Discord team
# decides to grace Linux users with a audio streaming feature.
# (As you can see this is very ugly and hacky and you are allowed to disown me
#  for that…)
#
# The first argument must be the name of the application that shall be
# re-routed. (this is matched against the output of `pactl list sink-inputs`)
# This may be wrong iif the application has opened multiple sinks… You may want
# to check it afterwards.
set -eu -o pipefail

# Now we try to find the sink-input (and sink-output) of the involved
# applications to be able to set their targets correctly
TARGET_SI="$(tr '[:upper:]' '[:lower:]' <<< "${1?"Expected target application!"}")"
TARGET_SI="$(pactl list sink-inputs | tr '[:upper:]' '[:lower:]' |
    sed -n '/^sink input/,/^\s*$/{s/^sink input #\([0-9]*\)/\1/p;/'"$(
    # shellcheck disable=SC2001 # escape the characters
    sed 's/./[&]/g' <<< "$TARGET_SI")"'/p}' |
    grep -B1 "$TARGET_SI" | grep '[0-9]\+' | tail -n1 || true)"
[ -z "$TARGET_SI" ] && { echo "target $1 not found or playing back!" >&2; exit 1; }

DISCORD_SO="$(pactl list source-outputs | tr '[:upper:]' '[:lower:]' |
    sed -n '/^source output/,/^\s*$/{s/^source output #\([0-9]*\)/\1/p;/discord/p}' | grep -iB1 'discord' | grep '[0-9]\+' | tail -n1 || true)"
[ -z "$DISCORD_SO" ] && { echo "Discord not found or recording!" >&2; exit 1; }


# shellcheck source=/home/noxgrim/.device_specific/default_sink.sh
source "$HOME/.device_specific/default_sink.sh"
# shellcheck source=/home/noxgrim/.device_specific/default_source.sh
source "$HOME/.device_specific/default_source.sh"

# Decide which sinks and sources to use. The files that were sourced earlier
# should export two arrays `SINKS` and `SOURCES` that define the names (not the
# decriptions!) of the sinks/sources to be used in order of precedence (the
# first match will be chosen)
for SINK in "${SINKS[@]}"; do
    SINK_DATA="$(pactl list sinks | sed -n '/^\s*Name: '"$SINK"'/,/^\s*$/p')"
    if [ -n "$SINK_DATA" ]; then
        break
    fi
done
for SOURCE in "${SOURCES[@]}"; do
    SOURCE_DATA="$(pactl list sources | sed -n '/^\s*Name: '"$SOURCE"'/,/^\s*$/p')"
    if [ -n "$SOURCE_DATA" ]; then
        break
    fi
done


# Load the required modules, if necessary
if ! pactl list sinks | grep -q '^\s*Name:\s*null\s*'; then
    # loaded as fake output for Discord to record from
    pactl load-module module-null-sink sink_name=null
    LOADED_NULL='true'
fi
if ! pactl list sinks | grep -q '^\s*Name:\s*combined\(_discord\)\?\s*'; then
    # the application shall output to the fake output and the normal output
    pactl load-module module-combine-sink sink_name=combined_discord slaves=null,"$SINK"
    pactl update-sink-properties combined_discord device.description="Discord Hack Combined Sink"
elif [ "${LOADED_NULL:-}" == 'true' ]; then # we may have to re-load the all combining sink
    if pactl list sinks | grep -q '^\s*Name:\s*combined\s*'; then
        pactl unload-module "$(pactl list modules | grep sink_name=combined -B2 | sed -n 's/Module #\([0-9]*\).*/\1/p')"
        # The combine module does not seem to combine all sinks all the time so we
        # combine the defined sinks if they are present
        pactl load-module module-combine-sink sink_name=combined slaves="null,$(
        for SINK in "${SINKS[@]}"; do
            SINK_DATA="$(pactl list sinks | sed -n '/^\s*Name: '"$SINK"'/,/^\s*$/p')"
            if [ -n "$SINK_DATA" ]; then
                printf '%s,' "$SINK"
            fi
        done | sed 's/,$//')"
        # Alternatively you could use this to combine every sink (regardless whether it's sensible)
        # pactl load-module module-combine-sink sink_name=combined slaves="$(pactl list sinks | sed -n 's/^\s*Name: //p' | sed -z 's/\n/,/g;s/,$//')"

    fi
fi
if pactl list sinks | grep -q '^\s*Name:\s*combined_discord\s*'; then
    COMBINED='combined_discord'
elif pactl list sinks | grep -q '^\s*Name:\s*combined\s*'; then
    COMBINED='combined'
else
    echo 'No combined sink found?' >&2 && exit 1
fi

# The loopback is used to add the microphone output to the null output so that
# the participants can hear the application as well as the stramer.
# We may want to set a new loopback target
if pactl list modules | grep -q module-loopback; then
    pactl unload-module module-loopback
fi

pactl load-module module-loopback sink=null source="$SOURCE"

# Do the actual moving
pactl move-sink-input "$TARGET_SI" "$COMBINED"
pactl move-source-output "$DISCORD_SO" null.monitor
