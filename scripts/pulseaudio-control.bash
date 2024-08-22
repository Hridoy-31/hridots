#!/usr/bin/env bash

# Ignore warnings about unused variables
# shellcheck disable=SC2034
ICON_SINK="Replaced by ICON_NODE, see https://github.com/marioortizmanero/polybar-pulseaudio-control/releases/tag/v3.0.0"
SINK_NICKNAME="Replaced by NODE_NICKNAME, see https://github.com/marioortizmanero/polybar-pulseaudio-control/releases/tag/v3.0.0"


AUTOSYNC="no"
COLOR_MUTED="%{F#FF0000}"
ICON_MUTED=
ICON_NODE=
NODE_TYPE="output"
NOTIFICATIONS="no"
OSD="no"
NODE_NICKNAMES_PROP=
VOLUME_STEP=2
VOLUME_MAX=130
LISTEN_TIMEOUT=0.05

# Ignore warnings about variables being used in single quotes
# shellcheck disable=SC2016
FORMAT='$VOL_ICON ${VOL_LEVEL}%  $ICON_NODE $NODE_NICKNAME'
declare -A NODE_NICKNAMES
declare -a ICONS_VOLUME
declare -a NODE_BLACKLIST

SINK_OR_SOURCE="ink"

# Environment & global constants
# Some pactl calls depend on English output
export LC_ALL=C 
END_COLOR="%{F-}"

function getCurNode() {
    if ! pactl info &>/dev/null; then return 1; fi
    
    local curNodeName

    curNodeName=$(pactl info | awk "/Default S${SINK_OR_SOURCE}: / {print \$3}")
    curNode=$(pactl list s${SINK_OR_SOURCE}s | grep -B 4 -E "Name: $curNodeName\$" | sed -nE "s/^S${SINK_OR_SOURCE} #([0-9]+)$/\1/p")
}

function getCurVol() {
    VOL_LEVEL=$(pactl list s${SINK_OR_SOURCE}s | grep -A 15 -E "^S${SINK_OR_SOURCE} #$1\$" | grep 'Volume:' | grep -E -v 'Base Volume:' | awk -F : '{print $3; exit}' | grep -o -P '.{0,3}%' | sed 's/.$//' | tr -d ' ')
}

function getNodeName() {
    nodeName=$(pactl list s${SINK_OR_SOURCE}s short | awk -v sink="$1" "{ if (\$1 == sink) {print \$2} }")
    portName=$(pactl list s${SINK_OR_SOURCE}s | grep -e "S${SINK_OR_SOURCE} #" -e 'Active Port: ' | sed -n "/^S${SINK_OR_SOURCE} #$1\$/,+1p" | awk '/Active Port: / {print $3}')
}

function getNickname() {
    getNodeName "$1"
    unset NODE_NICKNAME

    if [ -n "$nodeName" ] && [ -n "$portName" ] && [ -n "${NODE_NICKNAMES[$nodeName/$portName]}" ]; then
        NODE_NICKNAME="${NODE_NICKNAMES[$nodeName/$portName]}"
    elif [ -n "$nodeName" ] && [ -n "${NODE_NICKNAMES[$nodeName]}" ]; then
        NODE_NICKNAME="${NODE_NICKNAMES[$nodeName]}"
    elif [ -n "$nodeName" ]; then
        for glob in "${!NODE_NICKNAMES[@]}"; do
            # Disable Shellcheck warning for glob matching
            # Shellcheck disable=SC2053
            if [[ "$nodeName/$portName" == $glob ]] || [[ "$nodeName" == $glob ]]; then
                NODE_NICKNAME="${NODE_NICKNAMES[$glob]}"
                NODE_NICKNAMES["$nodeName"]="$NODE_NICKNAME"
                break
            fi
        done
    fi

    if [ -z "$NODE_NICKNAME" ] && [ -n "$nodeName" ] && [ -n "$NODE_NICKNAMES_PROP" ]; then
        getNicknameFromProp "$NODE_NICKNAMES_PROP" "$nodeName"
        NODE_NICKNAMES["$nodeName"]="$NODE_NICKNAME"
    elif [ -z "$NODE_NICKNAME" ]; then
        NODE_NICKNAME="S${SINK_OR_SOURCES} #$1"
    fi
}