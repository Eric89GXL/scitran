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
	source scripts/0-setup.sh
	source scripts/1-install.sh
	source scripts/2-run.sh
	source scripts/3-targets.sh

	function Usage() {
		echo "Usage: $0 {setup|run|venv|api|template|ci|release|update|secret|reset-db}" 1>&2;
		exit 1
	}

	# Choose target
	if [ -z "$1" ] ; then
		Usage
	else
		case "$1" in

			# Prepare everything for launch, but don't run
			setup)
				SetupTarget ;;

			configure)
				ConfigureTarget ;;

			run)
				RunTarget ;;

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
				CiTarget ;;

			# Create release tarball
			release)
				Release ;;

			# Update all code
			update)
				Update ;;

			secret)
				PrintSecret ;;

			reset-db)
				rm -rf persistent/mongo/*
				Setup
				Install
				Configure ;;

			# Print usage
			*)
				Usage ;;
		esac

	fi
)
