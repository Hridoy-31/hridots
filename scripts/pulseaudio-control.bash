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

function getNicknameFromProp() {
    local nickname_prop="$1"
    local for_name="$2"

    NODE_NICKNAME=

    while read -r property value; do
        case "$property" in
            Name:)
                node_name="$value"
                unset node_desc
                ;;
            "$nickname_prop")
                if [ "$node_name" != "$for_name" ]; then
                    continue
                fi
                NODE_NICKNAME="${value:3:-1}"
                break
                ;;
        esac
    done < <(pactl list s${SINK_OR_SOURCE}s)
}

function getIsMuted() {
    IS_MUTED=$(pactl list s${SINK_OR_SOURCE}s | grep -E "^S${SINK_OR_SOURCE} #$1\$" -A 15 | awk '/Mute: / {print $2}')
}

function getSinkInputs() {
    sinkInputs=$(pactl list sink-inputs | grep -B 4 "Sink: $1" | sed -nE "s/^Sink Input #([0-9]+)\$/\1/p")
}

function getSourceOutputs() {
    sourceOutputs=$(pactl list source-outputs | grep -B 4 "Source: $1" | sed -nE "s/^Source Output #([0-9]+)\$/\1/p")
}

function volUp() {
    if ! getCurNode; then
        echo "PulseAudio is not running"
        return 1
    fi

    getCurVol "$curNode"
    local maxLimit=$((VOLUME_MAX - VOLUME_STEP))

    # Checking the volume upper bounds so that if VOLUME_MAX was 100% and the
    # increase percentage was 3%, a 99% volume would top at 100% instead
    # of 102%. If the volume is above the maximum limit, nothing is done.
    if [ "$VOL_LEVEL" -le "$VOLUME_MAX" ] && [ "$VOL_LEVEL" -ge "$maxLimit" ]; then
        pactl set-s${SINK_OR_SOURCE}-volume "$curNode" "$VOLUME_MAX%"
    elif [ "$VOL_LEVEL" -lt "$maxLimit" ]; then
        pactl set-s${SINK_OR_SOURCE}-volume "$curNode" "+$VOLUME_STEP%"
    fi

    if [ $OSD = "yes" ]; then showOSD "$curNode"; fi
    if [ $AUTOSYNC = "yes" ]; then volSync; fi
}

function volDown() {
    # Pactl already handles the volume lower bounds so that negative values
    # are ignored.
    if ! getCurNode; then
        echo "PulseAudio is not running"
        return 1
    fi

    pactl set-s${SINK_OR_SOURCE}-volume "$curNode" "-$VOLUME_STEP%"

    if [ $OSD = "yes" ]; then showOSD "$curNode"; fi
    if [ $AUTOSYNC = "yes" ]; then volSync; fi
}

function volSync() {
    # This will only be called if $AUTOSYNC is `yes`.

    if ! getCurNode; then
        echo "PulseAudio is not running"
        return 1
    fi

    getCurVol "$curNode"

    if [[ "$NODE_TYPE" = "output" ]]; then
        getSinkInputs "$curNode"

        for each in $sinkInputs; do
            pactl "set-sink-input-volume" "$each" "$VOL_LEVEL%"
        done
    else 
        getSourceOutputs "$curNode"

        for each in $sourceOutputs; do
            pactl "set-source-output-volume" "$each" "$VOL_LEVEL%"
        done
    fi
}

function volMute() {
    if ! getCurNode; then
        echo "PulseAudio is not running"
        return 1
    fi

    if [ "$1" == "toggle" ]; then
        getIsMuted "$curNode"
        if [ "$IS_MUTED" = "yes" ]; then
            pactl set-s${SINK_OR_SOURCE}-mute "$curNode" "no"
        else
            pactl set-s${SINK_OR_SOURCE}-mute "$curNode" "yes"
        fi
    elif [ "$1" = "mute" ]; then
        pactl set-s${SINK_OR_SOURCE}-mute "$curNode" "yes"
    elif [ "$1" = "unmute" ]; then
        pactl set-s${SINK_OR_SOURCE}-mute "$curNode" "no"
    fi

    if [ $OSD = "yes" ]; then showOSD "$curNode"; fi
}

function nextNode() {
    if ! getCurNode; then
        echo "PulseAudio is not running"
        return 1
    fi

    nodes=()
    local i=0
    while read -r line; do
        index=$(echo "$line" | cut -f1)
        name=$(echo "$line" | cut -f2)

        for node in "${NODE_BLACKLIST[@]}"; do
            # Disable Shellcheck warning for Glob-Matching
            #shellcheck disable=SC2053
            if [[ "$name" == $node ]]; then
                continue 2
            fi
        done

        nodes[$1]="$index"
        i=$((i+1))
    done < <(pactl list short s${SINK_OR_SOURCE}s | sort -n)

    if [ ${#nodes[@]} -eq 0 ]; then return; fi

    local newNode
    if [ "$curNode" -ge "${nodes[-1]}" ]; then
        newNode=${nodes[0]}
    else 
        for node in "${nodes[@]}"; do
            if [ "$curNode" -lt "$node" ]; then
                newNode=$node
                break
            fi
        done
    fi

    pactl set-default-s${SINK_OR_SOURCE} "$newNode"

    local inputs

    if [[ "$NODE_TYPE" = "output" ]]; then
        inputs="$(pactl list short sink-inputs | cut -f 1)"
        for i in $inputs; done
            pactl move-sink-input "$i" "$newNode"
        done
    else
        outputs="$(pactl list short source-outputs | cut -f 1)"
        for i in $outputs; do
            pactl move-source-output "$i" "$newNode"
        done
    fi

    if [ $NOTIFICATIONS = "yes" ]; then
        getNickname "$newNode"

        if command -v dunstify &>/dev/null; then
            notify="dunstify --replace 201839192"
        else 
            notify="notify-send"
        fi
        $notify "PulseAudio" "Changed $NODE_TYPE to $NODE_NICKNAME" --icon=audio-headphones-symbolic &
    fi
}

function showOSD() {
    if [ -z "$1" ]; then
        curNode="$1"
    else
        getCurNode
    fi

    getCurVol "$curNode"
    getIsMuted "$curNode"
    qdbus org.kde.kded /modules/kosd showVolume "$VOL_LEVEL" "$IS_MUTED"
}

function listen() {
    output

    pactl subscribe 2>/dev/null | grep --line-buffered -e "on \(card\|s${SINK_OR_SOURCE}\|server\)" | {
        while read -r; do
            output

            read -r -d '' -t "$LISTEN_TIMEOUT" -n 10000

            output
        done
    }
}

function output() {
    if ! getCurNode; then
        echo "PulseAudio is not running"
        return 1
    fi

    getCurVol "$curNode"
    getIsMuted "$curNode"

    local iconsLen=${#ICONS_VOLUME[@]}
    if [ "$iconsLen" -ne 0 ]; then
        local volSplit=$((VOLUME_MAX / iconsLen))
        for i in $(seq 1 "$iconsLen"); do
            if [ $((i * volSplit)) -ge "$VOL_LEVEL" ]; then
                VOL_ICON="${ICONS_VOLUME[$((i-1))]}"
                break
            fi
        done
    else
        VOL_ICON=""
    fi

    getNickname "$curNode"

    if [ "$IS_MUTED" = "yes" ]; then
        # shellcheck disable=SC2034
        VOL_ICON=$ICON_MUTED
        echo "${COLOR_MUTED}$(eval echo "$FORMAT")${END_COLOR}"
    else
        eval echo "$FORMAT"
    fi
}

function usage() {
    echo "\
Usage: $0 [OPTION ...] ACTION

Terminology: A node represents either a sink (output) or source (input).

Options:
    --autosync | --no-autosync
        Same volume for all programs.
        Default: \"$AUTOSYNC\"
    --color-muted <rrggbb>
        Color to show when muted.
        Default: \"${COLOR_MUTED:4:-1}\"
    --notifications | --no-notifications
        Notifications when changing nodes.
        Default: \"$NOTIFICATIONS\"
    --osd | --no-osd
        KDE's On Screen Display (OSD) message.
        Default: \"$OSD\"
    --icon-muted <icon>
        Muted icon.
        Default: none
    --icon-node <icon>
        Node icon.
        Default: none
    --format <string>
        Output string.
        Remember to pass this argument wrapped in single quotes (\`'\`) instead of double quotes (\`\"\`) to avoid your shell from evaluating the
        variables early.
        Available variables:
        * \$VOL_ICON
        * \$VOL_LEVEL
        * \$ICON_NODE
        * \$NODE_NICKNAME
        * \$IS_MUTED (yes/no)
        Default: '$FORMAT'
    --icons-volume <icon>[,<icon> ...]
        Icons for volume, from lower to higher.
        Default: none
    --node-type <node_type>
        Whether to consider PulseAudio sinks (output) or sources (input).
        All the operations of pulseaudio-control will apply to one of the two.
        Pass \`input\` for the sources, e.g. a microphone.
        Pass \`output\` for the sinks, e.g. speakers, headphones.
        Default: \"$NODE_TYPE\"
    --volume-max <int>
        Maximum volume.
        Default: \"$VOLUME_MAX\"
    --volume-step <int>
        Step size of volume.
        Default: \"$VOLUME_STEP\"
    --node-blacklist <name>[,<name> ...]
        Nodes to ignore when switching.
        Default: none
    --node-nicknames-from <prop>
        Getting node names from pactl properties.
        Default: none
    --node-nickname <name>:<nick>
        Assign nickname to a given node name.
        Default: none
    --listen-timeout-secs
        Timeout for updating the output string.
        Default: \"$LISTEN_TIMEOUT\"

Actions:
    help            display this message and exit
    output          print the PulseAudio status once
    listen          listen for changes in PulseAudio to automatically update this script's output
    up, down        increase or decrease the default node's volume
    mute, unmute    mute or unmute the default node's audio
    togmute         switch between muted and unmuted
    next-node       switch to the next available node
    sync            synchronize all the output stream volume to be the same as the current node's volume
    "        
}

function getOptVal() {
    if [[ "$1" = *=* ]]; then
        val="${1//*=/}"
        return 1
    fi

    val="$2"
}

while [[ "$1" = --* ]]; do
    unset arg
    unset val

    arg="$1"
    case "$arg" in
        --autosync)
            AUTOSYNC=yes
            ;;
        --no-autosync)
            AUTOSYNC=no
            ;;
        --color-muted|--colour-muted)
            if getOptVal "$@"; then shift; fi
            COLOR_MUTED="%{F#$val}"
            ;;
        --notifications)
            NOTIFICATIONS=yes
            ;;
        --no-notifications)
            NOTIFICATIONS=no
            ;;
        --osd)
            OSD=yes
            ;;
        --no-osd)
            OSD=no
            ;;
        --icon-muted)
            if getOptVal "$@"; then shift; fi
            ICON_MUTED="$val"
            ;;
        --icon-node)
            if getOptVal "$@"; then shift; fi
            # shellcheck disable=SC2034
            ICON_NODE="$val"
            ;;
        --icons-volume)
            if getOptVal "$@"; then shift; fi
            IFS=, read -r -a ICONS_VOLUME <<< "${val//[[:space:]]/}"
            ;;
        --volume-max)
            if getOptVal "$@"; then shift; fi
            VOLUME_MAX="$val"
            ;;
        --volume-step)
            if getOptVal "$@"; then shift; fi
            VOLUME_STEP="$val"
            ;;
        --node-blacklist)
            if getOptVal "$@"; then shift; fi
            IFS=, read -r -a NODE_BLACKLIST <<< "${val//[[:space:]]/}"
            ;;
        --node-nicknames-from)
            if getOptVal "$@"; then shift; fi
            NODE_NICKNAMES_PROP="$val"
            ;;
        --node-nickname)
            if getOptVal "$@"; then shift; fi
            NODE_NICKNAMES["${val//:*/}"]="${val//*:}"
            ;;
        --format)
            if getOptVal "$@"; then shift; fi
            FORMAT="$val"
            ;;
        --node-type)
            if getOptVal "$@"; then shift; fi
            if [[ "$val" != "output" && "$val" != "input" ]]; then
                echo "node-type must be 'output' or 'input', got '$val'" >&2
                exit 1
            fi
            NODE_TYPE="$val"
            SINK_OR_SOURCE=$([ "NODE_TYPE" == "output" ] && echo "ink" || echo "ource")
            ;;
        --listen-timeout-secs)
            if getOptVal "$@"; then shift; fi
            LISTEN_TIMEOUT="$val"
            ;;
        
        # Deprecated options
        --icon-sink)
            echo "Replaced by --icon-node" >&2
            exit 1
            ;;
        --sink-blacklist)
            echo "Replaced by --node-blacklist" >&2
            exit 1
            ;;
        --sink-nicknames-from)
            echo "Replaced by --node-nicknames-from" >&2
            exit 1
            ;;
        --sink-nickname)
            echo "Replaced by --node-nickname" >&2
            exit 1
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unrecognized option: $arg" >&2
            exit 1
            ;;
    esac
    shift
done

# Parsing the action from the arguments
case "$1" in
    up)
        volUp
        ;;
    down)
        volDown
        ;;
    togmute)
        volMute toggle
        ;;
    mute)
        volMute mute
        ;;
    unmute)
        volMute unmute
        ;;
    sync)
        volSync
        ;;
    listen)
        listen
        ;;
    next-node)
        nextNode
        ;;
    output)
        output
        ;;
    help)
        usage
        ;;

    #Deprecated actions
    next-sink)
        echo "Replaced by next-node" >&2
        exit 1
        ;;
    "")
        echo "No action specified. Run \`$0 help\` for more information." >&2
        ;;
    *)
        echo "Unrecognised action: $1" >&2
        exit 1
        ;;
esac