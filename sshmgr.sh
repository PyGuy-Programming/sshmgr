#!/bin/bash

HOSTS_FILE="$HOME/.config/sshmgr/known_hosts.json"

if [ ! -f "$HOSTS_FILE" ]; then
  mkdir -p "$(dirname "$HOSTS_FILE")"
  cat <<'DEFAULT' >"$HOSTS_FILE"
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
-p | --ping)
  # ping all known hosts in parallel with fping
  echo "checking all hosts..."
  # bewusst unquoted: Worttrennung ist hier gewollt (Hosts enthalten keine Leerzeichen)
  fping $(jq -r '.hosts[].host' "$HOSTS_FILE") 2>&1
  ;;
-h | --help)
  # printing help/usage information
  echo -e "Usage:\n \nsshmgr | opens host selection. exit py pressing CTRL+Q\n \nsshmgr -e / sshmgr --edit | opens the known hosts file with standart editor for you to edit it\n \nsshmgr -p / sshmgr --ping | pings all known hosts in parallel\n \nsshmgr -h / sshmgr --help | shows this text for help"
  ;;
"")
  # starting selcetion of known hosts if no option is given
  # preview ruft dieses script selbst mit __info auf (siehe case unten)
  echo "opening known host selection..."
  selected=$(jq -r '.hosts[] | "\(.name)"' "$HOSTS_FILE" |
    fzf --prompt="SSH > " --preview="\"$0\" __info {}")

  [[ -z "$selected" ]] && exit 0

  host=$(jq -r --arg name "$selected" '.hosts[] | select(.name == $name) | .host' $HOSTS_FILE)
  user=$(jq -r --arg name "$selected" '.hosts[] | select(.name == $name) | .user' $HOSTS_FILE)
  port=$(jq -r --arg name "$selected" '.hosts[] | select(.name == $name) | .port' $HOSTS_FILE)
  jumphost=$(jq -r --arg name "$selected" '.hosts[] | select(.name == $name) | .jumphost' $HOSTS_FILE)

  # try conecting to the selected host
  if [ -z "$jumphost" ]; then
    echo "Conecting to $selected ($user@$host)..."
    ssh -p "$port" "$user@$host"
  else
    echo "Connecting to $selected ($user@$host) using $jumphost as jumphost"
    ssh -pJ "$port" "$jumphost" "$user@$host"
  fi
  ;;
__info)
  # internal: wird von der fzf preview aufgerufen, zeigt status + details
  info_host=$(jq -r --arg name "$2" '.hosts[] | select(.name == $name) | .host' "$HOSTS_FILE")

  if command -v fping >/dev/null 2>&1; then
    timeout 2 fping -c1 "$info_host" >/dev/null 2>&1 && echo "● online" || echo "○ offline"
    echo
  fi

  jq -r --arg name "$2" '.hosts[] | select(.name == $name) |
    "User:     \(.user)\nHost:     \(.host)\nPort:     \(.port // "?")\nJumphost: \(.jumphost | if . == null or . == "" then "-" else . end)"' "$HOSTS_FILE"
  if [ -z "$(jq -r --arg name "$2" '.hosts[] | select(.name == $name) | .name' "$HOSTS_FILE")" ]; then
    echo "(host not found)"
  fi
  ;;
*)
  # printing help if given unknown option
  echo -e "unknown option: $1\nrun sshmgr -h for available options"
  ;;
esac
