# iocage-plugin-gitea

An [iocage][] plugin for [Gitea][], a community managed lightweight code hosting
solution written in Go.

[gitea]: https://gitea.io/
[iocage]: https://github.com/iocage/iocage

|         |                                      |
| ------: | ------------------------------------ |
|      CI | [![CI Status][badge-ci-overall]][ci] |
| License | [![License][badge-license]][license] |

**Table of Contents**

<!-- toc -->

- [Installation](#installation)
- [Usage](#usage)
  - [Enabling TLS Mode with an SSL Certificate](#enabling-tls-mode-with-an-ssl-certificate)
  - [Persisting Data](#persisting-data)
    - [Initial Setup](#initial-setup)
    - [Reattaching Data in a New Jail](#reattaching-data-in-a-new-jail)
- [Configuration](#configuration)
  - [User Serviceable Configuration](#user-serviceable-configuration)
  - [`gitea_app_name`](#gitea_app_name)
  - [`gitea_nginx_mode`](#gitea_nginx_mode)
  - [`gitea_internal_token`](#gitea_internal_token)
  - [`gitea_lfs_jwt_secret`](#gitea_lfs_jwt_secret)
  - [`gitea_oauth2_jwt_secret`](#gitea_oauth2_jwt_secret)
  - [`gitea_secret_key`](#gitea_secret_key)
  - [System Configuration](#system-configuration)
  - [`gitea_domain`](#gitea_domain)
  - [`gitea_user_home`](#gitea_user_home)
  - [`gitea_user`](#gitea_user)
  - [`gitea_work_dir`](#gitea_work_dir)
- [Code of Conduct](#code-of-conduct)
- [Issues](#issues)
- [Contributing](#contributing)
- [Release History](#release-history)
- [Authors](#authors)
- [License](#license)

<!-- tocstop -->

## Installation

This plugin can be installed via the [fnichol/iocage-plugin-index][index] plugin
collection which is not installed on FreeNAS or TrueOS by default. For example,
to install the plugin with a name of `gitea` and a dedicated IP address:

```console
$ jail=gitea
$ ip_addr=10.200.0.110

$ sudo iocage fetch \
  -g https://github.com/fnichol/iocage-plugin-index \
  -P gitea \
  --name $jail \
  ip4_addr="vnet0|$ip_addr"
```

[index]: https://github.com/fnichol/iocage-plugin-index

## Usage

### Enabling TLS Mode with an SSL Certificate

TLS mode is handled by the nginx service which forwards all traffic back to the
Gitea service via a local Unix domain socket. To enable TLS you will need a
public SSL certificate (i.e. a `cert.pem` file) and the private server key (i.e.
a `key.pem` file) installed into the nginx configuration directory of the
plugin's jail. Assuming a running installed plugin called `gitea` with a jail
mount point of `/mnt/tank/iocage/jails/gitea` in the host system, the following
will setup Gitea to run under HTTPS:

```console
$ jail=gitea
$ jail_mnt=/mnt/tank/iocage/jails/$jail

$ sudo cp cert.pem key.pem $jail_mnt/root/usr/local/etc/nginx/
$ sudo chown 0644 $jail_mnt/root/usr/local/etc/nginx/cert.pem
$ sudo chown 0600 $jail_mnt/root/usr/local/etc/nginx/key.pem
$ sudo iocage exec $jail plugin config set gitea_nginx_mode https
$ sudo iocage exec $jail plugin services restart
```

### Persisting Data

There are 2 primary directories that contain data in a Gitea jail:

- `/var/db/gitea` All internal state and configuration for Gitea
- `/usr/local/git` All hosted repository data

A good strategy is to create a ZFS dataset per directory and mount them into the
jail. This way, the jail can be destroyed and later re-created without losing
the Gitea configuration or the repository data itself.

#### Initial Setup

To set this up for the first time, the ZFS datasets will need to be created and
any initial state in the jail will need to be copied onto the datasets.

```console
$ jail=gitea
$ dataset=tank/src/gitea
$ mnt=/mnt/$dataset

# Create the ZFS datasets on the host system
$ sudo zfs create $dataset
$ sudo zfs create $dataset/config
$ sudo zfs create $dataset/repos

# Stop the Gitea service
$ sudo iocage exec $jail service gitea stop

# Mount the ZFS dataset for config data & copy existing data to dataset
$ sudo iocage exec $jail mv /var/db/gitea /var/db/_gitea
$ sudo iocage exec $jail mkdir /var/db/gitea
$ sudo iocage fstab -a $jail "$mnt/config /var/db/gitea nullfs rw 0 0"
$ sudo iocage exec $jail chmod 0750 /var/db/gitea
$ sudo iocage exec $jail chown git:git /var/db/gitea
$ sudo iocage exec $jail sh -c \
  'tar cf - -C /var/db/_gitea . | tar xpf - -C /var/db/gitea'
$ sudo iocage exec $jail rm -rf /var/db/_gitea

# Mount the ZFS dataset for repos data & copy existing data to dataset
$ sudo iocage exec $jail mv /usr/local/git /usr/local/_git
$ sudo iocage exec $jail mkdir /usr/local/git
$ sudo iocage fstab -a $jail "$mnt/repos /usr/local/git nullfs rw 0 0"
$ sudo iocage exec $jail chmod 0755 /usr/local/git
$ sudo iocage exec $jail chown git:git /usr/local/git
$ sudo iocage exec $jail sh -c \
  'tar cf - -C /usr/local/_git . | tar xpf - -C /usr/local/git'
$ sudo iocage exec $jail rm -rf /usr/local/_git

# Start the Gitea service
$ sudo iocage exec $jail service gitea start
```

#### Reattaching Data in a New Jail

If you are setting up a fresh new plugin instance and want to re-use the
configuration and repository data from a prior instance, then you can re-attach
the existing datasets into the new instance.

```console
$ jail=gitea_2
$ dataset=tank/src/gitea
$ mnt=/mnt/$dataset

# Stop the Gitea service
$ sudo iocage exec $jail service gitea stop

# Reattach the existing ZFS dataset with the config data
$ sudo iocage exec $jail rm -rf /var/db/gitea
$ sudo iocage exec $jail mkdir /var/db/gitea
$ sudo iocage fstab -a $jail "$mnt/config /var/db/gitea nullfs rw 0 0"

# Reattach the existing ZFS dataset with the repos data
$ sudo iocage exec $jail rm -rf /usr/local/git
$ sudo iocage exec $jail mkdir /usr/local/git
$ sudo iocage fstab -a $jail "$mnt/repos /usr/local/git nullfs rw 0 0"

# Start the Gitea service
$ sudo iocage exec $jail service gitea start
```

## Configuration

### User Serviceable Configuration

The following configuration is intended to be modified by a plugin user.

### `gitea_app_name`

Application name, used in the page title.
([Gitea reference](https://docs.gitea.io/en-us/config-cheat-sheet/#overall-default))

- default: `"Gitea: Git with a cup of tea"`

To change this value, use the installed `plugin` program and restart the
services to apply the updated configuration:

```console
$ plugin config set gitea_app_name "Gitea: Git with a cup of tea"
$ plugin services restart
```

### `gitea_nginx_mode`

Whether or not TLS is being used for the service. See the TLS section for more
information regarding how to install an SSL certificate.

- default: `"http"`
- valid values: `"http"`|`"https"`

To change this value, use the installed `plugin` program and restart the
services to apply the updated configuration:

```console
$ plugin config set gitea_nginx_mode http
$ plugin services restart
```

### `gitea_internal_token`

Secret used to validate communication within Gitea binary. This value is
randomly generated at install time.
([Gitea reference](https://docs.gitea.io/en-us/config-cheat-sheet/#security-security))

- default: **generated on install**

To change this value, use the installed `plugin` program and restart the
services to apply the updated configuration:

```console
$ plugin config set gitea_internal_token \
  "`gitea generate secret INTERNAL_TOKEN`"
$ plugin services restart
```

### `gitea_lfs_jwt_secret`

LFS authentication secret. This value is randomly generated at install time.
([Gitea reference](https://docs.gitea.io/en-us/config-cheat-sheet/#server-server))

- default: **generated on install**

To change this value, use the installed `plugin` program and restart the
services to apply the updated configuration:

```console
$ plugin config set gitea_lfs_jwt_secret \
  "`gitea generate secret LFS_JWT_SECRET`"
$ plugin services restart
```

### `gitea_oauth2_jwt_secret`

OAuth2 authentication secret for access and refresh tokens. This value is
randomly generated at install time.
([Gitea reference](https://docs.gitea.io/en-us/config-cheat-sheet/#oauth2-oauth2))

- default: **generated on install**

To change this value, use the installed `plugin` program and restart the
services to apply the updated configuration:

```console
$ plugin config set gitea_oauth2_jwt_secret \
  "`gitea generate secret JWT_SECRET`"
$ plugin services restart
```

### `gitea_secret_key`

Global secret key. This value is randomly generated at install time.
([Gitea reference](https://docs.gitea.io/en-us/config-cheat-sheet/#security-security))

- default: **generated on install**

To change this value, use the installed `plugin` program and restart the
services to apply the updated configuration:

```console
$ plugin config set gitea_secret_key \
  "`gitea generate secret SECRET_KEY`"
$ plugin services restart
```

### System Configuration

The following configuration is used to configure and setup the services during
post installation and is therefore not intended to be changed or modified by a
plugin user.

### `gitea_domain`

Domain name of this server.
([Gitea reference](https://docs.gitea.io/en-us/config-cheat-sheet/#server-server))

- default: `"localhost"`

### `gitea_user_home`

Used to determine a parent path for storing all repository data.

- default: **\$HOME for gitea_user**

### `gitea_user`

The non-privileged user which runs the `gitea` service.

- default: `"git"`

### `gitea_work_dir`

Used to determine a parent path for storing all internal service state and
configuration.

- default: `"/var/db/gitea"`

## Code of Conduct

This project adheres to the Contributor Covenant [code of
conduct][code-of-conduct]. By participating, you are expected to uphold this
code. Please report unacceptable behavior to fnichol@nichol.ca.

## Issues

If you have any problems with or questions about this project, please contact us
through a [GitHub issue][issues].

## Contributing

You are invited to contribute to new features, fixes, or updates, large or
small; we are always thrilled to receive pull requests, and do our best to
process them as fast as we can.

Before you start to code, we recommend discussing your plans through a [GitHub
issue][issues], especially for more ambitious contributions. This gives other
contributors a chance to point you in the right direction, give you feedback on
your design, and help you find out if someone else is working on the same thing.

## Release History

This project uses a "deployable master" strategy, meaning that the `master`
branch is assumed to be working and production ready. As such there is no formal
versioning process and therefore also no formal changelog documentation.

## Authors

Created and maintained by [Fletcher Nichol][fnichol] (<fnichol@nichol.ca>).

## License

Licensed under the Mozilla Public License Version 2.0 ([LICENSE.txt][license]).

Unless you explicitly state otherwise, any contribution intentionally submitted
for inclusion in the work by you, as defined in the MPL-2.0 license, shall be
licensed as above, without any additional terms or conditions.

[badge-license]: https://img.shields.io/badge/License-MPL%202.0%20-blue.svg
[badge-ci-overall]:
  https://api.cirrus-ci.com/github/fnichol/iocage-plugin-gitea.svg
[ci]: https://cirrus-ci.com/github/fnichol/iocage-plugin-gitea
[code-of-conduct]:
  https://github.com/fnichol/iocage-plugin-gitea/blob/master/CODE_OF_CONDUCT.md
[fnichol]: https://github.com/fnichol
[issues]: https://github.com/fnichol/iocage-plugin-gitea/issues
[license]:
  https://github.com/fnichol/iocage-plugin-gitea/blob/master/LICENSE.txt
