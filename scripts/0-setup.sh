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

# Automate the sudo parts for your automating pleasure
function Prepare() {(
	DetectPlatform

	if [[ "$platform" == "linux" ]]; then
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
	# Ensure venv, and clear pkgs flag if no venv
	test -d persistent/venv || (
		bb-flag-unset $flagName

		virtualenv persistent/venv

		# Always have the latest tools (in the venv).
		LoadVenv
		pip install --upgrade pip wheel setuptools | (grep -Ev "$ignore" || true)

		bb-log-info "Created python virtual environment"
	)

	# Install packages
	#
	# NOTE: DO NOT USE UNMODIFIED `pip freeze` TO GENERATE THIS FILE.
	# Pip will happily save instructions it has no idea how to proccess.
	# Specifically, you should ignore lines from manually-installed (git) packages.
	LoadVenv
	DetectPlatform

	# Squelch pip annoyances without using quiet flag.
	ignore="^(Requirement already up-to-date|Requirement already satisfied|Ignoring indexes)"

	baseURL="https://storage.googleapis.com/flywheel/wheels"
	url="$baseURL/$platform-$arch/$release"

	# Basic packages from index. No compilation.
	for f in requirements/*basic*.txt; do
		pip install -r $f | (grep -Ev "$ignore" || true)
	done

	# Install wheels if they exist for this platform + release.
	temp="$( bb-tmp-dir )"

	# Google storage buckets are not pip-simple compliant.
	# https://pip.readthedocs.org/en/stable/reference/pip_install/#finding-packages
	# https://pythonhosted.org/setuptools/easy_install.html#package-index-api
	# https://www.python.org/dev/peps/pep-0301/
	#
	# Hackaround until we host somewhere more reasonable.
	# Then, replace this manual list with a loop using '-f $url -r $f'
	pip install $url/mne-0.9.0-py2-none-any.whl              | (grep -Ev "$ignore" || true)
	pip install $url/numpy-1.9.2-cp27-none-linux_x86_64.whl  | (grep -Ev "$ignore" || true)
	pip install $url/scipy-0.16.0-cp27-none-linux_x86_64.whl | (grep -Ev "$ignore" || true)

	# Install manually if wheels failed.
	for f in requirements/*wheels*.txt; do
		pip install -r $f | (grep -Ev "$ignore" || true)
	done

	# Install github source packages
	for f in requirements/*source*.txt; do
		pip install -r $f | (grep -Ev "$ignore" || true)
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
