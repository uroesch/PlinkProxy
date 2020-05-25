[![Build](https://github.com/uroesch/PlinkProxy/workflows/build-release/badge.svg)](https://github.com/uroesch/PlinkProxy/actions?query=workflow%3Abuild-release)
[![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/uroesch/PlinkProxy?include_prereleases)](https://github.com/uroesch/PlinkProxy/releases)
[![Runs on](https://img.shields.io/badge/runs%20on-Win64%20%26%20Win32-blue)](#runtime-dependencies)

# PlinkProxy

## Executive Overview

PlinkProxy is a small wrapper and INI configuration file around the `plink`
command from the [`Putty`][putty] suite of tools. It is meant to dig ssh 
tunnels and create socks proxies into various networks to cut down on 
excessive jump host hoping.

It was conceived in a corporate environment with many dispersed environments which
were not directly accessible from the desktop. But the resources to be managed be it
databases, middleware service and web services to name but a few, required graphical
access to these resources.

PlinkProxy has been successfully used with [FoxyProxy][foxyproxy], [DBeaver][dbeaver], 
[WinSCP][winscp] and [FreeRDP][freerdp] over [SOCKS5][socks] and [LDAP Admin][ldapadmin], 
[Apache Directory Studio][directorystudio] over local SSH tunnel.

## Screenshot

![Plink Proxy Control Window][control-window]

## Prerequisites
* Windows 7 or higher
* [plink][putty-download]
* [pageant][putty-download]
* [ssh-keys][ssh-keys]

## Build Dependencies
* [AutoIT][autoit]

## Installation

### Download
The latest release can be obtained from the
[github releases page](https://github.com/uroesch/PlinkProxy/releases).
It is provided in the form of a ZIP file or a OneClick installer.

### ZIP File
`PlinkProxy` was written with portability in mind. The ZIP file expands into
a directory called `PlinkProxy` which contains the `PlinkProxy.exe` file and
a sample configuration file (`PlinkProxy.ini-sample`). Before running the
binary copy the `PlinkProxy.ini-sample` file to `PlinkProxy.ini` and modify
to match your environment. Then run `PlinkProxy.exe`.

### OneClick Installer
The provided installer is as minimial as it possibly can get. The installtion
copies files to the '%AppData%\PlinkProxy` directory and creates a start menu
item. To start the application navigate to the `%AppData%\PlinkProxy`
directory and rename the `PlinkProxy.ini-sample` file to `PlinkProxy.ini`.
Change the freshly copied configuration file to match your environment.
Go to the start menu and navigate to the PlinkProxy entry and start the
application.


## Configuration

### Introduction
`PlinkProxy.exe` requires a configuration file called `PlinkProxy.ini` to be
present in the same directory as the executable. If it is a new installation
copy the file `PlinkProxy.ini-sample` to `PlinkProxy.ini` and modify the file
to suit your needs.

The INI configuration is split into 2 distinct sections. The first one is 
called `Globals` and defines settings used in all the `plink` connections.

Further, each connection is defined in its own section staring with either
`Socket` or `LocalTunnel` followed by a colon `:` and then the port number. 
E.g. `Socket:8880`.

Below are some more details how to setup the INI file for your environment.

### Example Globals

```ini
[Globals]
login         = joedoe
path          = %ProgramFiles%\Putty
ssh_keys_dir  = %UserProfile%\etc
first_hop     = jumphost.acme.org
plink_options = -N -A -v -batch
```

* `login` defines the user name used for the `first_hop` and the `jump_host`s
* `path` is used to locate the `plink` executable. Windows command variables are
  being properly expanded.
* `first_hop` is the jump_host which is used to initiate the second hop to the
  final destination.
* `plink_options` are the global options used to spawn the connection.

Since version `v0.0.14-alpha` a special environmental variable called `%ScriptDir%`
has been added. It expands to the directory where the `PlinkProxy.exe` is run from.
This is a handy shortcut for the `path` defintion should `plink.exe` and 
`pageant.exe` be located in the same directory as `PlinkProxy.exe`.

### Example Socks

```ini
[Socks:8881]
name = dmz
enabled = yes
setup = no
jump_host = dmz-jumphost.acme.org
jump_port = 2222
```

* `Socks:8881` instructs to create a local Socks proxy on port `8881`.
   Equivalent to `-D 8881` on the command line.
* `enabled` should the socks proxy be started or not. Accepts `yes` or `no`.
* `setup` set to `yes` if the jumphost is used for the first time. Accepts `yes` or `no`
* `jump_host` defines the termination point of the Socks proxy.
* `jump_port` defines the port of `jump_host'`s connection, if ommited defaults to 22.


### Example LocalTunnel

```ini
[LocalTunnel:11636]
name = ldap-server
enabled = yes
setup = no
jump_host = dmz-jumphost
target_host = ldap.dmz.acme.org
target_port  = 636
```

* `LocalTunnel:11636` instructs to create a local tunnel port forward on `11636`.
* `enabled` should the tunnel be started or not. Accepts `yes` or `no`.
* `setup` set to `yes` if the jumphost is used for the first time. Accepts `yes` or `no`.
* `jump_host` defines the termination point of the tunnel.
* `target_host` forward address or ip when leaving the tunnel.
* `target_port` forward port when leaving the tunnel.

Command line equivalent of `-L 11636:ldap.dmz.acme.org:636`

### Example RemoteTunnel

With version `v0.0.10-alpha` the new tunnel type `RemoteTunnel` was introduced.

```ini
[RemoteTunnel:5900]
name = vnc-remote-assistance
enabled = yes
setup = no
jump_host = jumphost.acme.org
target_host = localhost
target_port  = 5900
```

* `RemoteTunnel:5900` instructs to create a remote tunnel listening on port `5900`
   of the `jump_hosts`'s loopback interface.
* `enabled` should the tunnel be started or not. Accepts `yes` or `no`.
* `setup` set to `yes` if the jumphost is used for the first time. Accepts `yes` or `no`.
* `jump_host` defines the termination point of the tunnel where to listen for incoming traffic.
* `target_host` forward address or ip when receiving a connection on the tunnel.
* `target_port` forward port when receiving a connection on the tunnel.

Command line equivalent of `-R 5900:localhost:5900`

**Note:** The global option for remote tunnels which listens on all interfaces is not yet implemented.
Due internal data representation a remote tunnel must use a unique port number with in the `[RemoteTunnel]`
namespace.

### Commandline Options

Since version `v0.0.11-alpha` `PlinkProxy` is able to parse command line options. Below is a list of the
short and long options available.

```shell

Usage:
        PlinkProxy.exe <Options>

        Options:
        -h | --help
                Display this message and exit
        -c | --config-file
                Path to config file
                Default: PlinkProxy.ini
        -l | --log-file
                Path to log file
                Default: PlinkProxy.log

```

### Further Reading
* [INI Format](https://en.wikipedia.org/wiki/INI_file)


## Build

There is a small cmd build script (`CompilePlinkProxy.cmd`) to compile and ZIP up the relase.

```
C:> bin\CompilePlinkProxy.cmd
```
## Known Issues
- [ ] Update of status list not working correctly if name of connection was changed.
- [ ] Setup mode constains logic errors and does not work as initially intended.

## Todo
- [ ] Make it a tray application.
- [ ] Enable overriding defaults from the Globals section in each of the connections.

[putty]: https://www.chiark.greenend.org.uk/~sgtatham/putty/
[foxyproxy]: https://www.chiark.greenend.org.uk/~sgtatham/putty/
[dbeaver]: https://dbeaver.io/
[winscp]: https://winscp.net/
[freerdp]: https://cloudbase.it/freerdp-for-windows-nightly-builds/
[socks]: https://en.wikipedia.org/wiki/SOCKS
[ldapadmin]: http://www.ldapadmin.org/
[directorystudio]: https://directory.apache.org/studio/
[putty-download]: https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html
[ssh-keys]: https://en.wikipedia.org/wiki/Secure_Shell#Authentication:_OpenSSH_Key_management
[autoit]: https://www.autoitscript.com/

[control-window]: images/PlinkProxy_v0.0.8-alpha_control-window.png
