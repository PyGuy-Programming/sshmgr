#!/bin/bash

HOSTS_FILE="$HOME/.local/bin/sshmgr/known_hosts.save"


case "$1" in
    -e|--edit)
        # wird ausgeführt wenn $1 "-e" oder "--edit" ist
	echo "opening known hosts file with nano..."
	nano "$HOSTS_FILE"
    ;;         # <-- das ist wie "break" in Python
    -u|--uninstall)
        # wird ausgeführt bei "-u" oder "--uninstall"
	echo "uninstalling sshmgr..."
	
	echo "removing directory $HOME/.local/bin/sshmgr..."
	rm -rf "$HOME/.local/bin/sshmgr" 

	echo "removing alias from .bashrc file in home directory..."
	sed -i '/alias sshmgr/d' $HOME/.bashrc
	echo "note that you need to reopen the terminal to apply"
	;;
    -h|--help)
	echo -e "Usage:\n \nsshmgr | opens host selection. exit py pressing CTRL+Q\n \nsshmgr -e / sshmgr --edit | opens the known hosts file with nano for you to edit it\n \nsshmgr -u / sshmgr --uninstall | uninstalls sshmgr (needs to be ran with sudo)\n \nsshmgr -h / sshmgr --help | shows this text for help"
	;;
    "")
	echo "opening known host selection..."
	selected=$(grep -v '^\s*#\|^\s*$' "$HOSTS_FILE" | fzf --prompt="SSH > ")

	[[ -z "$selected" ]] && exit 0

	user_ip="${selected%% - *}"
	name="${selected#* - }"

	echo "Verbinde mit $name ($user_ip)..."
	ssh "$user_ip"
    ;;
    *)
    # der "default" Fall — unbekanntes Argument
    echo -e "unknown option: $1\nrun sshmgr -h for available options"
    ;;
esac   # <-- "case" rückwärts geschrieben, so endet der Block
