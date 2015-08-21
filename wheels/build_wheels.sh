#!/bin/bash -ef

# must have the following installed via synaptic:
# build-essential python-dev libatlas-dev libatlas-base-dev liblapack-dev gfortran libgmp-dev libmpfr-dev python-pip

# this will create a "wheelhouse" directory in the current dir with
# all the requirements
pip wheel --no-cache-dir --find-links=wheelhouse -r ../requirements.txt

