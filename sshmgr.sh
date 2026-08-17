#!/bin/bash

HOSTS_FILE="$HOME/.config/sshmgr/known_hosts.json"

if [ ! -f "$HOSTS_FILE" ]; then
  mkdir -p "$(dirname "$HOSTS_FILE")"
  cat << 'DEFAULT' > "$HOSTS_FILE"
{
  "hosts": []
}
DEFAULT
  echo "created empty hosts file at $HOSTS_FILE"
  echo "add your hosts there and run sshmgr again"
  exit 0
fi
jq -e '.hosts' "$HOSTS_FILE" >/dev/null 2>&1 || {
  echo "invalid json"
  exit 1
}

case "$1" in
-e | --edit)
  # wird ausgeführt wenn $1 "-e" oder "--edit" ist
  echo "opening known hosts file with nano..."
  $EDITOR "$HOSTS_FILE"
  ;;
-h | --help)
  # printing help/usage information
  echo -e "Usage:\n \nsshmgr | opens host selection. exit py pressing CTRL+Q\n \nsshmgr -e / sshmgr --edit | opens the known hosts file with standart editor for you to edit it\n \nsshmgr -h / sshmgr --help | shows this text for help"
  ;;
"")
  # starting selcetion of known hosts if no option is given
  echo "opening known host selection..."
  selected=$(jq -r '.hosts[] | "\(.name)"' "$HOSTS_FILE" | fzf --prompt="SSH > ")

  [[ -z "$selected" ]] && exit 0

  host=$(jq -r --arg name "$selected" '.hosts[] | select(.name == $name) | .host' $HOSTS_FILE)
  user=$(jq -r --arg name "$selected" '.hosts[] | select(.name == $name) | .user' $HOSTS_FILE)
  port=$(jq -r --arg name "$selected" '.hosts[] | select(.name == $name) | .port' $HOSTS_FILE)

  # try conecting to the selected host
  echo "Verbinde mit $selected ($user@$host)..."
  ssh -p "$port" "$user@$host"
  ;;
*)
  # printing help if given unknown option
  echo -e "unknown option: $1\nrun sshmgr -h for available options"
  ;;
esac
