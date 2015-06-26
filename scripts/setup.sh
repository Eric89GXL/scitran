
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

	if [[ $platform == 'linux' ]]; then
		bb-apt-install python-virtualenv
	elif [[ $platform == 'mac' ]]; then
		pip install virtualenv
	fi

	bb-log-info "Virtualenv installed"
	bb-flag-set venv
)}

function LoadVenv() {
	# Not in a subshell for obvious reasons
	source $venv/bin/activate

	# Ensure .pyc files are generated
	unset PYTHONDONTWRITEBYTECODE
}

# TODO: probably requires some apt packages
# build-essential python-dev
function EnsurePipPackages() {(

	# OSX does not ship with hashers >:|
	if [[ $platform == 'mac' ]]; then
		bb-log-error "Todo: script homebrew"
		brew install coreutils
	fi

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

function EnsureConfig() {
	test -f config.toml || (
		cp $tDir/config.toml config.toml
		bb-log-info "Generated default config file"
	)

	# Not in a subshell for obvious reasons
	LoadVenv
	eval `scripts/load-env.py config.toml`

	# Generate configured templates
	scripts/template.py config.toml ${tDir}/web-config.js    > ${gDir}/web-config.js
	scripts/template.py config.toml ${tDir}/reflex.config.sh > ${gDir}/reflex.config.sh
	scripts/template.py config.toml ${tDir}/uwsgi.config.ini > ${gDir}/uwsgi.config.ini

	# Mongo data directory is configurable; use the location we just discovered
	mkdir -p $lDir $dDir $pDir $gDir $mDir ${_mongo_location}
}


function EnsureGolang() {(
	set +e
	bb-flag? golang-$golangVer && return
	set -e

	tarF="golang.tar.gz"
	temp="$( bb-tmp-dir )"

	if [[ $platform == 'linux' ]]; then
		snip="linux-amd64"
	elif [[ $platform == 'mac' ]]; then
		snip="darwin-amd64-osx10.8"
	fi

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
	set +e
	bb-flag? mongodb && return
	set -e

	if [[ $platform == 'linux' ]]; then
		bb-apt-install mongodb
	elif [[ $platform == 'mac' ]]; then
		bb-log-error "Todo: script homebrew"
		brew update
		brew install mongodb
	fi

	bb-flag-set mongodb
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
