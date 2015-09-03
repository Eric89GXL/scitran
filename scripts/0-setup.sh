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
	arch='unknown'
	release='unknown'
	unamestr=`uname`
	if [[ "$unamestr" == 'Linux' ]]; then
		platform='linux'
		cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
		arch=$( uname -m | sed 's/x86_//;s/i[3-6]86/32/' )
		# some old versions of ubuntu (e.g., 12.04) don't have this file
		if [ -e /etc/os-release ]; then
			release=$( cat /etc/os-release | grep VERSION_ID | cut -f 2 -d '"' )
		else
			release=$( lsb_release -sr )
		fi;
	elif [[ "$unamestr" == 'Darwin' ]]; then
		platform='mac'
		cores=4 # whelp
	fi
}

function EnsurePackages() {
	# Idempotently install apt packages
	bb-apt-install libatlas3gf-base liblapack3gf libgmp10 libmpfr4 python-pip python-virtualenv uuid-runtime ca-certificates
}

function LoadVenv() {
	# Ensure .pyc files are generated
	unset PYTHONDONTWRITEBYTECODE

	# Not in a subshell for obvious reasons
	source persistent/venv/bin/activate
}

function EnsurePipPackages() {(
	# Ensure venv, and clear pkgs flag if no venv
	test -d persistent/venv || (
		bb-flag-unset $flagName

		virtualenv persistent/venv
		bb-log-info "Created python virtual environment"
	)

	# Install packages
	#
	# NOTE: DO NOT USE UNMODIFIED `pip freeze` TO GENERATE THIS FILE.
	# Pip will happily save instructions it has no idea how to proccess.
	# Specifically, you should ignore lines from manually-installed (git) packages.
	LoadVenv
	DetectPlatform

	if [ "$arch" != "64" ]; then
		bb-log-error "Only 64-bit architecture supported"
		exit 1;
	fi;
	url="https://lester.ilabs.uw.edu/files/wheelhouse/$release"
	if [ -z "$release" ] || [ $( curl -s --head $url | head -n 1 | grep -c "HTTP/1.[01] [23].." ) != "1" ]; then
		bb-log-error "No pip packages found for distribution '$release'"
		exit 1;
	fi;

	bb-log-info "Checking Python packages at ${url}"
	ignore="^(Requirement already up-to-date|Requirement already satisfied|Ignoring indexes)"

	pip install --upgrade pip wheel setuptools | (grep -Ev "$ignore" || true)
	for f in requirements/*_install.txt; do
		pip install --no-index -f $url -r $f | (grep -Ev "$ignore" || true)
	done
)}

# For loading all project configuration into bash variables.
# Requires that config.toml exist.
function LoadConfig() {
	# Not in a subshell for obvious reasons
	LoadVenv
	eval `scripts/load_env.py config.toml`
}

# Implies LoadConfig and LoadVenv
function EnsureConfig() {

	test -f config.toml || (

		# Generate a shared secret
		secret=`uuidgen --random /dev/random | sed 's/-//g'`

		# Set shared secret while copying template
		cat templates/config.toml | sed 's/"change-me"/"'$secret'"/g' > config.toml

		bb-log-info "Generated default config file"
	)

	# Not in a subshell so that subsequent scripting can use config variables
	LoadConfig

	# Check config version
	scripts/check_version.py config.toml
}
