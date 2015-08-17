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
		echo "Usage: $0 {setup|configure|run|cmd|api|http|mongo|tail-python|template|ci|release|update|secret|reset-db}" 1>&2;
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

			# Run a command in the venv with config variables loaded
			# Examples:
			#	./live.sh cmd pip freeze
			#	./live.sh cmd 'echo ${_mongo_uri}'
			cmd)
				shift

				# Workaround for bash special variables being irate
				cmd="$@"

				# Load  config in subshell
				LoadVenv
				bash -c 'eval `scripts/load-env.py config.toml`; '"$cmd";;

			# Run an API python file, from its folder
			# Example:
			#	./live.sh api ./bootstrap.py
			api)
				shift
				cmd="$@"

				# Run command from correct directory and with workaround for API import problems
				cmd="cd code/api; export PYTHONPATH=../data; $cmd"

				./live.sh cmd $cmd;;

			# Make an API call with shared-secret authentication
			# Examples:
			# 	./live.sh http api/jobs/count
			# 	./live.sh http POST api/users _id=test@example.com firstname=Example lastname=User
			http)
				shift
				cmd="$@"

				# Handle host, port, and URL prefix
				cmd=`echo $cmd | sed 's%api%https://${_site_domain}:${_ports_web}/api%'`

				# Add headers to auth with shared secret
				cmd='http --verify=no '$cmd' "User-Agent:SciTran Drone Script" "X-SciTran-Auth:${_auth_shared_secret}"'

				./live.sh cmd $cmd;;

			# Connect to the mongo shell, or just run a mongo command.
			# Examples:
			# ./live.sh mongo
			# ./live.sh mongo show dbs
			# ./live.sh mongo 'db.users.count()'
			mongo)
				shift

				if [ "$#" -eq 0 ]; then
					./live.sh cmd mongo '${_mongo_uri}'
				else
					# Send command via stdin; suppress CLI spam.
					./live.sh cmd 'echo "'$@'" | mongo --quiet ${_mongo_uri}'
				fi
				;;

			# Follows the python logs.
			# Formats stack traces by removing long paths and highlighting scitran files.
			tail-python)
				tail -f -n 30 persistent/logs/uwsgi.log | sed --unbuffered 's$'`pwd`'$$g; s$/persistent/venv/local/lib/python2.7/site-packages/$$g;' | egrep --color '\"\..*\.py\"|api.wsgi|'
				;;

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
