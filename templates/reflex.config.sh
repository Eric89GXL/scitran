# Reflex config file
#	https://github.com/cespare/reflex#config-file


# This file is auto-generated.
# Be sure you are editing the copy in templates/.

# Some service actually just launch and never re-launch.
# Uses reflex as an utterly simple daemon manager for development simplicity.

# Python server
--start-service --regex='.*\.py$' --inverse-regex="persistent/.*" -- uwsgi {{folder.generated}}/uwsgi.config.ini

# Mongo server
--start-service --glob="does-not-exist" --inverse-regex=".*" -- mongod --config {{folder.generated}}/mongo.config.yaml

# Nginx server
--start-service --glob="does-not-exist" --inverse-regex=".*" -- nginx -p {{absPath}} -c {{folder.generated}}/nginx/nginx.conf

# Gracefully reload uwsgi on file change
# Pidfile also used in uwsgi.config.ini
# --regex='.*\.py$' --inverse-regex="persistent/.*" -- bash -c "kill -HUP `cat {{folder.pids}}/uwsgi.pid`"
