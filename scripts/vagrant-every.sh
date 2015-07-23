#! /bin/bash -e

#
# Box boot
#

# Mongo does not like trying to memory-map files across operating systems.
# Place the persistent folder on the vagrant host.
mongoDir="/scitran/persistent/mongo"
mongoVDir="/scitran-mongo"

mkdir -p `dirname $mongoDir`

# This will intentionally fail if mongo is dir is non-empty.
# If you already have mongo data from running on the host, copy it in manually.
rm -f $mongoDir 2>1 > /dev/null || rmdir $mongoDir

# Place mongo data inside the vagrant (outside the mount)
mkdir -p $mongoVDir
ln -s $mongoVDir $mongoDir

# Bootstrap
/scitran/live.sh setup

# And yet more
sudo chown -R vagrant $mongoVDir
sudo chown -R vagrant /var/log/nginx/
