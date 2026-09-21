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
# runs when $1 is "-e" or "--edit"
  echo "opening known hosts file with nano..."
  $EDITOR "$HOSTS_FILE"
  ;;
-p | --ping)
  # ping all known hosts in parallel with fping
  echo "checking all hosts..."
  # intentionally unquoted: word splitting is wanted here (host addresses contain no spaces)
  fping $(jq -r '.hosts[].host' "$HOSTS_FILE") 2>&1
  ;;
-h | --help)
  # printing help/usage information
  echo -e "Usage:\n \nsshmgr | opens host selection. exit py pressing CTRL+Q\n \nsshmgr -e / sshmgr --edit | opens the known hosts file with standart editor for you to edit it\n \nsshmgr -p / sshmgr --ping | pings all known hosts in parallel\n \nsshmgr -h / sshmgr --help | shows this text for help"
  ;;
"")
  # starting selection of known hosts if no option is given
  # the fzf preview calls this script itself with __info (see case below)
  echo "opening known host selection..."
  selected=$(jq -r '.hosts[] | "\(.name)"' "$HOSTS_FILE" |
    fzf --prompt="SSH > " --preview="\"$0\" __info {}")

  [[ -z "$selected" ]] && exit 0

  host=$(jq -r --arg name "$selected" '.hosts[] | select(.name == $name) | .host // empty' "$HOSTS_FILE")
  user=$(jq -r --arg name "$selected" '.hosts[] | select(.name == $name) | .user // empty' "$HOSTS_FILE")
  port=$(jq -r --arg name "$selected" '.hosts[] | select(.name == $name) | .port // empty' "$HOSTS_FILE")
  jumphost=$(jq -r --arg name "$selected" '.hosts[] | select(.name == $name) | .jumphost // empty' "$HOSTS_FILE")

  # defaults for optional fields
  [[ "$host" == "null" ]] && host=""
  [[ "$user" == "null" ]] && user=""
  [[ "$port" == "null" || -z "$port" ]] && port="22"
  [[ "$jumphost" == "null" ]] && jumphost=""

  if [ -z "$host" ]; then
    echo "error: no host address found for '$selected'"
    exit 1
  fi

  if [ -n "$user" ]; then
    dest="$user@$host"
  else
    dest="$host"
  fi

  # try connecting to the selected host
  if [ -z "$jumphost" ]; then
    echo "Connecting to $selected ($dest)..."
    ssh -p "$port" "$dest"
  else
    echo "Connecting to $selected ($dest) using $jumphost as jumphost"
    ssh -p "$port" -J "$jumphost" "$dest"
  fi
  ;;
__info)
  # internal: called by the fzf preview, shows status + details
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
