[![Title](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&weight=600&size=50&duration=2000&pause=1000&color=7DE687&center=true&repeat=false&width=435&height=70&lines=sshmgr)](https://git.io/typing-svg)
[![Description](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&duration=3000&color=80B1CD&center=true&multiline=true&repeat=false&width=540&height=100&lines=A+simple+tool+writen+in+bash+to+make++;connecting+to+servers+much+easier+and+faster;(actively+working+on+it+btw))](https://git.io/typing-svg)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version: 2.4.1](https://img.shields.io/badge/version-2.4.1-blue.svg)](https://github.com/pyguy-programming/sshmgr)

A simple tool written in bash to make connecting to servers much easier and faster.

Repo: https://github.com/pyguy-programming/sshmgr

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Features

- **Fzf-based host selection**: interactive menu with fuzzy search and live preview (online status + connection details)
- **Jumphost support**: connect through bastion hosts via SSH `-J`, configured per host
- **Parallel ping**: check all hosts at once with fping (`sshmgr -p`)
- **JSON configuration**: easy-to-read host definitions in `~/.config/sshmgr/known_hosts.json`
- **Custom user/port per host**, with port validation (defaults to 22)
- **Add hosts in a built-in form**: `sshmgr -a` opens one text box per field, with live validation
- **Remove hosts**: `sshmgr -r` picks them in fzf (multi-select), or takes them as arguments
- **Optional kitty ssh kitten**: connect through `kitten ssh` for shell integration and connection reuse (toggleable)

## Installation

### Brew (recommended)

```bash
brew tap PyGuy-Programming/sshmgr
brew install sshmgr
```

This pulls in the dependencies (`fzf`, `jq`, `fping`) automatically and installs
the manual page, so `man sshmgr` works.

### Manual Installation

From the cloned repository, either run the installer:

```bash
./INSTALL
```

Or install step by step:

```bash
# 1. Install dependencies: fzf, jq, fping (and nano, or set $EDITOR)
#    macOS: brew install fzf jq fping
#    Debian/Ubuntu: sudo apt-get install fzf jq fping

# 2. Copy the script and install the manual page
mkdir -p "$HOME/.local/bin/sshmgr" "$HOME/.local/share/man/man1"
cp sshmgr.sh "$HOME/.local/bin/sshmgr/"
cp sshmgr.1 "$HOME/.local/share/man/man1/"
grep -q MANPATH ~/.bashrc || echo 'export MANPATH="$HOME/.local/share/man:${MANPATH:-}"' >> ~/.bashrc

# 3. Add alias and reload
echo 'alias sshmgr="bash $HOME/.local/bin/sshmgr/sshmgr.sh"' >> ~/.bashrc
source ~/.bashrc

# 4. Initialize the hosts file
sshmgr -e
```

Both paths end up with a working `man sshmgr`.

## Usage

| Command | Description |
|---------|-------------|
| `sshmgr` | Open the interactive fzf host selection menu |
| `sshmgr -e` / `--edit` | Open `known_hosts.json` in `$EDITOR` |
| `sshmgr -a` / `--add` | Add a host in the built-in form, or from arguments |
| `sshmgr -r` / `--remove` | Remove hosts, picked in fzf or given as arguments |
| `sshmgr -p` / `--ping` | Ping all known hosts in parallel (fping) |
| `sshmgr -h` / `--help` | Show help |

Everything is also written up in the manual: `man sshmgr`.

### Adding hosts

With arguments, the entry is written straight away and nothing is asked:

```bash
sshmgr -a web-server example.com                       # user, port, jumphost stay empty
sshmgr -a web-server example.com deploy 2222
sshmgr -a internal-db 10.0.0.50 admin 22 bastion.example.com
```

Without arguments, sshmgr opens a form. It is drawn by the script itself, one
text box per field, and the box you are in gets the caret. Anything that would
keep the entry from being written is shown on the spot:

```
  ╭─ sshmgr · new host ──────────────────────────────────────╮
  │                                                          │
  │ name      [ web-server                                   ] │
  │ host      [ a host address is required                   ] │
  │ user      [ optional                                     ] │
  │ port      [ optional                                     ] │
  │ jumphost  [ optional                                     ] │
  │                                                          │
  ├──────────────────────────────────────────────────────────╮
  │ ! a host address is required                             │
  ╰──────────────────────────────────────────────────────────╯

  ⇥/⇧⇥ field   ← → move   ⌫ delete   ^U clear   ^S save   esc cancel
```

| Key | Effect |
|-----|--------|
| `⇥` / `⏎` | next field |
| `⇧⇥` / `↑` | previous field |
| `←` `→` | move the caret inside the field |
| `⌫` / `⌦` | delete a character |
| `^U` | clear the whole field |
| `^S` or `^D` | write the entry, once it is complete |
| `esc` or `^C` | quit without writing |

Blank fields are left out of the entry, so an empty port keeps the `22` default,
and names must be unique. The form needs a terminal; in a script (or with
`NO_COLOR` set) sshmgr falls back to asking for each field on stdin instead.

### Removing hosts

`sshmgr -r` opens the host list in fzf with the same preview as the connect
menu: `⇥` selects an entry and moves on, `⏎` removes everything selected, `esc`
cancels. Names can also be passed directly, which removes them without a prompt:

```bash
sshmgr -r old-server          # remove one
sshmgr -r old-server test-box # remove several
```

In the selection menu: type to filter, `↑/↓` to navigate, `Enter` to connect,
`CTRL+Q` to quit. The preview shows each host's online status (via fping, if
installed) and connection details. If the selected host has a `jumphost`
configured, sshmgr connects through it automatically
(`ssh -p <port> -J <jumphost> <user>@<host>`). Unknown options print an error
pointing to `sshmgr -h`.

## Configuration

Stored at `~/.config/sshmgr/known_hosts.json` (created automatically on first
run). The script validates it with `jq` on startup and exits with
`invalid json` if it is malformed or missing the `hosts` key.

```json
{
  "kitten_ssh": false,
  "hosts": [
    { "name": "web-server", "host": "example.com", "user": "deploy", "port": "2222" },
    { "name": "internal-db", "host": "10.0.0.50", "user": "admin", "jumphost": "bastion.example.com" }
  ]
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Display name in the menu; must be unique |
| `host` | Yes | Hostname or IP address |
| `user` | No | SSH user (defaults to current local user if omitted) |
| `port` | No | SSH port (defaults to `22`; must be 1–65535) |
| `jumphost` | No | Bastion host for `ssh -J`; omit if unused |

### kitty ssh kitten

Set the top-level `"kitten_ssh": true` to connect via kitty's ssh kitten
instead of plain `ssh`. It is a drop-in replacement for `ssh` that adds remote
shell integration, connection multiplexing (much faster reconnects) and makes
the kitty terminfo database available on the remote host.

Because the kitten only works from inside a kitty terminal, sshmgr falls back to
plain `ssh` with a note when `kitten` is missing or the script runs outside
kitty. `port`, `user` and `jumphost` are passed through unchanged.

#### If it prints "Connecting to ..." and then nothing happens

This is a hang inside kitty's ssh kitten, not in sshmgr, and it only happens
when the remote host asks for a **password**.

The kitten does not let `ssh` prompt in the terminal. Instead its askpass helper
asks kitty to draw the prompt as an overlay, by writing a `kitty-ask` escape
sequence to the tty, and then waits for kitty to write the answer back into a
shared memory segment. That wait is an endless poll with no timeout, so if kitty
never services the request, nothing is printed and nothing is read — the
connection just sits there until you interrupt it.

Use key-based authentication if you can: then no password is ever requested, the
overlay is never needed, and you keep the part of the kitten that actually pays
off (near-instant reconnects, remote shell integration, terminfo on the remote).

If you want to keep typing passwords, turn the overlay off and let `ssh` prompt
at the terminal as usual:

```bash
# ~/.config/kitty/ssh.conf
askpass ssh
```

Everything else about the kitten keeps working; the only cost is a slightly
slower first connect, because the kitten can no longer send its setup data
before `ssh` is done with the terminal. The same works for a single connection
with `kitten ssh --kitten askpass=ssh <host>`.

To confirm which path you are on, compare against plain `ssh`:

```bash
ssh -o BatchMode=yes <user>@<host>      # fails at once, no prompt needed
```

Tips: keep the JSON valid, use descriptive names, and test jumphosts manually
first (`ssh -J bastion user@target`). Entries from the old plain-text format
(`user@address - name` in `known_hosts.save`) can be migrated by converting
each line into a JSON entry as above.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `invalid json` on startup | Run `sshmgr -e` and fix the syntax (trailing commas, quotes, braces); validate with `jq . ~/.config/sshmgr/known_hosts.json` |
| Empty menu / host missing | Each host needs a unique `name` field; check the `hosts` array is not empty |
| Connection fails | Verify `host`/`user`/`port`; run `sshmgr -p`, then try manually: `ssh -p <port> <user>@<host>` (add `-J <jumphost>` if configured) |
| Ping shows offline but SSH works | ICMP is often blocked — ping is only an indicator, not a requirement |
| `command not found` | Check the alias in `.bashrc` (`source ~/.bashrc`) or reinstall via brew |
| `kitten ssh` errors out | Set `"kitten_ssh": false`, or run sshmgr from inside a kitty terminal |
| "Connecting to ..." then nothing | Password prompt hang in kitty's ssh kitten, see [If it prints "Connecting to ..."](#if-it-prints-connecting-to--and-then-nothing-happens) |
| `sshmgr -a` asks on stdin instead of drawing the form | There is no terminal to draw on, e.g. piped output or cron |

Diagnostics:

```bash
man sshmgr                            # what am I forgetting again?
sshmgr -h                              # script runs?
jq . ~/.config/sshmgr/known_hosts.json # valid JSON?
which fzf fping jq ssh                 # dependencies present?
sshmgr -p                              # hosts reachable?
```

Still stuck? Open an issue at https://github.com/pyguy-programming/sshmgr/issues
with a description, steps to reproduce, and the `jq` validation output.

## License

MIT — see [LICENSE.md](LICENSE.md) for the full license text.
