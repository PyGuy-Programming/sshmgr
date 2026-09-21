[![Title](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&weight=600&size=50&duration=2000&pause=1000&color=7DE687&center=true&repeat=false&width=435&height=70&lines=sshmgr)](https://git.io/typing-svg)
[![Description](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&duration=3000&color=80B1CD&center=true&multiline=true&repeat=false&width=540&height=100&lines=A+simple+tool+writen+in+bash+to+make++;connecting+to+servers+much+easier+and+faster;(actively+working+on+it+btw))](https://git.io/typing-svg)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-2.3.1-blue.svg)](https://github.com/pyguy-programming/sshmgr)

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

## Installation

### Brew (recommended)

```bash
brew tap PyGuy-Programming/sshmgr
brew install sshmgr
```

This pulls in the dependencies (`fzf`, `jq`, `fping`) automatically.

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

# 2. Copy the script
mkdir -p "$HOME/.local/bin/sshmgr"
cp sshmgr.sh "$HOME/.local/bin/sshmgr/"

# 3. Add alias and reload
echo 'alias sshmgr="bash $HOME/.local/bin/sshmgr/sshmgr.sh"' >> ~/.bashrc
source ~/.bashrc

# 4. Initialize the hosts file
sshmgr -e
```

## Usage

| Command | Description |
|---------|-------------|
| `sshmgr` | Open the interactive fzf host selection menu |
| `sshmgr -e` / `--edit` | Open `known_hosts.json` in `$EDITOR` |
| `sshmgr -p` / `--ping` | Ping all known hosts in parallel (fping) |
| `sshmgr -h` / `--help` | Show help |

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

Diagnostics:

```bash
sshmgr -h                              # script runs?
jq . ~/.config/sshmgr/known_hosts.json # valid JSON?
which fzf fping jq ssh                 # dependencies present?
sshmgr -p                              # hosts reachable?
```

Still stuck? Open an issue at https://github.com/pyguy-programming/sshmgr/issues
with a description, steps to reproduce, and the `jq` validation output.

## License

MIT — see [LICENSE.md](LICENSE.md) for the full license text.
