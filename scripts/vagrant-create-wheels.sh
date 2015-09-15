#! /bin/bash -e

# Special povisioning for wheel-building VMs.
# Do not change these package names if a future version of Ubuntu messes with them.
# Instead, copy this to a new file, modify, then change which provisioners fire for which wheel VMs.

packages=()

# General python requirements
packages+=(python-dev python-pip python-virtualenv)

# Various dev packages for scientific wheels
packages+=(libatlas3gf-base liblapack3gf libgmp10 libmpfr4 liblapack-dev libatlas-base-dev gfortran)\

apt-get -y install "${packages[@]}"
