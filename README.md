# postinstall.sh

Bash Script to automate post-installation steps.
Helps to install packages on REDHAT based operating systems.

![Red Hat](img/redhat.png)

## Overview

`postinstall.sh` is simple bash shell script which in turn generates scripts.
The generation depends on the operating system and type of installation.
The templates that are included in the generation can be stored in the file system or on a web server.

`postinstall.sh` is not a configuration management system.
If you want to install many servers automatically, you should look at [ansible](https://github.com/ansible/ansible).
But if you want to quickly reinstall your laptop or Raspberry Pi, `postinstall.sh` can help you.

## Installation

Example:

```
mkdir install
cd install
vi packages.list
```

Run as root:

```
bash postinstall.sh -b install
```

## Usage

```
Usage: postinstall.sh [-t <TYPE>] [-b <BASE>] [-h]:
        [-t <TYPE>]      sets the type of installation (default: server)
        [-b <BASE>]      sets the base url or dir (default: https://raw.githubusercontent.com/Cyclenerd/postinstall/master/base)
        [-h]             displays help (this message)
```

Example: `postinstall.sh` or `postinstall.sh -t workstation`

## Program Flow

* Determine operating system and architecture
* Check package manager and requirements
* Generate script to run before and after installation and list of packages to install
* Install packages


## Requirements

Only `bash`, `curl`, `tput` (`ncurses-utils`) and a package manager for the respective operating system:

* Red Hat / Fedora / CentOS → `dnf` or `yum`

## License

GNU Public License version 3.
Please feel free to fork and modify this on GitHub (https://github.com/Cyclenerd/postinstall).
