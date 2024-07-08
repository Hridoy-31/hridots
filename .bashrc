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
