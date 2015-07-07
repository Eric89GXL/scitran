#!/bin/bash -e

(
	# Set cwd
	unset CDPATH
	cd "$( dirname "${BASH_SOURCE[0]}" )"

	# You've got boost power
	BB_WORKSPACE="persistent/setup"
	BB_LOG_PREFIX="Flywheel"
	BB_LOG_FORMAT='${PREFIX}: ${MESSAGE}'
	source scripts/bashbooster.sh

	# Control flow
	source scripts/setup.sh
	source scripts/targets.sh

	# Run default or specific target
	if [ -z "$1" ] ; then
		Launch
	else
		case "$1" in

			# Prepare everything for launch, but don't run
			setup)
				Setup ;;

			# Run a command in the venv
			venv)
				shift
				LoadVenv
				"$@" ;;

			# Run an API python file, from its folder
			api)
				shift
				LoadVenv

				# This ain't uwsgi; chdir manually in this subshell
				cd code/api

				# Hackaround for API import problems
				export PYTHONPATH=../data

				"$@" ;;

			# Only regenerate templates
			template)
				EnsureConfig ;;

			# Run everything desired for CI
			ci)
				CI ;;

			# Create release tarball
			release)
				Release ;;

			# Update all code
			update)
				Update ;;

			# Create a drone certificate
			create-drone)
				shift
				CreateDrone $@ ;;

			# Print usage
			*)
				echo "Usage: $0 {setup|venv|template|ci|release|update|create-drone}" 1>&2;
				echo "Run without args to launch!" 1>&2;
				exit 1
			;;
		esac

	fi
)
