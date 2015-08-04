#! /bin/bash -e

#
# Box boot
#

# Mongo does not like trying to memory-map files across operating systems.
# Place the persistent folder on the vagrant host.
persistentDir="/scitran/persistent"
mongoDir="/scitran/persistent/mongo"
mongoVDir="/scitran-mongo"

#If directory is either not present or not a symlink
if [ ! -L $mongoDir ]; then

  #Blow away what's there
  rm -rf $mongoDir 2>1 > /dev/null || rmdir $mongoDir

  # Place mongo data inside the vagrant (outside the mount)
  mkdir -p $persistentDir
  mkdir -p $mongoVDir
  ln -s $mongoVDir $mongoDir
fi

# Bootstrap
/scitran/live.sh setup

# Hackaround: stolen from EnsureNginx. See there for reasoning :(
sudo mkdir -p /var/log/nginx/
sudo chmod 777 /var/log/nginx/

# And yet more
sudo chown -R vagrant $mongoVDir
sudo chown -R vagrant /var/log/nginx/
