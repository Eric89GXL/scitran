#!/bin/bash -e

(
	# Set cwd
	unset CDPATH
	cd "$( dirname "${BASH_SOURCE[0]}" )"

	# You've got boost power
	BB_WORKSPACE="$HOME/.flywheel"
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
			venv)
				# Run a command in the venv
				LoadVenv
				shift
				"$@" ;;
			ci)
				CI ;;
			template)
				EnsureConfig ;;
			*)
				echo "Usage: $0 {ci|template}" 1>&2;
				exit 1
			;;
		esac

	fi
)
