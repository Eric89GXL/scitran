
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

function EnsurePip() {(
	set +e
	bb-flag? pip && return
	set -e

	# Ensure .pyc files are generated
	unset PYTHONDONTWRITEBYTECODE

	curl https://bootstrap.pypa.io/get-pip.py | python
	pip install --upgrade pip

	bb-log-info "Python installed"
	bb-flag-set pip
)}

function EnsureVirtualEnv() {(
	set +e
	bb-flag? venv && return
	set -e

	bb-apt-install python-virtualenv

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
	mongoVersion="2.6.9"

	set +e
	bb-flag? mongodb-${mongoVersion} && return
	set -e

	# http://docs.mongodb.org/v2.6/tutorial/install-mongodb-on-ubuntu
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
	echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list
	sudo apt-get update
	sudo apt-get install -y mongodb-org=${mongoVersion} mongodb-org-server=${mongoVersion} mongodb-org-shell=${mongoVersion} mongodb-org-mongos=${mongoVersion} mongodb-org-tools=${mongoVersion}

	echo "mongodb-org hold"        | sudo dpkg --set-selections
	echo "mongodb-org-server hold" | sudo dpkg --set-selections
	echo "mongodb-org-shell hold"  | sudo dpkg --set-selections
	echo "mongodb-org-mongos hold" | sudo dpkg --set-selections
	echo "mongodb-org-tools hold"  | sudo dpkg --set-selections

	# Potential removal instructions:
	# sudo apt-get purge mongodb mongodb-clients mongodb-dev mongodb-server
	# sudo rm -rf /var/log/mongodb /var/lib/mongodb

	bb-flag-set mongodb-${mongoVersion}
)}

function EnsureReflex() {(
	set +e
	bb-flag? reflex && return
	set -e

	temp="$( bb-tmp-dir )"

	GOROOT=$golangDir GOPATH=$temp go get -v github.com/cespare/reflex
	mv $temp/bin/reflex $reflexLoc

	reflex -h 2>&1 | head -n 1
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

# TODO: probably requires some apt packages
# build-essential python-dev
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

function EnsureConfig() {
	test -f config.toml || (
		cp $tDir/config.toml config.toml
		bb-log-info "Generated default config file"
	)

	# Not in a subshell so that subsequent scripting can use config variables
	LoadConfig

	# Mongo data directory is configurable; use the location we just discovered
	mkdir -p $lDir $dDir $pDir $gDir $mDir ${_mongo_location}

	# Generate configured templates
	scripts/template.py config.toml ${tDir}/web-config.js     > ${gDir}/web-config.js
	scripts/template.py config.toml ${tDir}/reflex.config.sh  > ${gDir}/reflex.config.sh
	scripts/template.py config.toml ${tDir}/mongo.config.yaml > ${gDir}/mongo.config.yaml
	scripts/template.py config.toml ${tDir}/uwsgi.config.ini  > ${gDir}/uwsgi.config.ini
}

function EnsureCode() {
	# Folder, ref, URI
	function EnsureClone() {
		test -d $1 || git clone -b $2 $3 $1
	}

	EnsureClone code/api      master   https://github.com/scitran/api.git
	EnsureClone code/www      master   https://github.com/scitran/sdm.git

	# EnsureClone code/data     master   https://github.com/scitran/data.git
	# EnsureClone code/apps     master   https://github.com/scitran/apps.git
	# EnsureClone code/testdata master   https://github.com/scitran/testdata.git
	# EnsureClone code/engine   stopgapp https://github.com/scitran/engine.git
}


#
# Run actions
#

function Reflex() {(
	# Quiets mongo complaining
	rm -f ${lDir}/mongo.log

	LoadVenv
	$reflexLoc --decoration=none --config=$gDir/reflex.config.sh
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
