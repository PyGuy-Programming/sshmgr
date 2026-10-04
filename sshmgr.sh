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

# the colours the form needs. every field gets one colour of the rainbow, in
# the order of the flag, and the title rule is striped to match. the colours
# belong to the fields instead of cycling, so nothing flickers while typing.
add_colors() {
  # reverse video is what makes the caret readable; it survives NO_COLOR
  ADD_C_CARET=$'\e[1;7m'
  ADD_C_PRIDE=()
  ADD_C_PRIDE_BOLD=()

  if [ -n "${NO_COLOR:-}" ]; then
    ADD_C_OFF= ADD_C_LABEL= ADD_C_VALUE= ADD_C_FRAME=
    ADD_C_FOCUS= ADD_C_ERR= ADD_C_OK= ADD_C_HINT=
    return
  fi

  ADD_C_OFF=$'\e[0m'
  ADD_C_LABEL=$'\e[38;5;244m'
  ADD_C_VALUE=$'\e[38;5;252m'
  ADD_C_FRAME=$'\e[38;5;238m'
  ADD_C_FOCUS=$'\e[1;38;5;117m'
  ADD_C_ERR=$'\e[1;38;5;203m'
  ADD_C_OK=$'\e[38;5;114m'
  ADD_C_HINT=$'\e[38;5;240m'
  # does this terminal do 24 bit colour? without it the fade bands badly
  ADD_C_TRUE=0
  case "${COLORTERM:-}" in
  truecolor | 24bit) ADD_C_TRUE=1 ;;
  esac

  # the flag is at full strength in june and fades out day by day afterwards
  ADD_PRIDE_LEVEL=$(add_pride_level)
  if [ "$ADD_PRIDE_LEVEL" -gt 0 ]; then
    ADD_C_PRIDE=()
    ADD_C_PRIDE_BOLD=()
    for i in 1 2 3 4 5 6; do
      ADD_C_PRIDE+=("$(printf '\e[38;%sm' "$(add_pride_rgb "$i" "$ADD_PRIDE_LEVEL")")")
      ADD_C_PRIDE_BOLD+=("$(printf '\e[1;38;%sm' "$(add_pride_rgb "$i" "$ADD_PRIDE_LEVEL")")")
    done
  fi
}

# how much rainbow is showing, in per mille: the pride version of the theme is
# june, and it goes away again a little every day through july rather than all
# at once, the way a pride logo does. the plain grey theme is what is left when
# it is gone. only needs date(1), no epoch arithmetic.
ADD_PRIDE_FADE_DAYS=30
add_pride_level() {
  local md m d
  md=$(date '+%m %d') || return 0
  m=${md% *}
  d=${md#* }
  case "$m" in
  06) printf 1000 ;;
  07) printf '%s' $((1000 * (ADD_PRIDE_FADE_DAYS - 10#$d) / ADD_PRIDE_FADE_DAYS)) ;;
  *) printf 0 ;;
  esac
}

# the six colours of the flag, and the neutral they fade towards
ADD_PRIDE_RGB=(237 80 80 245 150 60 245 215 90 95 205 120 95 150 245 185 120 230)
ADD_PRIDE_FADE=(168 172 182)

# the cube levels of the xterm-256 palette
ADD_CUBE=(0 95 135 175 215 255)

# prints the position in ADD_CUBE of whichever level is closest to $1, in
# ADD_NEAREST. a function rather than a substitution to keep the forks out of
# the redraw.
add_nearest() {
  local v="$1" i d best=999999
  for i in 0 1 2 3 4 5; do
    d=$(((ADD_CUBE[i] - v) * (ADD_CUBE[i] - v)))
    if [ "$d" -lt "$best" ]; then
      best=$d
      ADD_NEAREST=$i
    fi
  done
}

# prints the xterm-256 colour closest to the given rgb. both the colour cube
# and the grey ramp are tried, because a colour that has mostly faded out is
# usually nearer to a grey than to any cube entry.
add_rgb256() {
  local r="$1" g="$2" b="$3" ri gi bi idx d bestg=999999 gv gk dcube
  add_nearest "$r"
  ri=$ADD_NEAREST
  add_nearest "$g"
  gi=$ADD_NEAREST
  add_nearest "$b"
  bi=$ADD_NEAREST
  idx=$((16 + 36 * ri + 6 * gi + bi))

  dcube=$(((ADD_CUBE[ri] - r) * (ADD_CUBE[ri] - r)
    + (ADD_CUBE[gi] - g) * (ADD_CUBE[gi] - g)
    + (ADD_CUBE[bi] - b) * (ADD_CUBE[bi] - b)))

  # the error has to be measured the same way for both candidates, so the grey
  # is compared against all three channels too, not just their average
  for gk in 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19; do
    local gv0=$((8 + gk * 10))
    d=$(((gv0 - r) * (gv0 - r) + (gv0 - g) * (gv0 - g) + (gv0 - b) * (gv0 - b)))
    if [ "$d" -lt "$bestg" ]; then
      bestg=$d
      gv=$((232 + gk))
    fi
  done

  if [ "$bestg" -lt "$dcube" ]; then printf '%s' "$gv"; else printf '%s' "$idx"; fi
}

# the $1th colour of the flag at $2 per mille of its strength, as an sgr colour
# fragment. a 256 colour palette only has six steps per channel, which makes a
# fade visibly banded, so terminals that advertise truecolor get exact values.
add_pride_rgb() {
  local i=$((($1 - 1) * 3)) level="$2" r g b
  r=$(((ADD_PRIDE_RGB[i] * level + ADD_PRIDE_FADE[0] * (1000 - level)) / 1000))
  g=$(((ADD_PRIDE_RGB[i + 1] * level + ADD_PRIDE_FADE[1] * (1000 - level)) / 1000))
  b=$(((ADD_PRIDE_RGB[i + 2] * level + ADD_PRIDE_FADE[2] * (1000 - level)) / 1000))
  if [ "$ADD_C_TRUE" = "1" ]; then
    printf '2;%d;%d;%d' "$r" "$g" "$b"
  else
    printf '5;%s' "$(add_rgb256 "$r" "$g" "$b")"
  fi
}

# one "label   value" line for the preview, the label in a colour of the flag
add_info_line() {
  printf '%s%-10s%s %s%s%s\n' "$(add_hue "$3")" "$1" "$ADD_C_OFF" \
    "$ADD_C_VALUE" "$2" "$ADD_C_OFF"
}

# prints the $1th colour of the flag, or nothing when colour is off
add_hue() {
  local hues=${#ADD_C_PRIDE[@]}
  [ "$hues" -gt 0 ] && printf '%s' "${ADD_C_PRIDE[$(( $1 % hues ))]}"
  return 0
}

# prints $1 copies of the character $2, but as a striped rainbow rule
add_rule() {
  local width="$1" segs="${#ADD_C_PRIDE[@]}" i part used=0 out=""
  if [ "$segs" -eq 0 ]; then
    add_repeat "$2" "$width"
    return
  fi
  for ((i = 0; i < segs; i++)); do
    # the last stripe takes whatever is left, so the rule keeps its width
    if [ "$i" -eq $((segs - 1)) ]; then
      part=$((width - used))
    else
      part=$((width / segs))
    fi
    used=$((used + part))
    out+="${ADD_C_PRIDE_BOLD[i]}$(add_repeat "$2" "$part")$ADD_C_OFF"
  done
  printf '%s' "$out"
}

# paints every line of stdin with the next colour of the flag, so the fzf menus
# come out in the same colours as the form. a no-op when colour is off.
add_rainbow() {
  local i=0 hue
  while IFS= read -r line || [ -n "$line" ]; do
    hue=${#ADD_C_PRIDE[@]}
    if [ "$hue" -eq 0 ]; then
      printf '%s\n' "$line"
    else
      printf '%s%s%s\n' "${ADD_C_PRIDE[i % hue]}" "$line" "$ADD_C_OFF"
    fi
    i=$((i + 1))
  done
}

# strips the colour back out of a line, needed wherever fzf hands a painted
# item back to us for a lookup
add_uncolour() {
  sed $'s/\033\\[[0-9;]*m//g'
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
  local text_color box_color label_color title head_txt tail_txt caret_char
  local content hues line start room pre post

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
  hues=${#ADD_C_PRIDE[@]}

  problems=$(add_problems "${ADD_VALUES[@]}")

  # the frame lines each take one colour of the flag, so the edges run through
  # it from top to bottom, and every field row wears the colour of its own field
  printf '\e[H\e[K\r\n'
  title="sshmgr · new host"
  printf '  %s╭─%s %s%s%s %s%s╮\e[K\r\n' \
    "$(add_hue 0)" "$ADD_C_OFF" \
    "$ADD_C_LABEL" "$title" "$ADD_C_OFF" \
    "$(add_rule $((cols - 4 - ${#title} - 3)) ─)"

  printf '  %s│%s%s│%s\e[K\r\n' "$(add_hue 0)" "$ADD_C_OFF" \
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
    if [ "$hues" -gt 0 ]; then
      label_color="$(add_hue "$i")"
      box_color="$label_color"
      # the field being edited is the bold one, so the focus stays obvious
      if [ "$i" -eq "$ADD_FOCUS" ]; then
        label_color="${ADD_C_PRIDE_BOLD[i % hues]}"
        box_color="$label_color"
      fi
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
    pre=""
    post=""
    head_txt="$shown"
    caret_char=""
    tail_txt=""

    if [ "$i" -eq "$ADD_FOCUS" ]; then
      caret_style="$ADD_C_CARET"
      # split around the caret, with the block sitting on the character there
      head_txt=${shown:0:ADD_CARET}
      tail_txt=""
      if [ "$ADD_CARET" -lt "${#shown}" ]; then
        caret_char=${shown:ADD_CARET:1}
        tail_txt=${shown:ADD_CARET+1}
      else
        caret_char=" "
      fi

      # whatever does not fit is trimmed, tail first and then the head, so the
      # caret itself is never the thing that gets cut
      budget=$((box_w - 1))
      if [ "${#tail_txt}" -gt "$budget" ]; then
        tail_txt="${tail_txt:0:budget-1}"
        post="…"
        budget=$((budget - 1))
      fi
      if [ "${#head_txt}" -gt "$budget" ]; then
        head_txt="${head_txt:0:budget-1}"
        pre="…"
      fi
    elif [ "${#shown}" -gt "$box_w" ]; then
      head_txt="${shown:0:$((box_w - 1))}"
      post="…"
    fi
    content=$(( ${#pre} + ${#head_txt} + ${#caret_char} + ${#tail_txt} + ${#post} ))

    printf '  %s│%s %s%s%s %s[ %s%s' \
      "$box_color" "$ADD_C_OFF" \
      "$label_color" "$(add_pad "$key" "$label_w")" "$ADD_C_OFF" \
      "$box_color" "$text_color" "$pre"
    printf '%s' "$head_txt"
    printf '%s%s%s' "$caret_style" "$caret_char" "$ADD_C_OFF"
    printf '%s%s%s%s' "$text_color" "$tail_txt" "$post" "$ADD_C_OFF"
    printf ' %s%s]' "$(add_pad "" $((box_w - content)))" "$box_color"
    printf ' %s│%s\e[K\r\n' "$box_color" "$ADD_C_OFF"
  done

  # below the fields the frame carries on with the colours the flag has left
  printf '  %s│%s%s│%s\e[K\r\n' "$(add_hue 4)" "$ADD_C_OFF" \
    "$(add_pad "" "$inner")" "$ADD_C_OFF"
  printf '  %s├─%s╮\e[K\r\n' "$(add_hue 5)" "$(add_repeat ─ $((inner - 1)))"

  status=$(jq -r 'to_entries | map(.value) | first // ""' <<<"$problems")
  if [ -n "$status" ]; then
    printf '  %s│%s %s%s%s %s│%s\e[K\r\n' \
      "$(add_hue 5)" "$ADD_C_OFF" "$ADD_C_ERR" \
      "$(add_pad "! $status" $((inner - 2)))" "$ADD_C_OFF" \
      "$(add_hue 5)" "$ADD_C_OFF"
  else
    printf '  %s│%s %s%s%s %s│%s\e[K\r\n' \
      "$(add_hue 5)" "$ADD_C_OFF" "$ADD_C_OK" \
      "$(add_pad "✓ complete, ^S writes the entry" $((inner - 2)))" "$ADD_C_OFF" \
      "$(add_hue 5)" "$ADD_C_OFF"
  fi
  printf '  %s╰─%s╯\e[K\r\n' "$(add_hue 5)" "$(add_repeat ─ $((inner - 1)))"

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
  add_colors
  picked=$(jq -r '.hosts[].name' "$HOSTS_FILE" |
    add_rainbow |
    fzf --ansi --multi --no-sort \
      --border=rounded \
      --border-label=" ${ADD_C_PRIDE_BOLD[0]}sshmgr${ADD_C_OFF} ${ADD_C_LABEL}· remove hosts${ADD_C_OFF} ${ADD_C_LABEL}· ⇥ select · ⏎ remove · esc cancel${ADD_C_OFF} " \
      --prompt="${ADD_C_PRIDE_BOLD[1]}remove${ADD_C_OFF} ${ADD_C_PRIDE_BOLD[2]}>${ADD_C_OFF} " \
      --color="hl:33" \
      --bind='tab:toggle+up' \
      --preview="\"$0\" __info {}" \
      --preview-window='right:32' ) || return 0

  remove_hosts "$(printf '%s' "$picked" | add_uncolour)"
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
  cat <<'USAGE'
sshmgr - connect to your hosts without typing ssh commands

usage:
  sshmgr                            open the host menu, enter connects
  sshmgr -e                         edit the hosts file in $EDITOR
  sshmgr -a                         add a host in a form
  sshmgr -a NAME HOST [USER] [PORT] [JUMPHOST]
                                    add a host without being asked anything
  sshmgr -r                         pick hosts to remove in fzf
  sshmgr -r NAME...                 remove the given hosts
  sshmgr -p                         ping all hosts in parallel
  sshmgr -h                         this text

keys in the add form:
  tab / enter      next field            left / right   move the caret
  shift-tab / up   previous field        backspace      delete a character
  ctrl-u           clear the field       ctrl-s         write the entry
  esc / ctrl-c     quit

keys in the remove list:
  tab              select and move on    enter          remove what is selected
  esc              quit

files:
  ~/.config/sshmgr/known_hosts.json   hosts and settings
  set "kitten_ssh": true there to connect with kitty's ssh kitten

examples:
  sshmgr -a web-server example.com deploy 2222
  sshmgr -a internal-db 10.0.0.50 admin 22 bastion.example.com
  sshmgr -r old-server test-box

run 'man sshmgr' for the full manual.
USAGE
  ;;
"")
  # starting selection of known hosts if no option is given
  # the fzf preview calls this script itself with __info (see case below)
  echo "opening known host selection..."
  add_colors
  selected=$(jq -r '.hosts[] | "\(.name)"' "$HOSTS_FILE" |
    add_rainbow |
    fzf --ansi --no-sort \
      --border=rounded \
      --border-label=" ${ADD_C_PRIDE_BOLD[0]}sshmgr${ADD_C_OFF} ${ADD_C_LABEL}· pick a host${ADD_C_OFF} " \
      --prompt="${ADD_C_PRIDE_BOLD[1]}SSH${ADD_C_OFF} ${ADD_C_PRIDE_BOLD[2]}>${ADD_C_OFF} " \
      --color="hl:33" \
      --preview="\"$0\" __info {}")

  # fzf hands the colour back with the name, and the lookup needs it plain
  selected=$(printf '%s' "$selected" | add_uncolour)

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
  # internal: called by the fzf preview, shows status + details.
  # fzf passes the item as painted, so the name arrives with colour on it
  name=$(printf '%s' "$2" | add_uncolour)
  add_colors
  info_host=$(jq -r --arg name "$name" '.hosts[] | select(.name == $name) | .host' "$HOSTS_FILE")

  # the status is coloured by what it means, the details by the flag
  if command -v fping >/dev/null 2>&1; then
    if timeout 2 fping -c1 "$info_host" >/dev/null 2>&1; then
      printf '%s● online%s\n' "$ADD_C_OK" "$ADD_C_OFF"
    else
      printf '%s○ offline%s\n' "$ADD_C_ERR" "$ADD_C_OFF"
    fi
    echo
  fi

  info=$(jq -r --arg name "$name" '.hosts[] | select(.name == $name) |
    [ (.user // ""), .host, (.port // "?"),
      (.jumphost | if . == null or . == "" then "-" else . end) ] | @tsv' "$HOSTS_FILE")

  if [ -z "$info" ]; then
    printf '%s(host not found)%s\n' "$ADD_C_ERR" "$ADD_C_OFF"
  else
    IFS=$'\t' read -r i_user i_host i_port i_jump <<<"$info"
    add_info_line "User:" "${i_user:--}" 0
    add_info_line "Host:" "${i_host:--}" 1
    add_info_line "Port:" "$i_port" 2
    add_info_line "Jumphost:" "$i_jump" 3
  fi
  ;;
*)
  # printing help if given unknown option
  echo -e "unknown option: $1\nrun sshmgr -h for available options"
  ;;
esac
