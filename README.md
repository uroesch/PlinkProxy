[![Build](https://github.com/uroesch/PlinkProxy/workflows/build-release/badge.svg)](https://github.com/uroesch/PlinkProxy/actions?query=workflow%3Abuild-release)
[![GitHub release (latest by date including pre-releases)](https://img.shields.io/github/v/release/uroesch/PlinkProxy?include_prereleases)](https://github.com/uroesch/PlinkProxy/releases)

# PlinkProxy

## Executive Overview

PlinkProxy is a small wrapper and INI configuration file around the `plink`
command from the `Putty` suite of tools. It is meant to dig ssh tunnels and
create socks proxies into various networks to cut down on excessive jump
host hoping.


## Prerequisites
* Windows 7 or higher
* [plink](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html)
* [pageant](https://www.chiark.greenend.org.uk/~sgtatham/putty/latest.html)
* [ssh-keys](https://en.wikipedia.org/wiki/Secure_Shell#Authentication:_OpenSSH_Key_management)

## Build Dependencies
* [AutoIT](https://www.autoitscript.com/)

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

### Example Socks

```ini
[Socks:8881]
name = dmz
enabled = yes
setup = no
jump_host = dmz-jumphost.acme.org
```

* `Socks:8881` instructs to create a local Socks proxy on port `8881`.
   Equivalent to `-D 8881` on the command line.
* `enabled` should the socks proxy be started or not. Accepts `yes` or `no`.
* `setup` set to `yes` if the jumphost is used for the first time. Accepts `yes` or `no`
* `jump_host` defines the termination point of the Socks proxy.


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
* `enabled` should the socks tunnel be started or not. Accepts `yes` or `no`.
* `setup` set to `yes` if the jumphost is used for the first time. Accepts `yes` or `no`.
* `jump_host` defines the termination point of the tunnel.
* `target_host` forward address or ip when leaving the tunnel.
* `target_port` forward port when leaving the tunnel.

Command line equivalent of `-L 11636:ldap.dmz.acme.org:636`


### Further Reading
* [INI Format](https://en.wikipedia.org/wiki/INI_file)


## Build

There is a small cmd build script (`CompilePlinkProxy.cmd`) to compile and ZIP up the relase.

```
C:> bin\CompilePlinkProxy.cmd
```

## Todo
* Make it a tray application.
* Enable overriding defaults from the Globals section in each of the connections.
