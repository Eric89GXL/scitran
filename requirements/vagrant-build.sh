#!/usr/bin/env bash
set -e

# This script is called once for each release
release=$1

outFolder="out"
saveFolder="/vagrant/out/linux/$release"

echo "-----------------------"
echo "BUILDING FOR $release"
echo "-----------------------"

# Work outside the shared folder for performance
rm -rf /tmp/wheels
mkdir -p /tmp/wheels
cd /tmp/wheels

# Ignore regex for pip
ignore="^(Requirement already up-to-date|Requirement already satisfied|Ignoring indexes)"

# Create a venv
virtualenv venv
source venv/bin/activate
pip install --upgrade pip wheel setuptools | (grep -Ev "$ignore" || true)

# Install pip deps that are required for building wheels
# These aren't ALL required, but it's easier not to segment.
for f in /vagrant/*basic*.txt; do
	echo "-----------------------"
	echo "FETCHING $f"
	echo "-----------------------"
	pip install -r $f | (grep -Ev "$ignore" || true)
done

# Build wheels. Each wheel file must have its deps satisfied by a previous file.
# Note that 'pip wheel' and 'pip install' require different flags for saving & loading wheels.
for f in /vagrant/*wheels*.txt; do
	echo "-----------------------"
	echo "BUILDING $f"
	echo "-----------------------"
	time pip wheel --wheel-dir $outFolder -r $f
	echo "-----------------------"
	echo "INSTALLING $f"
	echo "-----------------------"
	pip install --upgrade --no-index -f $outFolder -r $f
done

# Copy results to host
echo "Copying results to host..."
mkdir -p $saveFolder
cp $outFolder/* $saveFolder/
