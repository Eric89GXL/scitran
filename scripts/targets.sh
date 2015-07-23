# User-level targets to run, notes from setup.sh apply.


# Idempotent environment
function Setup() {
	DetectPlatform

	# Install basic deps
	EnsurePip
	EnsureVirtualEnv
	EnsureMongoDb
	EnsureNginx
	EnsureGolang
	EnsureReflex

	# Scitran-specific environment, code, example dataset
	EnsurePipPackages
	EnsureConfig
	EnsureCode
	EnsureTestData

	# Scitran-specific stateful config
	EnsureClientCertificates
	EnsureBootstrapData
}

function Launch() {
	bb-log-info "Preparing environment"
	Setup

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

function CI() {
	Setup
	PylintAll server.py
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
