# Reflex config file
#	https://github.com/cespare/reflex#config-file


# If this file in the persistent directory, it is auto-generated.
# Edit the file in templates instead.

# Python server
# Trickery: actually just launch and never re-launch; send signals instead with next rule!
# Uses reflex as an utterly simple daemon manager for development simplicity.
--start-service --regex='.*\.invalidExtention$' -- uwsgi {{gDir}}/uwsgi.config.ini

# Mongo server
# Same thing here
--start-service --regex='.*\.invalidExtention2$' -- mongod --dbpath {{mongo.location}} --port 9001 --logpath {{lDir}}/mongo.log

# Gracefully reload uwsgi on file change
# Pidfile also used in uwsgi.config.ini
--regex='.*\.py$' -- bash -c "kill -HUP `cat {{pDir}}/uwsgi.pid`"
