# Reflex config file
#	https://github.com/cespare/reflex#config-file


# This file is auto-generated.
# Be sure you are editing the copy in templates/.

# Python server
# Trickery: actually just launch and never re-launch; send signals instead with next rule!
# Uses reflex as an utterly simple daemon manager for development simplicity.
--start-service --glob="does-not-exist" --inverse-regex=".*" -- uwsgi {{folder.generated}}/uwsgi.config.ini

# Mongo server
--start-service --glob="does-not-exist" --inverse-regex=".*" -- {{folder.bb}}/mongo/{{version.mongo}}/mongod --config {{folder.generated}}/mongo.config.yaml

# Nginx server
--start-service --glob="does-not-exist" --inverse-regex=".*" -- {{folder.bb}}/nginx/{{version.nginx}}/sbin/nginx -p {{absPath}} -c {{folder.generated}}/nginx/nginx.conf

# Gracefully reload uwsgi on file change
# Pidfile also used in uwsgi.config.ini
--regex='.*\.py$' --inverse-regex="persistent/.*" -- bash -c "kill -HUP `cat {{folder.pids}}/uwsgi.pid`"
