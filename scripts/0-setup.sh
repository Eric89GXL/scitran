# Initial setup for loading configuration.
# This file does not use any config.toml keys

# Notes for modifying these files:
#
# 1) Control flow with exit codes (bb-flag, etc) MUST set +e.
# 2) Run all idempotency-providing functions in a subshell to prevent contamination.
# 3) This file should take no action; only export functions that can be unconditionally called.
# 4) There is *exactly* one stateful file/folder outside of 'persistent', and that is 'config.toml'.


# OSX flag difference #23479:
#
# Conflict in bash-booster regarding declare syntax. Appears to be inconsequential
# | grep -v -E "(declare\: -A\: invalid option$|^declare\: usage\: declare|date\: illegal option|usage\: date |\[-f fmt date )"

# Detect operating system
function DetectPlatform() {
	platform='unknown'
	cores=4

	unamestr=`uname`
	if [[ "$unamestr" == 'Linux' ]]; then
		platform='linux'
		cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
	elif [[ "$unamestr" == 'Darwin' ]]; then
		platform='mac'
		cores=4 # whelp
	fi
}

# Automate the sudo parts for your automating pleasure
function Prepare() {(
	if [[ $platform == "linux" ]]; then
		bb-log-info "Preparing linux system"

		# Ensure .pyc files are generated
		unset PYTHONDONTWRITEBYTECODE

		sudo apt-get install -y build-essential python-dev python-virtualenv

		# Download pip bootstrapper
		tempF="$( bb-tmp-file )"
		curl https://bootstrap.pypa.io/get-pip.py > $tempF

		# Install then upgrade pip
		sudo python $tempF
		sudo pip install --upgrade pip

	else
		bb-log-info "Skipping preparation as no instructions for your platform"
	fi
)}


function LoadVenv() {
	# Ensure .pyc files are generated
	unset PYTHONDONTWRITEBYTECODE

	# Not in a subshell for obvious reasons
	source persistent/venv/bin/activate
}

function EnsurePipPackages() {(

	# Pip install takes time to run, let's circumvent if up to date
	reqHash=`cat requirements.txt requirements-manual.txt | sha1sum requirements.txt | cut -c -7`
	flagName="pip-pkgs-$reqHash"

	# Ensure venv, and clear pkgs flag if no venv
	test -d persistent/venv || (
		bb-flag-unset $flagName

		virtualenv persistent/venv
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
		cp templates/config.toml config.toml
		bb-log-info "Generated default config file"
	)

	# Not in a subshell so that subsequent scripting can use config variables
	LoadConfig

	# Check config version
	scripts/check-version.py config.toml
}
