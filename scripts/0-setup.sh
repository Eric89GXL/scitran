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
	unamestr=`uname`
	if [[ "$unamestr" == 'Linux' ]]; then
		platform='linux'
		cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
	elif [[ "$unamestr" == 'Darwin' ]]; then
		platform='mac'
		cores=4 # whelp
	fi
}

function EnsurePackages() {
	# Idempotently install apt packages
	bb-apt-install libatlas3gf-base liblapack3gf libgmp10 libmpfr4 python-pip python-virtualenv
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

	arch=`uname -m | sed 's/x86_//;s/i[3-6]86/32/'`
	if [ "$arch" != "64" ]; then
		echo "Only 64-bit architecture supported"
           exit 1;
	fi;
	release=`lsb_release -sr`
	url="https://lester.ilabs.uw.edu/files/wheelhouse/$release"
	if [ `curl -s --head $url | head -n 1 | grep -c "HTTP/1.[01] [23].."` != "1" ]; then
		echo "No pip packages found for distribution $release"
           exit 1;
	fi;

	pip install --upgrade pip wheel setuptools requests[security]
	pip install --no-index -f $url -r requirements_0_build_install.txt
	pip install --no-index -f $url -r requirements_1_build_install.txt
	pip install --no-index -f $url -r requirements_2_install.txt
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

		# Hackaround: travis started not having this package.
		# If source infra lands, this can go away in favor of travis apt config
		# Package requirement should be doc'd also.
		which uuidgen || sudo apt-get install -y uuid-runtime

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
