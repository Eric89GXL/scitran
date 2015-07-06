
# Notes for modifying this file:
#
# 1) Control flow with exit codes (bb-flag, etc) MUST set +e.
# 2) Run all idempotency-providing functions in a subshell to prevent contamination.
# 3) This file should take no action; only export functions that can be unconditionally called.
# 4) There is *exactly* one stateful file/folder outside of stateDir, and that is config.toml.


# OSX flag difference #23479:
#
# Conflict in bash-booster regarding declare syntax. Appears to be inconsequential
# | grep -v -E "(declare\: -A\: invalid option$|^declare\: usage\: declare|date\: illegal option|usage\: date |\[-f fmt date )"


# Detect operating system
function DetectPlatform() {
	platform='unknown'
	unamestr=`uname`
	if [[ "$unamestr" == 'Linux' ]]; then
		platform='linux'
		cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
	elif [[ "$unamestr" == 'Darwin' ]]; then
		platform='mac'
		cores=4 # whelp
	fi
}

# Product versions
golangVer="1.4.2"

# Derived
golangDir=$BB_WORKSPACE/golang/$golangVer
reflexLoc=$BB_WORKSPACE/reflex

# Locations that are not configurable
tDir="templates"
stateDir="persistent"
gDir="$stateDir/generated"
lDir="$stateDir/logs"
pDir="$stateDir/pids"
venv="$stateDir/venv"

keyDir=$stateDir/keys
mkdir -p $keyDir

# Hackaround: really, there should be another toml template holding all these.
# load-env.py and template.py should unconditionally load them.
# Then LoadConfig / EnsureConfig would be trivially correct and DRY.

KEY_CERT_COMBINED_FILE=$keyDir/base-key+cert.pem
KEY_FILE=$keyDir/base-key.pem
CERT_FILE=$keyDir/base-cert.pem

ROOT_CERT_COMBINED_FILE=$keyDir/rootCA-key+cert.pem
ROOT_KEY_FILE=$keyDir/rootCA-key.pem
ROOT_CERT_FILE=$keyDir/rootCA-cert.pem
ROOT_SRL_FILE=$keyDir/rootCA-cert.srl

CA_CERTS_COMBINED_FILE=$keyDir/ca-certificates+scitranCA.crt

function EnsurePip() {(
	set +e
	bb-flag? pip && return
	set -e

	# Ensure .pyc files are generated
	unset PYTHONDONTWRITEBYTECODE

	# Download pip bootstrapper
	tempF="$( bb-tmp-file )"
	curl https://bootstrap.pypa.io/get-pip.py > $tempF

	# We need these for numpy, may as well place here.
	sudo apt-get install -y build-essential python-dev

	# Install then upgrade pip
	sudo python $tempF
	sudo pip install --upgrade pip

	bb-log-info "Pip installed"
	bb-flag-set pip
)}

function EnsureVirtualEnv() {(
	set +e
	bb-flag? venv && return
	set -e

	sudo apt-get install -y python-virtualenv

	bb-log-info "Virtualenv installed"
	bb-flag-set venv
)}

function EnsureGolang() {(
	set +e
	bb-flag? golang-$golangVer && return
	set -e

	tarF="golang.tar.gz"
	temp="$( bb-tmp-dir )"
	snip="linux-amd64"

	# bb-download appears to have strange quirks. How about no.
	wget https://storage.googleapis.com/golang/go$golangVer.${snip}.tar.gz --progress=dot:mega -O $temp/$tarF
	(
		cd $temp
		mkdir -p "$golangDir"
		tar xf $tarF --strip-components=1 -C $golangDir
	)

	GOROOT=$golangDir $golangDir/bin/go version
	bb-log-info Golang $golangVer installed.
	bb-flag-set golang-$golangVer
)}

function EnsureMongoDb() {(
	mongoVer="2.6.9"

	set +e
	bb-flag? mongodb-${mongoVer} && return
	set -e

	# http://docs.mongodb.org/v2.6/tutorial/install-mongodb-on-ubuntu
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
	echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list
	bb-log-info "Updating apt..."
	sudo apt-get update -qq
	sudo apt-get install -y mongodb-org=${mongoVer} mongodb-org-server=${mongoVer} mongodb-org-shell=${mongoVer} mongodb-org-mongos=${mongoVer} mongodb-org-tools=${mongoVer}

	echo "mongodb-org hold"        | sudo dpkg --set-selections
	echo "mongodb-org-server hold" | sudo dpkg --set-selections
	echo "mongodb-org-shell hold"  | sudo dpkg --set-selections
	echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
	echo "mongodb-org-tools hold"  | sudo dpkg --set-selections

	# Potential removal instructions:
	# sudo apt-get purge mongodb mongodb-clients mongodb-dev mongodb-server
	# sudo rm -rf /var/log/mongodb /var/lib/mongodb

	mongod --version | head -n 1
	bb-log-info Mongo $mongoVer installed.
	bb-flag-set mongodb-${mongoVer}
)}

function EnsureNginx() {(
	set +e
	bb-flag? nginx && return
	set -e

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

	nginx -v
	bb-log-info Nginx $nginxVer installed.
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


function LoadVenv() {
	# Not in a subshell for obvious reasons
	source $venv/bin/activate

	# Ensure .pyc files are generated
	unset PYTHONDONTWRITEBYTECODE
}

function EnsurePipPackages() {(

	# Pip takes time to run, let's circumvent if up to date
	reqHash=`cat requirements.txt requirements-manual.txt | sha1sum requirements.txt | cut -c -7`
	flagName="pip-pkgs-$reqHash"

	# Ensure venv, and clear pkgs flag if no venv
	test -d $venv || (
		bb-flag-unset $flagName

		virtualenv $venv
		bb-log-info "Created python virtual environment"
	)

	set +e
	bb-flag? $flagName && return
	set -e

	# Install packages
	#
	# NOTE: DO NOT USE UNMODIFIED `pip freeze` TO GENERATE THIS FILE.
	# Pip will happily save instructions it has no idea how to proccess.
	# Specifically, you should ignore lines from manually-installed (git) packages.
	LoadVenv
	pip install -r requirements.txt | grep -v "Requirement already satisfied"

	# Install manual packages.
	#
	#  Hackaround for pip's inability to install from its own r.txt file.
	#  Can later be moved into r.txt with correct flags + egg names.
	while read line; do
		echo "Installing $line"
		pip install $line
	done <requirements-manual.txt

	# Remember this set of packages
	bb-log-info "Pip packages installed"
	bb-flag-set $flagName
)}

# For loading all project configuration into bash variables.
# Requires that config.toml exist.
function LoadConfig() {
	# Not in a subshell for obvious reasons
	LoadVenv
	eval `scripts/load-env.py config.toml`
}

# Implies LoadConfig and LoadVenv
function EnsureConfig() {
	test -f config.toml || (
		cp $tDir/config.toml config.toml
		bb-log-info "Generated default config file"
	)

	# Not in a subshell so that subsequent scripting can use config variables
	LoadConfig

	# Check config version
	scripts/check-version.py config.toml

	# Some data directories is configurable; use the location we just discovered
	mkdir -p $lDir $pDir $gDir ${_mongo_location} ${_data_location}

	# Generate configured templates
	scripts/template.py config.toml ${tDir}/web-config.js     > ${gDir}/web-config.js
	scripts/template.py config.toml ${tDir}/reflex.config.sh  > ${gDir}/reflex.config.sh
	scripts/template.py config.toml ${tDir}/mongo.config.yaml > ${gDir}/mongo.config.yaml
	scripts/template.py config.toml ${tDir}/uwsgi.config.ini  > ${gDir}/uwsgi.config.ini

	# Nginx is a folder
	cp -r ${tDir}/nginx ${gDir}
	scripts/template.py config.toml ${tDir}/nginx/nginx.conf  > ${gDir}/nginx/nginx.conf
}

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

	# EnsureClone code/testdata master   https://github.com/scitran/testdata.git
	# EnsureClone code/engine   stopgapp https://github.com/scitran/engine.git

	# Web app demands web-config.js
	mkdir -p code/www/app
	cp ${gDir}/web-config.js code/www/app/
)}

function EnsureClientCertificates() {(
	# Ensure root CA ready
	test -f $ROOT_CERT_COMBINED_FILE || (
		# Create a root CA key
		openssl genrsa -out $ROOT_KEY_FILE 2048

		# Create a root CA cert
		openssl req -x509 -new -nodes -subj "/C=US/ST=example/L=example/O=example/CN=example" -key $ROOT_KEY_FILE -days 999 -out $ROOT_CERT_FILE

		# Combine for nginx
		cat $ROOT_KEY_FILE $ROOT_CERT_FILE > $ROOT_CERT_COMBINED_FILE

		bb-log-info "Generated CA certificate"
	)

	# Ensure server cert for SSL
	test -f $KEY_CERT_COMBINED_FILE || (
		# Generate individual files
		openssl req -x509 -newkey rsa:2048 -subj "/C=US/ST=example/L=example/O=example/CN=example" -keyout $KEY_FILE -out $CERT_FILE -days 999 -nodes

		# Combine for nginx
		cat $KEY_FILE $CERT_FILE > $KEY_CERT_COMBINED_FILE

		bb-log-info "Generated server certificate"
	)

	# Combine the ca-certificates bundle with out our trusted CA certificate
	# This is a hackaround for having to give nginx a single CA certs package for client cert auth.
	# Which is itself a hackaround for making nginx more compatible with various SSL client auth libraries (eg, golang).
	cat /etc/ssl/certs/ca-certificates.crt $ROOT_CERT_FILE > $CA_CERTS_COMBINED_FILE
)}

#
# Run actions
#

function Reflex() {(
	LoadVenv

	# Hackaround for API import problems
	export PYTHONPATH=../data

	# Supress reflex output decoration and uwsgi's launch message
	$reflexLoc --decoration=plain --config=$gDir/reflex.config.sh | grep -v "getting INI configuration from $gDir/uwsgi.config.ini"
)}

# Add some initial db state if none exists.
# Should be used before mongo has ever been launched (via Reflex() or otherwise)
# Hackaround: duplicates Reflex()
# Hackaround: should be composable, and a run target of live.sh even if database already exists?
function EnsureBootstrapData() {(

	# This duration needs to be long enough to run and cleanly shut down all infra.
	# Hackaround for a sleep-try-loop that waits for mongo to be up.
	waitSeconds="5"

	# Test if mongo has ever been launched before
	test -f persistent/mongo/mongod.lock || (
		bb-log-info "Preparing infrastructre for bootstrap..."

		LoadVenv

		# Hackaround for API import problems
		export PYTHONPATH=../data

		# Supress reflex output decoration and uwsgi's launch message
		# Launch reflex in the background. Omits the grep to get PID easily -.-
		$reflexLoc --decoration=plain --config=$gDir/reflex.config.sh > /dev/null &
		taskPID=$!
		bb-log-info "Reflex temporarily launched with $taskPID"

		# Hope that infra is online
		bb-log-info "Waiting for infrastructre to be ready for bootstrap..."
		sleep $waitSeconds

		# Bootstrap
		bb-log-info "Loading initial users..."
		(
			LoadVenv

			# Hackaround for API import problems
			export PYTHONPATH=../data

			# This ain't uwsgi; chdir manually in this subshell
			cd code/api

			# Run
			set +e
			./bootstrap.py dbinit -j ../../${tDir}/bootstrap.json "${_mongo_uri}"
			result=$?

			# If bootstrapping failed, still shut down infra
			if [ $result -ne 0 ]; then
			   bb-log-info "Bootstrapping failed. Cleaning up..."
			   kill -INT $taskPID
			   sleep $waitSeconds

			   exit $result;
			fi
		)

		# Shut down infra
		bb-log-info "Finishing bootstrap..."
		kill -INT $taskPID
		sleep $waitSeconds

		# Sanity check
		# ps aux | grep uwsgi | grep -v grep
		# ps aux | grep mongo | grep -v grep
	)
)}


# Pylint docs:
#
# http://pylint-messages.wikidot.com/all-codes
# http://pylint-messages.wikidot.com/all-messages

function PylintCritical() {(
	LoadVenv

	# There does not seem to be a great way to document pylint error whitelists.
	# Could at least move this to a pylintrc file in future.
	#
	# This variant is intended to be run on every change, and only stop critical problems.
	#
	# Disables:
	# C0111: Missing docstring
	# W    : All warnings
	# F0401: Unable to import package - possible problem with pylint usage?
	pylint -j 0 --reports n --disable=C0111,C,W0312,F0401 $@ 2> >(grep -v "No config file found, using default configuration")
)}

function PylintAll() {(
	LoadVenv

	# This variant is intended to be run on developer checkin or as CI target.
	#
	# Disables:
	# C0111: Missing docstring
	# F0401: Unable to import package - possible problem with pylint usage?
	pylint -j 0 --reports n --disable=C0111,F0401 $@ 2> >(grep -v "No config file found, using default configuration")
)}

function CreateDrone() {(
	drone_name=$1

	if [ -z "$drone_name" ] ; then
		bb-log-info "Name required to create drone certificate"
		exit 1
	fi

	drone_key=$keyDir/client-${drone_name}-key.pem
	drone_cert=$keyDir/client-${drone_name}-cert.pem
	drone_csr=$keyDir/client-${drone_name}.csr
	drone_combined=$keyDir/client-${drone_name}-key+cert.pem

	# Create a key for this drone
	openssl genrsa -out $drone_key 2048

	# Create a CSR from that key
	openssl req -new -subj "/C=US/ST=example/L=example/O=example/CN=example" -key $drone_key -out $drone_csr

	# Sign the CSR with root CA
	openssl x509 -req -in $drone_csr -CA $ROOT_CERT_FILE -CAkey $ROOT_KEY_FILE -CAcreateserial -out $drone_cert -days 999

	# Combine
	cat $drone_key $drone_cert > $drone_combined

	# Delete CSR
	rm -f $drone_csr

	bb-log-info "Generated client certificate for $drone_name in $keyDir"
)}
