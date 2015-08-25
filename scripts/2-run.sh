# Various launch actions.
# This file requires LoadConfig to have been called in a parent subshell.

# See 0-setup.sh for overall design notes.

#
# Run actions
#

function Reflex() {(
	LoadVenv

	# Hackaround for API import problems
	export PYTHONPATH=../data


	# Run when shutting down
	control_c() {
		# Complete unconditionally; wait will sometimes return 141
		set +e

		# Jump past emulator-visible "^C" text
		echo
		bb-log-info "Shutting down..."

		# Send SIGTERM to process manager; wait for clean shutdown
		kill $reflexPID
		wait $reflexPID

		bb-log-info "Stopped."
		exit 0
	}

	# trap keyboard interrupt (control-c)
	trap control_c SIGINT

	# Run reflex.
	#
	# Sed filter goes in a subshell to change the launch order of the two commands.
	# This allows reflex to launch last, and get reflex's PID on the next line with $!.
	# Capturing the PID allows us to guarantee cleanup in the control_c function.
	#
	# Sed statement does the following, in order:
	# 	Labels reflex's [00] prefix as Python
	# 	Labels reflex's [01] prefix as Mongo
	# 	Labels reflex's [02] prefix as Nginx
	# 	Removes useless message from python about loading config
	# 	Renames 'Starting service'
	# 	Renames 'Killing service'
	$reflexLoc --decoration=plain --config=${_folder_generated}/reflex.config.sh > >(sed 's/^\[00\]/Python:  /g; s/^\[01\]/Mongo:   /g; s/^\[02\]/Nginx:   /g; /\[uWSGI\] getting INI configuration from/d; s/Starting service$/Running/; s/Killing service$/Restarting.../; ') &


	# Block here until Ctrl-C
	reflexPID=$!
	wait $reflexPID
)}

# This duration needs to be long enough to run and cleanly shut down all infra.
# Hackaround for a sleep-try-loop that waits for mongo to be up.
waitSeconds="5"

# Start reflex and get its PID
# Not in a subshell so you can use $reflexPID
function StartReflex() {
	LoadVenv

	# Hackaround for API import problems
	export PYTHONPATH=../data

	# Supress reflex output decoration and uwsgi's launch message
	# Launch reflex in the background. Omits the grep to get PID easily -.-
	$reflexLoc --decoration=plain --config=${_folder_generated}/reflex.config.sh &
	reflexPID=$!
	bb-log-info "Reflex launched with $reflexPID"

	# Hope that infra is online
	bb-log-info "Waiting for infrastructure to be ready for bootstrap..."
	sleep $waitSeconds
}

function StopReflex() {
	bb-log-info "Reflex stopping with $reflexPID"
	kill -INT $reflexPID
	sleep $waitSeconds
}

# Takes bootstrap file location as param, relative to code/api folder.
function BootStrapUsers() {(
	bb-log-info "Loading initial users..."

	# This ain't uwsgi; chdir manually in this subshell
	cd code/api

	# Run
	set +e

	# Load user(s)
	./bootstrap.py dbinit -j $1 "mongodb://${_mongo_uri}"
	result=$?

	# Shut down reflex, if bootstrapping failed exit.
	if [ $result -ne 0 ]; then
		bb-log-info "Bootstrapping users failed. Cleaning up..."
		StopReflex
		exit $result;
	fi
)}

function BootStrapData() {(
	# HACKAROUND: 'bootstrap sort' will *DELETE* data... make a copy :(
	bb-log-info "Making of copy of the example dataset..."
	temp="$( bb-tmp-dir )"
	cp -r ${_folder_testdata}/* $temp

	bb-log-info "Loading example dataset..."

	# This ain't uwsgi; chdir manually in this subshell
	cd code/api

	# Run
	set +e

	# Load data
	# TODO: change to uri
	./bootstrap.py sort -q mongodb://localhost:${_mongo_port}/scitran $temp ../../persistent/data
	result=$?

	rm -rf $temp

	if [ $result -ne 0 ]; then
		bb-log-info "Bootstrapping data failed. Cleaning up..."
		StopReflex
		exit $result;
	fi
)}

# Add some initial db state if none exists.
# Should be used before mongo has ever been launched (via Reflex() or otherwise)
# Hackaround: duplicates Reflex()
# Hackaround: should be composable, and a run target of live.sh even if database already exists?
function EnsureBootstrapData() {(

	# Test if mongo has ever been launched before
	test -f persistent/mongo/mongod.lock || (
		bb-log-info "Preparing infrastructre for bootstrap..."
		StartReflex

		BootStrapUsers ../../${_folder_templates}/bootstrap.json
		BootStrapData

		bb-log-info "Finishing bootstrap..."
		StopReflex
	)
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
	pylint --disable=C,W0312 scripts/*.py
)}

function PylintAll() {(
	LoadVenv

	# This variant is intended to be run on developer checkin or as CI target.
	pylint scripts/*.py
)}
