# User-level targets to run, aggregating a loose dep tree

# TODO: review and possibly use http://www.bashbooster.net/#task


# Install basic deps and load config.
# Likely required by all other targets.
function Setup() {
	DetectPlatform

	EnsurePipPackages
	EnsureConfig

	DeriveLocations
}

# Install prequisites
function Install() {
	EnsureNginx
	EnsureScons
	EnsureMongoDb
	EnsureGolang
	EnsureReflex
}

# Scitran-specific environment, code, example dataset
# Will temporarily launch platform for bootstrapping purposes
function Configure() {
	EnsureTemplates
	EnsureCode
	EnsureTestData

	# Scitran-specific stateful setup
	EnsureClientCertificates
	EnsureBootstrapData
}

# Default: run the platform
function Launch() {
	bb-log-info "Preparing environment"
	Setup
	Install
	Configure

	# Pylint has many complaints ATM; reconcile as separate project
	# bb-log-info "Checking server code"
	# PylintCritical code/api/

	# Run
	# Hackaround: control-C doesn't show reflex cleanup ops.
	# Should instead use a sigtrap, kill -INT, pid-wait.
	bb-log-info "Launching"
	Reflex

	# Wait for exit
	bb-log-info "Stopped."
}

# Print the shared secret
function PrintSecret() {
	Setup
	echo ${_auth_shared_secret}
}

# What should our CI target run?
function CI() {
	DetectPlatform
	Prepare
	Setup
	Install
	Configure
}

function Release() {
	DetectPlatform

	# Remove old tar
	rm -f release.tar

	# Whitelist files to ship (AKA, don't put random certs + config in dist)
	bb-log-info "Preparing list of files to ship..."
	files=(`git ls-files`)
	files+=("code")

	bb-log-info "Creating release tarball..."
	# Don't create a tarbomb
	if [[ $platform == 'linux' ]]; then
		tar --transform 's,^,scitran/,rSh' -cf release.tar ${files[@]}
	elif [[ $platform == 'mac' ]]; then
		tar -s ',^,scitran/,' -cf release.tar ${files[@]}
	fi
}

function Update() {
	find . -type d -name .git -exec git -C "{}/.." pull \;
}
