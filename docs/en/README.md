# English documentation

## How to use

- Install Debian.
- Optionally install [OMV](https://www.openmediavault.org/).
- Setup router.
- Setup DNS.
- Install Docker.
- Copy docker-compose configuration.
- Configure and run services.
- Setup front-end.


### Installing Debian

You can use fully-encrypted drive under ZFS volume or using ZFS encryption over physical volume.
The first variant is more secure.
See [Debian Installation Manual](https://www.debian.org/releases/stable/installmanual) for the details.


### Installing OMV

You must to add [OMV package repository](https://packages.openmediavault.org/public/) to the `/etc/apt/source.list.d/`.
Then make `sudo apt-get update && sudo apt-get install openmediavault`.
See [OMV documentation](https://openmediavault.readthedocs.io/en/5.x/installation/on_debian.html) for the details.


### Setup router

Buy constant IP and create NAT, using port 443.


### Setup DNS


### Install Docker

### Copy docker-compose configuration

### Configure and run services

### Setup front-end

Setup Organizr pages.
