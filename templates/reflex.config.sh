# Reflex config file
#	https://github.com/cespare/reflex#config-file


# This file is auto-generated.
# Be sure you are editing the copy in templates/.

# Some services actually just launch and never re-launch.
# Uses reflex as an utterly simple daemon manager for development simplicity.

# Copy the inverse-regex from the python server line to any future 'real' commands to avoid lots of wasted watching.
# Inverse regex should ideally match all stateful dirs.

# Python server
--start-service --regex='^code/api/.*\.(py|wsgi)$' --inverse-regex="^(persistent/|code/www/node_modules/|\.vagrant/|code/apps/graph/).*" -- uwsgi {{folder.generated}}/uwsgi.config.ini

# Mongo server
--start-service --glob="does-not-exist" --inverse-regex=".*" -- mongod --config {{folder.generated}}/mongo.config.yaml

# Nginx server
--start-service --glob="does-not-exist" --inverse-regex=".*" -- nginx -p {{absPath}} -c {{folder.generated}}/nginx/nginx.conf
