# Pinnwand

Pinnwand is a straightforward pastebin service designed for simplicity and ease of use. It provides a clean web interface to share and manage text snippets, code, or notes. It supports features like syntax highlighting, expiration times, and revocation.

## Pinnwand Installer Script

The Pinnwand installer script is a Bash script designed to automate the installation, upgrade, and setup of Pinnwand on a Linux system. It sets up and installs Pinnwand into a Python virtual environment, keeping it separate from the base system.

### Prerequisites

- Python 3.8 or higher with `pip`
- Git installed on the system.

### Features

1. **Automated Installation**: The script can install Pinnwand by cloning its repository and setting up a virtual environment.
2. **Upgrade Support**: It can update Pinnwand to the latest version, a specified Git reference or main development branch.
3. **Custom Source Testing**: A `USE_LOCAL_SRC` option allows using manually downloaded sources and avoids the `git` dependency.

### Usage

1. Clone or download the script.
2. Set the username, install path and source path in the script.
3. Run the script as the `pinnwand` user:
   ```bash
   sudo -u pinnwand-user ./pinnwand-installer.sh
   ```
Simply re-run the script to upgrade and existing installation.

### Running pinnwand

Create a `config.toml` with desired configuration options.

An example config file is available in the source tree under `etc/pinnwand-toml-example`.

#### Manually
Specify the configuring file and the TCP/IP listening port on the command line.
```bash
sudo -u pinnwand-user path/to/pinnwand/venv/bin/pinnwand --configuration-path config.toml http --port 1234
```

#### OpenRC init.d script
The provided init scripts help you run pinnwand as a service on a OpenRC system such as Gentoo and Alpine Linux.

1. Cooy `pinnwand.initd` to `/etc/init.d/pinnwand`
2. Cooy `pinnwand.confd` to `/etc/conf.d/pinnwand`
3. Set the correct user and path in `/etc/conf.d/pinnwand`
4. Run `rc-update add pinnwand` to enable autostart on boot.
5. Run `rc-service pinnwand start` to start pinnwand now.


## gist.sh - paste from command line
Sometimes you nay need to paste a log file, a snippet or code or a kernel log to a pastebin service.

The siplest way may be to use `curl`, as described on https://pinnwand.readthedocs.io/en/latest/tricks.html

```bash
cat file | curl -X POST http://localhost:8000/curl -F 'raw=<-'
```

I wanted a little more control over language (lexer) selection and be able to upload several files in one go, so I expanded on the curl script and ended up with `gist.sh`.

```
Usage: gist.sh [options] [file1 file2 ...]
Options:
  -e, --expiry <expiry>   Set the expiry time for the paste (e.g., 1day, 1hour).
                          Default is '1day' if not specified.
  -l, --lexer <lexer>     Specify the lexer to use for syntax highlighting.
  --lexers                List all available lexers in 'name : description' format.
  -h, --help              Show this help message and exit.
```

### Examples
```bash
  gist.sh -e 1hour -l python file1 file2
  gist.sh --lexers
  dmesg | gist.sh -l kmsg
```