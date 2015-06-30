# Reflex config file
#	https://github.com/cespare/reflex#config-file


# This file is auto-generated.
# Be sure you are editing the copy in templates/.

# Python server
# Trickery: actually just launch and never re-launch; send signals instead with next rule!
# Uses reflex as an utterly simple daemon manager for development simplicity.
--start-service --glob="does-not-exist" --inverse-regex=".*" -- uwsgi {{gDir}}/uwsgi.config.ini

# Mongo server
# Same thing here
--start-service --glob="does-not-exist" --inverse-regex=".*" -- mongod --config {{gDir}}/mongo.config.yaml

# Gracefully reload uwsgi on file change
# Pidfile also used in uwsgi.config.ini
--regex='.*\.py$' --inverse-regex="persistent/.*" -- bash -c "kill -HUP `cat {{pDir}}/uwsgi.pid`"
