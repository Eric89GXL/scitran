#! /bin/bash -e

#
# Box setup
#

# Speed up installs and don't create cache files
#	See: https://github.com/dotcloud/docker/pull/1883#issuecomment-24434115
echo "force-unsafe-io"                 > /etc/dpkg/dpkg.cfg.d/02apt-speedup
echo "Acquire::http {No-Cache=True;};" > /etc/apt/apt.conf.d/no-cache
chmod 0644 /etc/dpkg/dpkg.cfg.d/02apt-speedup
chmod 0644 /etc/apt/apt.conf.d/no-cache

# Configure mirror URL
mirror="http://mirrors.linode.com/ubuntu/"

# Get release codename ("saucy", "trusty", etc)
codename=`/usr/bin/lsb_release -cs`

# Apt-get sources:
#	Tell apt to use a nearby mirror. Can *dramatically* increase update speed.
#	Default Ubuntu sources generated via http://repogen.simplylinux.ch
cat > /etc/apt/sources.list <<EOF
###### Ubuntu Main Repos
deb $mirror $codename main restricted universe

###### Ubuntu Update Repos
deb $mirror $codename-security main restricted universe
deb $mirror $codename-updates main restricted universe
EOF
chmod 0644 /etc/apt/sources.list

# Set to non-interactive installs
export DEBIAN_FRONTEND=noninteractive

# Aggressively nuke apt cache
apt-get autoremove -y
apt-get clean -y
rm -rf /var/lib/apt/lists

# Ubuntu essentials
apt-get -y update
apt-get -y dist-upgrade

# Vagrant essentials
packages=()
packages+=(htop nano git screen unison curl wget p7zip-full) # Basics
packages+=(dstat makepasswd traceroute nmap) # Utilities
apt-get -y install "${packages[@]}"

# Kill SSH messages
rm -f /etc/update-motd.d/*
service ssh restart

# Mongo does not like trying to memory-map files across operating systems.
# Place the persistent folder on the vagrant host.
# WILL DESTROY ANY STORED DATA IN THIS INSTANCE.
rm -rf /scitran/persistent/mongo
mkdir -p /scitran-mongo
ln -s /scitran-mongo /scitran/persistent/mongo

# Start in /scitran
echo "cd /scitran" >> /home/vagrant/.bashrc

# Bootstrap
/scitran/live.sh setup
