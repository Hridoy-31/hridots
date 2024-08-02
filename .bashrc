# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Disables Ctrl-S and Ctrl-Q (used to pause terminal)
stty -ixon

# Aliases
alias ..='cd ..'
alias ...='cd ../..'
alias install='sudo apt install'
alias update='sudo apt update'
alias upgrade='sudo apt upgrade'
alias uplist='apt list --upgradable'
alias remove='sudo apt autoremove'
alias l='exa -ll --color=always --group-directories-first'
alias ls='exa -al --header --icons --group-directories-first'
alias df='df -h'
alias free='free -h'
alias myip="ip -f inet address | grep inet | grep -v 'lo$' | cut -d ' ' -f 6,13 && curl ifconfig.me && echo ' external ip'"
alias x="exit"
alias bs='nano ~/.bashrc'
alias reload='source ~/.bashrc'
alias e="nano"
alias config="cd ~/.config"
alias downloads="cd ~/Downloads"
alias hi="notify-send 'Hi there!' 'Welcome to the Hridebian desktop! ' -i ''"
alias egrep='grep --color=auto'

# Environment variables
export PATH="~/scripts:$PATH" 
export PATH="~/.local/bin:$PATH"
export PATH="/usr/local/go/bin:$PATH"
export VISUAL=nano;
export EDITOR=nano;

# Color codes
RED="\\[\\e[1;31m\\]"
GREEN="\\[\\e[1;32m\\]"
YELLOW="\\[\\e[1;33m\\]"
BLUE="\\[\\e[1;34m\\]"
MAGENTA="\\[\\e[1;35m\\]"
CYAN="\\[\\e[1;36m\\]"
WHITE="\\[\\e[1;37m\\]"
ENDC="\\[\\e[0m\\]"

# Shell prompt
PS1="${MAGENTA}\@ ${GREEN}\u ${WHITE}at ${YELLOW}\h ${WHITE}in ${BLUE}\w \n${CYAN}\$${ENDC} "
