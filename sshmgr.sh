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

# optional setting in known_hosts.json: "kitten_ssh": true|false (default false)
# when true, connections go through kitty's ssh kitten if we are inside kitty
kitten_ssh=$(jq -r '.kitten_ssh // false' "$HOSTS_FILE")

# ---------------------------------------------------------------------------
# adding hosts
#
# "sshmgr -a <name> <host> [user] [port] [jumphost]" writes the entry straight
# away. Plain "sshmgr -a" opens a form that is drawn here: the terminal is put
# into raw mode so every keystroke can be handled, and each field is a real text
# box with the caret inside it.
# ---------------------------------------------------------------------------

# the fields, in the order they are shown, asked for and written
ADD_KEYS=(name host user port jumphost)

# prints a json object of {field: message} for everything that keeps the entry
# from being saved; an empty object means the entry is good to go.
# usage: add_problems <name> <host> <user> <port> <jumphost>
add_problems() {
  jq -n --arg name "${1:-}" --arg host "${2:-}" --arg user "${3:-}" \
    --arg port "${4:-}" --arg jumphost "${5:-}" --slurpfile h "$HOSTS_FILE" '
    (($h[0].hosts // []) | map(select(.name == $name))) as $dupe
    | (if $name == "" then {name: "a name is required"} else {} end)
    + (if ($name != "" and ($dupe | length) > 0)
       then {name: "already taken by another host"}
       else {} end)
    + (if $host == "" then {host: "a host address is required"} else {} end)
    + (if $port == "" then {}
       elif ($port | test("^[0-9]+$") | not) then {port: "must be a number"}
       elif (($port | tonumber) < 1 or ($port | tonumber) > 65535)
       then {port: "must be between 1 and 65535"}
       else {} end)'
}

# appends the entry to the hosts file, leaving empty fields out
# usage: add_write <name> <host> <user> <port> <jumphost>
add_write() {
  local tmp="${HOSTS_FILE}.tmp.$$"

  jq --arg name "${1:-}" --arg host "${2:-}" --arg user "${3:-}" \
    --arg port "${4:-}" --arg jumphost "${5:-}" '
      .hosts += [{name: $name, host: $host}
                 + (if $user     == "" then {} else {user: $user} end)
                 + (if $port     == "" then {} else {port: $port} end)
                 + (if $jumphost == "" then {} else {jumphost: $jumphost} end)]
    ' "$HOSTS_FILE" >"$tmp" && mv "$tmp" "$HOSTS_FILE"
}

# --------------------------------------------------------------------------
# the add form
#
# state lives in ADD_VALUES (one entry per ADD_KEYS), ADD_FOCUS is the index of
# the field being edited and ADD_CARET the position inside it.
# --------------------------------------------------------------------------

# the few colours the form needs, skipped entirely when NO_COLOR is set
add_colors() {
  # reverse video is what makes the caret readable; it survives NO_COLOR
  ADD_C_CARET=$'\e[1;7m'
  if [ -n "${NO_COLOR:-}" ]; then
    ADD_C_OFF= ADD_C_LABEL= ADD_C_VALUE= ADD_C_FRAME=
    ADD_C_FOCUS= ADD_C_ERR= ADD_C_OK= ADD_C_HINT=
  else
    ADD_C_OFF=$'\e[0m'
    ADD_C_LABEL=$'\e[38;5;244m'
    ADD_C_VALUE=$'\e[38;5;252m'
    ADD_C_FRAME=$'\e[38;5;238m'
    ADD_C_FOCUS=$'\e[1;38;5;117m'
    ADD_C_ERR=$'\e[1;38;5;203m'
    ADD_C_OK=$'\e[38;5;114m'
    ADD_C_HINT=$'\e[38;5;240m'
  fi
}

# prints $1 padded with spaces to $2 characters, cut short with an ellipsis when
# it does not fit, so a long value can never push the frame out of shape
add_pad() {
  local s="$1" n="$2" out
  if [ "${#s}" -gt "$n" ]; then
    printf '%s…' "${s:0:n-1}"
    return
  fi
  printf -v out '%*s' "$((n - ${#s}))" ''
  printf '%s%s' "$s" "$out"
}

# prints $2 copies of the character $1
add_repeat() {
  local out
  printf -v out '%*s' "$2" ''
  printf '%s' "${out// /$1}"
}

# draws the whole form and parks the caret inside the field being edited.
# the frame is inner = width - 4 characters wide, so every line ends on the
# same column no matter how long the values are.
add_form_draw() {
  local size cols inner label_w box_w value msg i key val shown problems status
  local text_color box_color label_color top title head_txt tail_txt caret_char content

  size=$(stty size 2>/dev/null)
  cols=${size##* }
  case "$cols" in
  '' | *[!0-9]*) cols=80 ;;
  esac
  inner=$((cols - 4))
  label_w=9
  box_w=$((inner - 16))
  [ "$box_w" -lt 10 ] && box_w=10
  ADD_BOX_W=$box_w

  problems=$(add_problems "${ADD_VALUES[@]}")

  printf '\e[H\e[K\r\n'

  # the title is dimmed like the rest of the frame instead of falling back to
  # the terminal's own foreground, which made the first row stand out
  title="sshmgr · new host"
  printf '  %s╭─%s %s%s%s %s%s╮\e[K\r\n' \
    "$ADD_C_FRAME" "$ADD_C_OFF" \
    "$ADD_C_LABEL" "$title" "$ADD_C_OFF" \
    "$ADD_C_FRAME" "$(add_repeat ─ $((cols - 4 - ${#title} - 3)))"

  printf '  %s│%s%s│%s\e[K\r\n' "$ADD_C_FRAME" "$ADD_C_OFF" \
    "$(add_pad "" "$inner")" "$ADD_C_OFF"

  for i in "${!ADD_KEYS[@]}"; do
    key="${ADD_KEYS[$i]}"
    val="${ADD_VALUES[$i]}"
    msg=$(jq -r --arg k "$key" '.[$k] // ""' <<<"$problems")

    # an empty field shows what it wants, a broken one shows why it is broken
    shown="$val"
    text_color="$ADD_C_VALUE"
    box_color="$ADD_C_FRAME"
    label_color="$ADD_C_LABEL"
    if [ "$i" -eq "$ADD_FOCUS" ]; then
      box_color="$ADD_C_FOCUS"
      label_color="$ADD_C_FOCUS"
    fi
    if [ -n "$msg" ]; then
      text_color="$ADD_C_ERR"
      shown="${shown:+$shown }$msg"
    elif [ -z "$val" ]; then
      text_color="$ADD_C_HINT"
      shown="optional"
    fi

    # the caret is drawn as a block on the character it sits on rather than by
    # parking the terminal cursor inside the box. moving the real cursor on
    # every keystroke is what terminals with a cursor trail (kitty) paint, and
    # it also fights the terminal's own blinking cursor.
    # only the field being edited gets one, the rest are plain text.
    caret_style=""
    head_txt="$shown"
    caret_char=""
    tail_txt=""
    if [ "$i" -eq "$ADD_FOCUS" ]; then
      caret_style="$ADD_C_CARET"
      head_txt=${shown:0:ADD_CARET}
      if [ "$ADD_CARET" -lt "${#shown}" ]; then
        caret_char=${shown:ADD_CARET:1}
        tail_txt=${shown:ADD_CARET+1}
      else
        caret_char=" "
      fi
    fi
    content=$(( ${#head_txt} + ${#caret_char} + ${#tail_txt} ))

    printf '  %s│%s %s%s%s %s[ %s' \
      "$ADD_C_FRAME" "$ADD_C_OFF" \
      "$label_color" "$(add_pad "$key" "$label_w")" "$ADD_C_OFF" \
      "$box_color" "$text_color"
    printf '%s' "$head_txt"
    printf '%s%s%s' "$caret_style" "$caret_char" "$ADD_C_OFF"
    printf '%s%s%s' "$text_color" "$tail_txt" "$ADD_C_OFF"
    printf '%s %s%s]' "$(add_pad "" $((box_w - content)))" "$box_color" "$ADD_C_OFF"
    printf ' %s│%s\e[K\r\n' "$ADD_C_FRAME" "$ADD_C_OFF"
  done

  printf '  %s│%s%s│%s\e[K\r\n' "$ADD_C_FRAME" "$ADD_C_OFF" \
    "$(add_pad "" "$inner")" "$ADD_C_OFF"
  printf '  %s├─%s╮\e[K\r\n' "$ADD_C_FRAME" "$(add_repeat ─ $((inner - 1)))"

  status=$(jq -r 'to_entries | map(.value) | first // ""' <<<"$problems")
  if [ -n "$status" ]; then
    printf '  %s│%s %s%s%s %s│%s\e[K\r\n' \
      "$ADD_C_FRAME" "$ADD_C_OFF" "$ADD_C_ERR" \
      "$(add_pad "! $status" $((inner - 2)))" "$ADD_C_OFF" \
      "$ADD_C_FRAME" "$ADD_C_OFF"
  else
    printf '  %s│%s %s%s%s %s│%s\e[K\r\n' \
      "$ADD_C_FRAME" "$ADD_C_OFF" "$ADD_C_OK" \
      "$(add_pad "✓ complete, ^S writes the entry" $((inner - 2)))" "$ADD_C_OFF" \
      "$ADD_C_FRAME" "$ADD_C_OFF"
  fi
  printf '  %s╰─%s╯\e[K\r\n' "$ADD_C_FRAME" "$(add_repeat ─ $((inner - 1)))"

  # the key bindings live outside the box, they are not part of the entry
  printf '\e[K\r\n  %s%s%s\e[K\r\n' "$ADD_C_HINT" \
    "⇥/⇧⇥ field   ← → move   ⌫ delete   ^U clear   ^S save   esc cancel" \
    "$ADD_C_OFF"

}

# reads keys until the entry is saved or the form is cancelled.
# returns 0 when it was written, 1 when it was not.
add_form() {
  local key seq ch i status prev_focus
  ADD_VALUES=("" "" "" "" "")
  ADD_FOCUS=0
  ADD_CARET=0
  ADD_SAVED=1
  prev_focus=0
  add_colors

  stty raw -echo 2>/dev/null
  # whatever happens, leave the terminal the way we found it
  trap 'stty sane 2>/dev/null; printf "\e[?25h"' EXIT
  # a signal means the user is done here; ^C is also read as a plain byte
  trap 'ADD_SAVED=0' INT TERM
  printf '\e[?25l\e[2J\e[H'

  while :; do
    add_form_draw
    IFS= read -rsn1 key || break

    if [ "$key" = $'\e' ]; then
      # an escape sequence arrives as several bytes; a lone escape means cancel
      seq=""
      while IFS= read -rsn1 -t 0.02 ch; do
        seq+="$ch"
      done
      case "$seq" in
      '[C' | 'OC') ADD_CARET=$((ADD_CARET + 1)) ;;
      '[D' | 'OD') ADD_CARET=$((ADD_CARET - 1)) ;;
      '[H' | 'OH' | '[1~' | '7~') ADD_CARET=0 ;;
      '[F' | 'OF' | '[4~' | '8~') ADD_CARET=${#ADD_VALUES[$ADD_FOCUS]} ;;
      '[A' | 'OA') ADD_FOCUS=$((ADD_FOCUS - 1)) ;;
      '[B' | 'OB') ADD_FOCUS=$((ADD_FOCUS + 1)) ;;
      '[Z') ADD_FOCUS=$((ADD_FOCUS - 1)) ;;
      '') ADD_SAVED=0; break ;;
      *) ;;
      esac
    else
      case "$key" in
      $'\t' | $'\r' | $'\n') ADD_FOCUS=$((ADD_FOCUS + 1)) ;;
      $'\x7f' | $'\b')
        [ "$ADD_CARET" -gt 0 ] && ADD_VALUES[$ADD_FOCUS]=${ADD_VALUES[$ADD_FOCUS]:0:ADD_CARET-1}${ADD_VALUES[$ADD_FOCUS]:ADD_CARET}
        ;;
      $'\x1b[3~')
        local v=${ADD_VALUES[$ADD_FOCUS]}
        ADD_VALUES[$ADD_FOCUS]=${v:0:ADD_CARET}${v:ADD_CARET+1}
        ;;
      $'\x01') ADD_CARET=0 ;;
      $'\x05') ADD_CARET=${#ADD_VALUES[$ADD_FOCUS]} ;;
      $'\x15') ADD_VALUES[$ADD_FOCUS]='' ;;
      $'\x03') ADD_SAVED=0; break ;;
      $'\x13' | $'\x04') break ;;
      *)
        # everything printable goes into the box, which also rebuilds
        # multibyte characters from their bytes one at a time
        if [ "$(printf '%d' "'$key")" -ge 32 ]; then
          local v=${ADD_VALUES[$ADD_FOCUS]}
          ADD_VALUES[$ADD_FOCUS]=${v:0:ADD_CARET}${key}${v:ADD_CARET}
          ADD_CARET=$((ADD_CARET + 1))
        fi
        ;;
      esac
    fi

    # moving to another field puts the caret behind whatever it holds
    if [ "$ADD_FOCUS" -ne "$prev_focus" ]; then
      ADD_CARET=${#ADD_VALUES[$ADD_FOCUS]}
    fi
    prev_focus="$ADD_FOCUS"

    # keep the caret inside its box
    [ "$ADD_CARET" -lt 0 ] && ADD_CARET=0
    [ "$ADD_CARET" -ge $((ADD_BOX_W - 2)) ] && ADD_CARET=$((ADD_BOX_W - 2))
    local vlen=${#ADD_VALUES[$ADD_FOCUS]}
    [ "$ADD_CARET" -gt "$vlen" ] && ADD_CARET=$vlen
    # and never walk off the list of fields
    [ "$ADD_FOCUS" -lt 0 ] && ADD_FOCUS=0
    [ "$ADD_FOCUS" -ge ${#ADD_KEYS[@]} ] && ADD_FOCUS=$((${#ADD_KEYS[@]} - 1))
  done

  trap - EXIT INT TERM
  stty sane 2>/dev/null
  printf '\e[?25h\e[%d;1H\r\n' "$LINES"

  if [ "$ADD_SAVED" = "0" ]; then
    echo "cancelled, nothing was written"
    return 0
  fi

  status=$(add_problems "${ADD_VALUES[@]}" | jq -r 'length')
  if [ "$status" != "0" ]; then
    add_problems "${ADD_VALUES[@]}" | jq -r 'to_entries[] | "error: " + .key + ": " + .value'
    return 1
  fi
  add_write "${ADD_VALUES[@]}"
}

# ---------------------------------------------------------------------------
# removing hosts
#
# "sshmgr -r <name>..." removes the given hosts right away, plain "sshmgr -r"
# lets fzf pick them.
# ---------------------------------------------------------------------------

# removes every host named in $1, one name per line
remove_hosts() {
  local wanted="$1" tmp missing count
  [ -z "$wanted" ] && return 0

  # refuse to do nothing quietly, a typo should be reported
  missing=$(jq -r --arg names "$wanted" '
    ($names | split("\n") | map(select(length > 0))) as $want
    | (.hosts | map(.name)) as $have
    | [$want[] | select(. as $n | ($have | index($n)) == null)] | join(", ")' "$HOSTS_FILE")

  if [ -n "$missing" ]; then
    echo "error: no such host: $missing"
    return 1
  fi

  tmp="${HOSTS_FILE}.tmp.$$"
  if jq --arg names "$wanted" '
        ($names | split("\n") | map(select(length > 0))) as $want
        | .hosts |= map(select(.name as $n | ($want | index($n)) == null))
      ' "$HOSTS_FILE" >"$tmp"; then
    mv "$tmp" "$HOSTS_FILE"
    count=$(jq --arg names "$wanted" '
      ($names | split("\n") | map(select(length > 0)) | unique) | length' "$HOSTS_FILE")
    echo "removed $count host(s) from $HOSTS_FILE"
  else
    rm -f "$tmp"
    echo "error: could not write $HOSTS_FILE"
    return 1
  fi
}

# picks the hosts to remove in fzf, with the same preview the menu uses
remove_pick() {
  local picked
  picked=$(jq -r '.hosts[].name' "$HOSTS_FILE" |
    fzf --multi --no-sort \
      --border=rounded \
      --border-label=" sshmgr · remove hosts · ⇥ select · ⏎ remove · esc cancel " \
      --prompt="remove › " \
      --bind='tab:toggle+up' \
      --preview="\"$0\" __info {}" \
      --preview-window='right:32' ) || return 0

  remove_hosts "$picked"
}

# asks for every field on stdin, used when there is no terminal to draw on
add_prompt() {
  local name="${1:-}" host="${2:-}" user="${3:-}" port="${4:-}" jumphost="${5:-}"

  read -r -p "name: ${name}" name
  read -r -p "host: ${host}" host
  read -r -p "user (optional): ${user}" user
  read -r -p "port (optional, defaults to 22): ${port}" port
  read -r -p "jumphost (optional): ${jumphost}" jumphost

  if [ "$(add_problems "$name" "$host" "$user" "$port" "$jumphost" | jq -r 'length')" != "0" ]; then
    add_problems "$name" "$host" "$user" "$port" "$jumphost" |
      jq -r 'to_entries[] | "error: " + .key + ": " + .value'
    return 1
  fi

  add_write "$name" "$host" "$user" "$port" "$jumphost"
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
-a | --add)
  # with arguments the entry is written straight away, without any prompt.
  # without them the form is opened when there is a terminal to draw it on,
  # and plain readline questions otherwise.
  if [ -n "${2:-}" ]; then
    if [ "$(add_problems "${2:-}" "${3:-}" "${4:-}" "${5:-}" "${6:-}" | jq -r 'length')" != "0" ]; then
      add_problems "${2:-}" "${3:-}" "${4:-}" "${5:-}" "${6:-}" |
        jq -r 'to_entries[] | "error: " + .key + ": " + .value'
      exit 1
    fi

    if ! add_write "${2:-}" "${3:-}" "${4:-}" "${5:-}" "${6:-}"; then
      echo "error: could not write $HOSTS_FILE"
      exit 1
    fi
    echo "added '${2}' to $HOSTS_FILE"
  elif [ -t 1 ]; then
    add_form
  else
    add_prompt
  fi
  ;;
-r | --remove)
  # with names as arguments they are removed right away, without a prompt.
  # without them the hosts are picked in fzf.
  if [ -n "${2:-}" ]; then
    shift
    remove_hosts "$(printf '%s\n' "$@")"
  else
    remove_pick
  fi
  ;;
-h | --help)
  # printing help/usage information
  echo -e "Usage:\n \nsshmgr | opens host selection. exit py pressing CTRL+Q\n \nsshmgr -e / sshmgr --edit | opens the known hosts file with standart editor for you to edit it\n \nsshmgr -a / sshmgr --add | adds a host in a small form, or from arguments: sshmgr -a <name> <host> [user] [port] [jumphost]\n \nsshmgr -r / sshmgr --remove | removes hosts picked in fzf, or from arguments: sshmgr -r <name>...\n \nsshmgr -p / sshmgr --ping | pings all known hosts in parallel\n \nsshmgr -h / sshmgr --help | shows this text for help"
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

  # defaults for optional fields (// empty above already maps missing/null -> "")
  [[ -z "$port" ]] && port="22"

  if ! [[ "$port" =~ ^[0-9]+$ ]] || ((10#$port < 1 || 10#$port > 65535)); then
    echo "error: invalid port '$port' for '$selected'"
    exit 1
  fi

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
  # the ssh kitten is a drop-in replacement for ssh, but it only works inside kitty
  ssh_cmd=(ssh)
  if [ "$kitten_ssh" = "true" ]; then
    if [ -n "$KITTY_WINDOW_ID" ] && command -v kitten >/dev/null 2>&1; then
      ssh_cmd=(kitten ssh)
    else
      echo "note: kitten_ssh is enabled, but kitten is unavailable here. falling back to ssh"
    fi
  fi

  ssh_args=(-p "$port")
  if [ -n "$jumphost" ]; then
    ssh_args+=(-J "$jumphost")
    echo "Connecting to $selected ($dest) using $jumphost as jumphost"
  else
    echo "Connecting to $selected ($dest)..."
  fi

  "${ssh_cmd[@]}" "${ssh_args[@]}" "$dest"
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
