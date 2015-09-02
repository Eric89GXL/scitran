#!/bin/bash -ef

# Helper script to build wheels for a given Ubuntu x86_64 version (e.g.,
# 12.04 or 15.04)

# these are required to build the packages
#sudo apt-get install -y build-essential python-dev libatlas-dev \
#	libatlas-base-dev liblapack-dev gfortran libgmp-dev libmpfr-dev \
#	python-pip python-virtualenv libffi-dev

# set up the virtualenv in which to build and install libs
if [ ! -d "venv" ]; then
	virtualenv venv
	source venv/bin/activate
	pip install --upgrade pip wheel setuptools
fi

# these pip commands will create a "wheelhouse" directory in the current dir with
# all the requirements fulfilled
source venv/bin/activate
# Cython is not in any build_install.txt because it's only used for building
# wheels, and is not needed by any end application
#pip wheel --no-cache-dir -f wheelhouse cython==0.23
#pip install --upgrade --no-index -f wheelhouse cython==0.23
# Now cycle through our dependencies
reg='.*\([0-9][0-9]\)\(_build\)\?_install.txt'
for name in $( find ../requirements -regextype sed -regex $reg | sort ) ; do
	n=$( echo $name | sed "s|$reg|\1|" )
	build_name=../requirements/${n}_build_install.txt
	install_name=$build_name
	if [ ! -e $build_name ]; then
		build_name=../requirements/${n}_build.txt
		install_name=../requirements/${n}_install.txt
		if [ ! -e $build_name ]; then
			echo "No proper build file found for ${n}"
			exit 1
		fi
	fi
	pip wheel --no-cache-dir -f wheelhouse -r $build_name
	pip install --upgrade --no-index -f wheelhouse -r $install_name
done

# We need separate "_build.txt" and "_install.txt" files for some deps
# because they are built from git source. If we only used one file, then pip
# will *always* rebuilds and reinstall the packages. By building, checking
# the resulting version number, and installing that specific version number,
# we end up avoiding the recompile/reinstall for every check.
