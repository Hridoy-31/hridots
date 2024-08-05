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
