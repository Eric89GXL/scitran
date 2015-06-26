# User-level targets to run, notes from setup.sh apply.


# Idempotent environment
function Setup() {
	DetectPlatform

	EnsurePip
	EnsureVirtualEnv
	EnsurePipPackages
	EnsureConfig
	echo ${_mongo_location}

	exit
	EnsureMongoDb
	EnsureGolang
	EnsureReflex
	GenerateTemplates
}

function Launch() {
	Setup
	exit

	bb-log-info "Checking server code"
	PylintCritical server.py

	# Run
	Reflex

	# Wait for exit
	bb-log-info "Stopped."
}

function CI() {
	Setup
	PylintAll server.py
}
