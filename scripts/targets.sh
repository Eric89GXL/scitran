# User-level targets to run, notes from setup.sh apply.


# Idempotent environment
function Setup() {
	DetectPlatform

	# Install basic deps
	EnsurePip
	EnsureVirtualEnv
	EnsureMongoDb
	EnsureGolang
	EnsureReflex

	# Scitran-specific environment, config
	EnsurePipPackages
	EnsureConfig
	EnsureCode
}

function Launch() {
	bb-log-info "Preparing environment"
	Setup

	# Pylint has many complaints ATM; reconcile as separate project
	# bb-log-info "Checking server code"
	# PylintCritical code/api/

	# Run
	bb-log-info "Launching"
	Reflex

	# Wait for exit
	bb-log-info "Stopped."
}

function CI() {
	Setup
	PylintAll server.py
}
