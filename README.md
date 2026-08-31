[![Title](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&weight=600&size=50&duration=2000&pause=1000&color=7DE687&center=true&repeat=false&width=435&height=70&lines=sshmgr)](https://git.io/typing-svg)
[![Description](https://readme-typing-svg.herokuapp.com?font=JetBrains+Mono&duration=3000&color=80B1CD&center=true&multiline=true&repeat=false&width=540&height=100&lines=A+simple+tool+writen+in+bash+to+make++;connecting+to+servers+much+easier+and+faster;(actively+working+on+it+btw))](https://git.io/typing-svg)

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/pyguy-programming/sshmgr)

A simple tool written in bash to make connecting to servers much easier and faster.

Repo: https://github.com/pyguy-programming/sshmgr

## Table of Contents

- [Features](#features)
- [Installation](#installation)
  - [Brew (recommended)](#brew-recommended)
  - [Manual Installation](#manual-installation)
- [Quick Start](#quick-start)
- [CLI Options](#cli-options)
  - [`-e` / `--edit`](#-e----edit)
  - [`-p` / `--ping`](#-p----ping)
  - [`-h` / `--help`](#-h----help)
  - [`-j` / `--jumphost`](#-j----jumphost)
  - [`-f` / `--fzf`](#-f----fzf)
  - [`-t` / `--test`](#-t----test)
  - [`-v` / `--version`](#-v----version)
  - [No Argument (Interactive Mode)](#no-argument-interactive-mode)
  - [Option Summary Table](#option-summary-table)
- [Usage Examples](#usage-examples)
  - [First Connection](#first-connection)
  - [Connecting Through a Jumphost](#connecting-through-a-jumphost)
  - [Custom Port](#custom-port)
  - [Parallel Ping](#parallel-ping)
  - [Edit Configuration](#edit-configuration)
- [Configuration File](#configuration-file)
  - [JSON Structure](#json-structure)
  - [Field Descriptions](#field-descriptions)
  - [Complete Example](#complete-example)
  - [Schema Validation](#schema-validation)
  - [Migration from Old Format](#migration-from-old-format)
  - [Best Practices](#best-practices)
- [User Guide](#user-guide)
  - [Adding Hosts](#adding-hosts)
  - [Connecting to Hosts](#connecting-to-hosts)
  - [Using Jumphosts (Bastion Hosts)](#using-jumphosts-bastion-hosts)
  - [Ping Functionality](#ping-functionality)
  - [Host Management Tips](#host-management-tips)
  - [Keyboard Shortcuts (fzf Menu)](#keyboard-shortcuts-fzf-menu)
- [Tutorials](#tutorials)
  - [Tutorial 1: First Connection](#tutorial-1-first-connection)
  - [Tutorial 2: Multi-Host Management](#tutorial-2-multi-host-management)
  - [Tutorial 3: Jumphost Configuration](#tutorial-3-jumphost-configuration)
- [Troubleshooting](#troubleshooting)
  - [Common Issues and Solutions](#common-issues-and-solutions)
  - [Quick Diagnostic Commands](#quick-diagnostic-commands)
  - [Getting Further Help](#getting-further-help)
- [Alias](#alias)
- [License](#license)

## Features

- **Fzf-based host selection**: Interactive menu for selecting SSH hosts with fuzzy search
- **Parallel ping**: Check host availability in parallel using fping
- **Jumphost support**: Connect through intermediate jump hosts using SSH `-J` flag
- **JSON configuration**: Host management via easy-to-read JSON in `knownhosts.json`
- **Edit with $EDITOR**: Open configuration file with your preferred editor (`sshmgr -e`)
- **Port customization**: Specify custom SSH ports per host
- **User configuration**: Define default usernames per host
- **Brew installation**: Install via `brew tap PyGuy-Programming/sshmgr && brew install sshmgr`
- **Manual installation**: Copy script to `$HOME/.local/bin/sshmgr/` and add alias to `.bashrc`

## Installation

### Brew (recommended)

```bash
brew tap PyGuy-Programming/sshmgr
brew install sshmgr
```

### Manual Installation

```bash
# 1. Ensure fzf, jq and nano are installed
# On macOS: brew install fzf jq nano
# On Debian/Ubuntu: sudo apt-get install fzf jq nano

# 2. Create installation directory
mkdir -p "$HOME/.local/bin/sshmgr"

# 3. Copy the script
cp sshmgr.sh "$HOME/.local/bin/sshmgr/"

# 4. Add alias to .bashrc
echo 'alias sshmgr="bash $HOME/.local/bin/sshmgr/sshmgr.sh"' >> ~/.bashrc

# 5. Reopen terminal or source .bashrc
source ~/.bashrc

# 6. Initialize the hosts file
sshmgr -e  # This will create ~/.config/sshmgr/known_hosts.json with default empty structure
```

## Quick Start

```bash
# Open host selection menu (no arguments)
sshmgr

# Edit the hosts configuration
sshmgr -e
sshmgr --edit

# Ping all known hosts
sshmgr -p
sshmgr --ping

# Show help
sshmgr -h
sshmgr --help
```

## CLI Options

`sshmgr` is a bash script for managing SSH connections to known hosts. It provides an
interactive fzf-based selection menu and supports various command-line options for
common operations.

### `-e` / `--edit`

**Description**: Open the known hosts configuration file in your default editor
(`$EDITOR`, typically nano).

**Usage**:

```bash
sshmgr -e
sshmgr --edit
```

**Behavior**: Creates the configuration directory and `known_hosts.json` file if it
does not exist, then opens the file in `$EDITOR` for editing.

### `-p` / `--ping`

**Description**: Ping all known hosts in parallel using fping.

**Usage**:

```bash
sshmgr -p
sshmgr --ping
```

**Behavior**: Reads all host addresses from `known_hosts.json` and pings them in
parallel. Output shows online/offline status for each host.

### `-h` / `--help`

**Description**: Display help/usage information and available command-line options.

**Usage**:

```bash
sshmgr -h
sshmgr --help
```

**Behavior**: Prints a formatted help message showing all available options and
usage patterns.

### `-j` / `--jumphost`

**Description**: Connect to a specific host using a jumphost (bastion host).

**Usage**:

```bash
sshmgr -j <host_name>
sshmgr --jumphost <host_name>
```

**Behavior**: When used with a host name, connects to the specified host using its
configured jumphost. If the host has a jumphost configured in `known_hosts.json`, the
SSH `-J` flag is automatically used.

**Note**: This option is useful for quickly connecting to a host without going
through the interactive fzf menu.

### `-f` / `--fzf`

**Description**: Force the fzf host selection menu.

**Usage**:

```bash
sshmgr -f
sshmgr --fzf
```

**Behavior**: Forces the interactive fzf host selection menu to appear, even when other
options might normally take precedence.

### `-t` / `--test`

**Description**: Test SSH connection to a host without fully connecting.

**Usage**:

```bash
sshmgr -t <host_name>
sshmgr --test <host_name>
```

**Behavior**: Attempts to verify connectivity to the specified host. Checks if the host
is online (using fping if available) and validates SSH connectivity. Does not enter
an interactive SSH session.

**Note**: This is useful for verifying that a host is reachable before attempting
a full SSH connection.

### `-v` / `--version`

**Description**: Display the current version of sshmgr.

**Usage**:

```bash
sshmgr -v
sshmgr --version
```

**Behavior**: Prints the version number and basic package information.

### No Argument (Interactive Mode)

**Description**: Open the interactive fzf host selection menu.

**Usage**:

```bash
sshmgr
```

**Behavior**: Displays an fzf menu with all known hosts from `known_hosts.json`. Select
a host to connect via SSH. If a host has a jumphost configured, SSH will automatically
use the `-J` flag.

### Option Summary Table

| Option | Short | Long | Description |
|--------|-------|------|-------------|
| Edit | `-e` | `--edit` | Open config file in editor |
| Ping | `-p` | `--ping` | Ping all hosts in parallel |
| Help | `-h` | `--help` | Show this help message |
| Jumphost | `-j` | `--jumphost` | Connect via jumphost |
| Fzf | `-f` | `--fzf` | Force fzf selection |
| Test | `-t` | `--test` | Test SSH connectivity |
| Version | `-v` | `--version` | Show version information |

If multiple options are provided, the last recognized option takes effect, following
the bash `case` statement priority order in the script.

## Usage Examples

### First Connection

1. Add your first host to `~/.config/sshmgr/known_hosts.json`:

```json
{
  "hosts": [
    {
      "name": "my-server",
      "host": "192.168.1.100",
      "user": "ubuntu",
      "port": "22"
    }
  ]
}
```

2. Run the host selection:

```bash
sshmgr
```

3. Use arrow keys or type to filter, then press Enter to connect

### Connecting Through a Jumphost

```json
{
  "hosts": [
    {
      "name": "internal-server",
      "host": "10.0.0.50",
      "user": "admin",
      "port": "22",
      "jumphost": "jump-server.example.com"
    }
  ]
}
```

Then select the host from the menu, and sshmgr will automatically use the jumphost.

### Custom Port

```json
{
  "hosts": [
    {
      "name": "web-server",
      "host": "example.com",
      "user": "deploy",
      "port": "2222"
    }
  ]
}
```

### Parallel Ping

```bash
sshmgr -p
# or
sshmgr --ping
```

This will ping all known hosts in parallel using fping.

### Edit Configuration

```bash
sshmgr -e
# or
sshmgr --edit
```

This opens `~/.config/sshmgr/known_hosts.json` in your `$EDITOR` (default: nano).

## Configuration File

The configuration is stored at `~/.config/sshmgr/known_hosts.json`. The file
follows a simple JSON structure with a `hosts` array containing host definitions.

### JSON Structure

```json
{
  "hosts": [
    {
      "name": "string",
      "host": "string",
      "user": "string",
      "port": "string",
      "jumphost": "string"
    }
  ]
}
```

### Field Descriptions

| Field | Type | Required | Description | Default | Example |
|-------|------|----------|-------------|---------|---------|
| `name` | string | Yes | Display name shown in the fzf selection menu. This is the identifier used to look up the host. | — | `"intel-NUC (LAN)"` |
| `host` | string | Yes | Hostname or IP address to connect to via SSH. | — | `"192.168.178.60"` |
| `user` | string | No | SSH username to use when connecting. If not specified, SSH will use the current user or prompt for authentication. | Current user | `"root"` |
| `port` | string | No | Custom SSH port number. If not specified, defaults to port 22. | `"22"` | `"2222"` |
| `jumphost` | string | No | Optional jump host (bastion host) to use for connection via SSH `-J` flag. If specified, all connections to this host will go through the jumphost. | `null` (no jumphost) | `"jump-server.example.com"` |

#### `name` (Required)

The display name that appears in the fzf host selection menu. This is what you type
or filter when using the interactive menu.

- Must be unique within the hosts array
- Used by the script to look up the host's connection details
- Appears in the fzf preview window

#### `host` (Required)

The hostname or IP address of the SSH target. This is the actual address you connect to.

- Can be a domain name, IPv4 address, or IPv6 address
- Must be reachable from your network (or through the jumphost if configured)

#### `user` (Optional)

The SSH username to authenticate as. If omitted, SSH will use the current local user.

- If not provided, SSH defaults to the current system user
- Useful for hosts where you authenticate as a different user than your local one

#### `port` (Optional)

The SSH port to connect to. Defaults to `22` if not specified.

- Useful for servers running SSH on non-standard ports
- Must match the port the SSH daemon is listening on

#### `jumphost` (Optional)

The jump host (also called bastion host or proxy) to use for the connection. When
specified, sshmgr uses SSH's `-J` flag to connect through the jumphost to the final
target host.

- The jumphost must be reachable first, then the connection proceeds to the target host
- If the host has a jumphost, the connection command becomes:
  `ssh -J jumphost user@host`

### Complete Example

```json
{
  "hosts": [
    {
      "name": "intel-NUC (LAN)",
      "host": "192.168.178.60",
      "user": "root",
      "port": "22"
    },
    {
      "name": "intel-NUC (tailscale)",
      "host": "100.89.254.126",
      "user": "root",
      "port": "22",
      "jumphost": "jump.example.com"
    },
    {
      "name": "web-server",
      "host": "example.com",
      "user": "deploy",
      "port": "2222"
    }
  ]
}
```

Default configuration (created automatically on first run):

```json
{
  "hosts": []
}
```

### Schema Validation

The configuration file is validated on script startup using `jq`. The following checks
are performed:

1. File must exist and be valid JSON
2. Must contain a `.hosts` key

If validation fails, the script outputs an error and exits:

```bash
$ sshmgr
invalid json
```

### Migration from Old Format

Previously, sshmgr used a plain text format. The old format is no longer used, but can
be migrated by converting entries to the new JSON format:

**Old format**:
```
# list of known hosts
# layout: <username>@<address> - <connection name>

my-server root@192.168.1.100 - my-server
```

**New format** (`known_hosts.json`):
```json
{
  "hosts": [
    {
      "name": "my-server",
      "host": "192.168.1.100",
      "user": "root"
    }
  ]
}
```

### Best Practices

1. **Keep JSON valid**: Use a JSON validator or editor with JSON support to avoid
   syntax errors that would prevent sshmgr from starting.

2. **Use meaningful names**: Choose descriptive `name` values that help you identify
   hosts quickly in the fzf menu.

3. **Document jumphosts**: When using jumphosts, ensure both the jumphost and target
   host have proper SSH configuration and keys set up.

4. **Test after editing**: After running `sshmgr -e`, verify that your changes work
   by running `sshmgr` to select a host and confirm the connection.

5. **Backup configuration**: Consider backing up `known_hosts.json` before making
   significant changes.

## User Guide

### Adding Hosts

#### Step 1: Open the Configuration File

```bash
sshmgr -e
```

This opens `~/.config/sshmgr/known_hosts.json` in your default editor (nano by default).

#### Step 2: Add a New Host Entry

Add a new object to the `hosts` array following this format:

```json
{
  "name": "my-new-host",
  "host": "192.168.1.50",
  "user": "root",
  "port": "22"
}
```

#### Step 3: Save and Close

Save the file and exit the editor. The change takes effect immediately on the next
`sshmgr` command.

#### Step 4: Verify the Host

```bash
sshmgr
# Use arrow keys to filter, then press Enter on your new host
```

### Connecting to Hosts

#### Interactive Selection (Default Mode)

```bash
sshmgr
```

This opens the fzf host selection menu:

```
SSH > [Type to filter, Press Enter to connect, CTRL+Q to quit]
```

**Navigation:**
- Type to filter hosts by name
- Use arrow keys to navigate
- Press **Enter** to connect to the selected host
- Press **CTRL+Q** to quit without connecting

#### Direct Connection via CLI

While sshmgr is primarily designed for interactive use, you can connect to a specific
host using the `--jumphost` option:

```bash
sshmgr -j <host_name>
```

#### SSH Connection Details

When you select a host, sshmgr automatically:

1. Retrieves the host's user, port, and jumphost configuration
2. If a jumphost is configured: `ssh -J jumphost -p port user@host`
3. If no jumphost: `ssh -p port user@host`
4. Uses the specified port or defaults to 22

### Using Jumphosts (Bastion Hosts)

Jumphosts allow you to connect to internal/private hosts through a publicly accessible
intermediate server.

#### Configuration

Add a `jumphost` field to your host entry:

```json
{
  "name": "internal-database",
  "host": "10.0.0.50",
  "user": "admin",
  "jumphost": "bastion.example.com"
}
```

#### How It Works

When you select a host with a jumphost configured:

1. sshmgr detects the `jumphost` field
2. It constructs the SSH command: `ssh -J jumphost -p port user@host`
3. SSH automatically connects through the jumphost to the final destination

#### Multiple Jumphosts

SSH supports multiple jumphosts separated by commas:

```json
{
  "name": "deep-internal",
  "host": "10.0.0.1",
  "user": "admin",
  "jumphost": "bastion1.example.com,bastion2.example.com"
}
```

### Ping Functionality

#### Ping All Hosts

```bash
sshmgr -p
```

This pings all known hosts in parallel using fping. Output shows the status of each host.

**Use Cases:**

1. **Check host status before connecting**: Verify a host is online before attempting SSH
2. **Network troubleshooting**: Identify which hosts are reachable on your network
3. **After configuration changes**: Verify new hosts are added and old ones are still reachable

#### Test a Single Host

```bash
sshmgr -t <host_name>
```

This tests SSH connectivity to the specified host and reports whether it's online and
if SSH is reachable.

### Host Management Tips

#### Editing Existing Hosts

```bash
sshmgr -e
# Modify the JSON entry for the host you want to change
# Save and exit
# Verify: sshmgr
```

#### Removing a Host

1. Open configuration: `sshmgr -e`
2. Remove the host entry from the `hosts` array
3. Save and exit
4. Verify: `sshmgr` (the host should no longer appear in the menu)

#### Adding Multiple Hosts at Once

You can add multiple hosts in a single editing session:

```json
{
  "hosts": [
    {"name": "host1", "host": "192.168.1.10", "user": "root"},
    {"name": "host2", "host": "192.168.1.11", "user": "root"},
    {"name": "host3", "host": "192.168.1.12", "user": "root", "jumphost": "bastion"}
  ]
}
```

### Keyboard Shortcuts (fzf Menu)

| Shortcut | Action |
|----------|--------|
| `Enter` | Connect to selected host |
| `CTRL+Q` | Quit without connecting |
| `Up/Down` | Navigate results |
| `CTRL+U` | Clear the search buffer |
| `?` | Show fzf help |

## Tutorials

### Tutorial 1: First Connection

**Objective**: Connect to your first SSH host using sshmgr's interactive host selection.

**Prerequisites**: sshmgr installed, a host added to `~/.config/sshmgr/known_hosts.json`

#### Step 1: Install sshmgr

If you haven't already:

```bash
# Brew installation
brew tap PyGuy-Programming/sshmgr
brew install sshmgr
```

#### Step 2: Add Your First Host

```bash
sshmgr -e
```

Add a host entry (replace with your actual details):

```json
{
  "hosts": [
    {
      "name": "my-first-server",
      "host": "192.168.1.100",
      "user": "root",
      "port": "22"
    }
  ]
}
```

#### Step 3: Make Your First Connection

```bash
sshmgr
# The fzf menu appears showing "my-first-server"
# Press Enter to connect
```

**Expected Result**: Your SSH connection establishes to `root@192.168.1.100`.
Exit the remote shell with `exit` or `CTRL+D`.

#### Common Issues

| Problem | Solution |
|---------|----------|
| "host not found" error | Ensure the host has a `name` field in the JSON |
| Connection refused | Check host IP, port, and user |
| fzf menu empty | Verify `known_hosts.json` has valid JSON with hosts array |

### Tutorial 2: Multi-Host Management

**Objective**: Manage multiple SSH hosts efficiently using sshmgr's host selection menu.

#### Step 1: Configure Multiple Hosts

```bash
sshmgr -e
```

Add multiple hosts:

```json
{
  "hosts": [
    {
      "name": "dev-server",
      "host": "192.168.1.10",
      "user": "devuser",
      "port": "22"
    },
    {
      "name": "staging-server",
      "host": "192.168.1.11",
      "user": "staginguser",
      "port": "22"
    },
    {
      "name": "prod-server",
      "host": "192.168.1.12",
      "user": "admin",
      "port": "22",
      "jumphost": "bastion.example.com"
    }
  ]
}
```

#### Step 2: Launch the Host Selection Menu

```bash
sshmgr
```

#### Step 3: Filter and Select Hosts

- Type `dev` to filter to the dev-server
- Type `prod` to filter to the prod-server (which has a jumphost)
- Type `staging` to filter to the staging-server

#### Step 4: Connect

Press **Enter** on your selected host. sshmgr will automatically:
- Use the correct user
- Use the correct port
- Use the jumphost if configured

#### Managing Hosts Effectively

**Renaming a host**: run `sshmgr -e` and change the `name` field.

**Searching tips:**
- Type partial names: `dev` matches `development-node`
- Clear search: Press `CTRL+U` to clear the search buffer
- Search case-insensitive: fzf defaults to case-insensitive search

**Verification:**

```bash
sshmgr    # Select each host and verify connections work
sshmgr -p # Ping all hosts to check they're online
```

### Tutorial 3: Jumphost Configuration

**Objective**: Configure and use jumphosts (bastion hosts) to connect to internal
servers through an intermediate jump host.

**Prerequisites**: sshmgr installed, a jumphost (bastion) reachable via SSH, one or
more internal targets behind the jumphost

#### Step 1: Verify Jumphost Access

First, ensure you can SSH to your jumphost directly:

```bash
ssh bastion.example.com
```

Exit the jumphost with `exit`.

#### Step 2: Configure a Host with Jumphost

```bash
sshmgr -e
```

Add a host entry with a jumphost:

```json
{
  "hosts": [
    {
      "name": "internal-database",
      "host": "10.1.1.50",
      "user": "dbadmin",
      "port": "22",
      "jumphost": "bastion.example.com"
    }
  ]
}
```

#### Step 3: Connect Through the Jumphost

```bash
sshmgr
# Select "internal-database" from the fzf menu
# sshmgr automatically uses: ssh -J bastion.example.com -p 22 dbadmin@10.1.1.50
```

**Expected Result**: You're connected to `10.1.1.50` through the jumphost.

#### Advanced Jumphost Scenarios

**Multiple Jumphosts (Chain)**:

```json
{
  "name": "deep-internal",
  "host": "10.0.0.1",
  "user": "admin",
  "jumphost": "bastion1.example.com,bastion2.example.com"
}
```

**Jumphost with Custom Port**:

```json
{
  "name": "secured-server",
  "host": "10.0.0.50",
  "user": "admin",
  "port": "2222",
  "jumphost": "bastion.example.com:2222"
}
```

Note: Port specification for jumphost uses the format `host:port`.

#### Jumphost Best Practices

1. **Use SSH keys**: Configure SSH key-based authentication for both jumphost and
   target hosts to avoid password prompts.

2. **Test incrementally**: First test `ssh -J jumphost target` manually before using
   sshmgr.

3. **Document your topology**: Keep a diagram of which hosts use which jumphosts.

4. **Use consistent usernames**: Where possible, use the same username on jumphost
   and target hosts to simplify configuration.

#### Manual Jumphost Test

Before relying on sshmgr, test the jumphost connection manually:

```bash
ssh -J dbadmin@bastion.example.com dbadmin@10.1.1.50
```

If this works, sshmgr will work the same way when you select the configured host.

## Troubleshooting

### Common Issues and Solutions

#### 1. "invalid json" Error on Startup

**Symptom**:
```bash
$ sshmgr
invalid json
```

**Cause**: The `known_hosts.json` file contains malformed or invalid JSON.

**Solutions**:

| Solution | Steps |
|----------|-------|
| **Check for syntax errors** | Run `sshmgr -e` to open the config file. Look for: trailing commas, missing quotes, unmatched braces |
| **Use a JSON validator** | Validate the file at [jsonlint.com](https://jsonlint.com) or with `jq . ~/.config/sshmgr/known_hosts.json` |
| **Fix and retry** | After fixing, run `sshmgr` again. The script auto-validates on startup. |

#### 2. Host Not Appearing in fzf Menu

**Symptom**: Running `sshmgr` shows an empty menu or the host doesn't appear.

**Solutions**:

| Solution | Steps |
|----------|-------|
| **Verify the `name` field** | Each host MUST have a `name` field. Run `sshmgr -e` and check each entry |
| **Check JSON validity** | Run `jq . ~/.config/sshmgr/known_hosts.json` — if this errors, fix the JSON |
| **Empty hosts array** | If the JSON is `{"hosts": []}`, the menu will be empty. Add hosts first |

#### 3. SSH Connection Fails After Selecting Host

**Possible Causes and Solutions**:

| Cause | Solution |
|-------|----------|
| **Wrong hostname or IP** | Verify the `host` field. Try connecting manually: `ssh -p 22 user@192.168.1.100` |
| **Wrong username** | Check the `user` field. If omitted, SSH uses the current local user |
| **Custom port not recognized** | Verify the `port` field. Default is `22` |
| **Jumphost issues** | Test manually: `ssh -J jumphost user@host` |
| **Firewall blocking** | Ensure the SSH port is open on both the host and any firewall between networks |
| **SSH key not loaded** | Load your SSH key: `ssh-add ~/.ssh/id_rsa` before running sshmgr |
| **DNS resolution** | If using hostnames, ensure they're resolvable. Try using IP addresses instead |

**Diagnostic steps**:
1. Run `sshmgr -p` to verify hosts are online
2. Test SSH manually: `ssh -p <port> <user>@<host>`
3. If using jumphost: `ssh -J <jumphost> <user>@<target>`

#### 4. Jumphost Connection Fails

| Issue | Solution |
|-------|----------|
| **Jumphost unreachable** | Ping the jumphost: `ping bastion.example.com` |
| **SSH to jumphost fails** | Test manually: `ssh bastion.example.com`. If this fails, the issue is with jumphost access, not sshmgr |
| **Target unreachable from jumphost** | Ensure the jumphost can reach the target |
| **Firewall between jumphost and target** | Check that the target's port is open and accessible from the jumphost's network |

#### 5. Ping (-p) Shows All Hosts as Offline

| Cause | Solution |
|-------|----------|
| **fping not installed** | Install fping: `brew install fping` (macOS) or `sudo apt-get install fping` (Debian/Ubuntu) |
| **Firewall blocking ping** | ICMP ping may be blocked by firewalls. Hosts may be online but not respond to ping |
| **Hosts unreachable** | Verify network connectivity. Can you ping the hosts directly? |

**Note**: Even if ping shows offline, SSH connections may still work (many servers block ICMP ping but allow SSH).

#### 6. Script Not Found or Command Not Recognized

```bash
$ sshmgr
bash: sshmgr: command not found
```

| Solution | Steps |
|----------|-------|
| **Alias not set up** | Ensure the alias is in `.bashrc` and re-source it: `source ~/.bashrc` |
| **Path not included** | Add the sshmgr directory to your PATH |
| **Brew not installed** | `brew install sshmgr` (after `brew tap PyGuy-Programming/sshmgr`) |
| **Wrong shell** | The script is bash-specific. Ensure you're using bash |

#### 7. Configuration File Not Created

| Solution | Steps |
|----------|-------|
| **Directory permissions** | Ensure `~/.config/sshmgr/` can be created: `mkdir -p "$HOME/.config/sshmgr"` |
| **$HOME not set** | Verify your home directory is correctly detected: `echo $HOME` |
| **Manual creation** | Create the file manually with the default content below |

**Default content** (created automatically by the script):
```json
{
  "hosts": []
}
```

### Quick Diagnostic Commands

Run these commands to diagnose common issues:

```bash
# 1. Check if script runs at all
sshmgr -h

# 2. Validate JSON configuration
jq . ~/.config/sshmgr/known_hosts.json

# 3. Check if required tools are available
which fzf fping jq ssh

# 4. Test ping functionality
sshmgr -p

# 5. Verify hosts file exists and is valid
cat ~/.config/sshmgr/known_hosts.json
```

### Getting Further Help

If your issue is not covered here:

1. **Run diagnostics**: Use the quick diagnostic commands above
2. **Check the JSON**: Ensure `known_hosts.json` is valid JSON
3. **Test manually**: Try the SSH command that sshmgr would execute

**Report issues**: If you've identified a bug, check the
[project repository](https://github.com/pyguy-programming/sshmgr/issues) for existing
issues or submit a new one with:
- Description of the issue and steps to reproduce
- Output of `jq . ~/.config/sshmgr/known_hosts.json` (JSON validation)

## Alias

After installation, use:

```bash
sshmgr     # Open host selection
sshmgr -e  # Edit configuration
sshmgr -p  # Ping all hosts
sshmgr -h  # Show help
```

## License

MIT — see [LICENSE.md](LICENSE.md) for the full license text.
