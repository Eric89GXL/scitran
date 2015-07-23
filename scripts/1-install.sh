# Initial setup for loading configuration.
# This file requires LoadConfig to have been called in a parent subshell.

# See 0-setup.sh for overall design notes.

# Save calculated locations. Required for all later functions.
function DeriveLocations() {
	golangDir=$BB_WORKSPACE/golang/${_version_golang}
	reflexLoc=$BB_WORKSPACE/reflex
}

function EnsureGolang() {(
	set +e
	bb-flag? golang-${_version_golang} && return
	set -e

	tarF="golang.tar.gz"
	temp="$( bb-tmp-dir )"
	snip="linux-amd64"

	# bb-download appears to have strange quirks. How about no.
	wget https://storage.googleapis.com/golang/go${_version_golang}.${snip}.tar.gz --progress=dot:mega -O $temp/$tarF
	(
		cd $temp
		mkdir -p "$golangDir"
		tar xf $tarF --strip-components=1 -C $golangDir
	)

	GOROOT=$golangDir $golangDir/bin/go version
	bb-log-info Golang ${_version_golang} installed.
	bb-flag-set golang-${_version_golang}
)}

function EnsureMongoDb() {(

	set +e
	bb-flag? mongodb-${_version_mongo} && return
	set -e

	# http://docs.mongodb.org/v2.6/tutorial/install-mongodb-on-ubuntu
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
	echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list
	bb-log-info "Updating apt..."
	sudo apt-get update -qq
	sudo apt-get install -y mongodb-org=${_version_mongo} mongodb-org-server=${_version_mongo} mongodb-org-shell=${_version_mongo} mongodb-org-mongos=${_version_mongo} mongodb-org-tools=${_version_mongo}

	echo "mongodb-org hold"        | sudo dpkg --set-selections
	echo "mongodb-org-server hold" | sudo dpkg --set-selections
	echo "mongodb-org-shell hold"  | sudo dpkg --set-selections
	echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
	echo "mongodb-org-tools hold"  | sudo dpkg --set-selections

	# Potential removal instructions:
	# sudo apt-get purge mongodb mongodb-clients mongodb-dev mongodb-server
	# sudo rm -rf /var/log/mongodb /var/lib/mongodb

	mongod --version | head -n 1
	bb-log-info Mongo ${_version_mongo} installed.
	bb-flag-set mongodb-${_version_mongo}
)}

function EnsureNginx() {(
	set +e
	bb-flag? nginx && return
	set -e

	if bb-apt-package? nginx; then
		previouslyInstalled=true
	fi

	sudo add-apt-repository -y ppa:nginx/stable
	bb-log-info "Updating apt..."
	sudo apt-get update -qq
	sudo apt-get install -y ca-certificates
	sudo apt-get install -y nginx

	# Hackaround for nginx config not listening to my demand that it not use /var/log/nginx.
	# A zero-byte error log is generated there, completely ignoring configuration.
	# It looks like nginx is hard coded to assume it's launched with root.
	sudo mkdir -p /var/log/nginx/
	sudo chmod 777 /var/log/nginx/

	# Stop nginx service if it was not previously installed
	if [ -z $previouslyInstalled ] ; then
		# Opportunistically stop service; ignore failures
		if which service > /dev/null; then
			sudo service nginx stop || true
		fi
	fi

	nginx -v
	bb-log-info Nginx installed.
	bb-flag-set nginx
)}

function EnsureReflex() {(
	set +e
	bb-flag? reflex && return
	set -e

	temp="$( bb-tmp-dir )"

	GOROOT=$golangDir GOPATH=$temp PATH=$golangDir/bin:$PATH go get -v github.com/cespare/reflex
	mv $temp/bin/reflex $reflexLoc

	$reflexLoc -h 2>&1 | head -n 1
	bb-log-info "Reflex installed"
	bb-flag-set reflex
)}


#
# Environment Config
#
function EnsureTemplates() {(
	# Use the locations we just discovered
	mkdir -p ${_folder_logs} ${_folder_pids} ${_folder_generated} ${_folder_mongo} ${_folder_data}

	# Generate configured templates
	scripts/template.py config.toml ${_folder_templates}/web-config.js yes > ${_folder_generated}/web-config.js
	scripts/template.py config.toml ${_folder_templates}/reflex.config.sh  > ${_folder_generated}/reflex.config.sh
	scripts/template.py config.toml ${_folder_templates}/mongo.config.yaml > ${_folder_generated}/mongo.config.yaml
	scripts/template.py config.toml ${_folder_templates}/uwsgi.config.ini  > ${_folder_generated}/uwsgi.config.ini

	# Nginx is a folder
	cp -r ${_folder_templates}/nginx ${_folder_generated}
	scripts/template.py config.toml ${_folder_templates}/nginx/nginx.conf  > ${_folder_generated}/nginx/nginx.conf
)}

function EnsureCode() {(
	# Folder, ref, URI
	function EnsureClone() {
		test -d $1 || git clone -b $2 $3 $1
	}

	EnsureClone code/api      master   https://github.com/scitran/api.git
	EnsureClone code/www      master   https://github.com/scitran/sdm.git
	EnsureClone code/data     master   https://github.com/scitran/data.git
	EnsureClone code/apps     master   https://github.com/scitran/apps.git
	EnsureClone code/www      master   https://github.com/scitran/sdm.git

	# EnsureClone code/engine   stopgapp https://github.com/scitran/engine.git

	# Web app demands web-config.js
	mkdir -p code/www/app
	cp ${_folder_generated}/web-config.js code/www/app/
)}

function EnsureTestData() {(
	test -d ${_folder_testdata} || (
		temp="$( bb-tmp-file )"

		wget https://github.com/scitran/testdata/archive/master.tar.gz -O $temp

		tar -xvf $temp -C ${_folder_state}/
		mv ${_folder_state}/testdata-master ${_folder_testdata}
		rm -f $temp
	)
)}

function EnsureClientCertificates() {(
	mkdir -p ${_folder_keys}

	# Ensure server cert for SSL
	test -f ${_keys_combined} || (
		# Generate individual files
		openssl req -x509 -newkey rsa:2048 -subj "/C=US/ST=example/L=example/O=example/CN=example" -keyout ${_keys_key} -out ${_keys_cert} -days 999 -nodes

		# Combine for nginx
		cat ${_keys_key} ${_keys_cert} > ${_keys_combined}

		bb-log-info "Generated server certificate"
	)
)}
