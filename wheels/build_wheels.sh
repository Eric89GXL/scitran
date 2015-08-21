#!/bin/bash -ef

sudo apt-get install -y build-essential python-dev libatlas-dev libatlas-base-dev liblapack-dev gfortran libgmp-dev libmpfr-dev python-pip python-virtualenv libffi-dev

if [ ! -d "venv" ]; then
	virtualenv venv
	source venv/bin/activate
	pip install --upgrade pip wheel setuptools
fi

# this will create a "wheelhouse" directory in the current dir with
# all the requirements
source venv/bin/activate
pip wheel --no-cache-dir -f wheelhouse cython==0.23
pip install --upgrade --no-index -f wheelhouse cython==0.23
pip wheel --no-cache-dir -f wheelhouse -r ../requirements_0_build_install.txt
pip install --upgrade --no-index -f wheelhouse -r ../requirements_0_build_install.txt
pip wheel --no-cache-dir -f wheelhouse -r ../requirements_1_build_install.txt
pip install --upgrade --no-index -f wheelhouse -r ../requirements_1_build_install.txt
pip wheel --no-cache-dir -f wheelhouse -r ../requirements_2_build.txt
pip install --upgrade --no-index -f wheelhouse -r ../requirements_2_install.txt

# we need separate "_build" and "_install" text files for some deps
# because they are built from git source
