#!/usr/bin/env python
#
import os
import sys
import pystache
import toml
import re

expectedVersion = toml.loads(open('templates/config.toml', 'r').read())['flywheel']['version']

mapP = sys.argv[1]
mapping = toml.loads(open(mapP, 'r').read())

if 'flywheel' in mapping and 'version' in mapping['flywheel'] and isinstance( mapping['flywheel']['version'], int ):
	version = mapping['flywheel']['version']

	if version > expectedVersion:
		# Config is too new; proceed with caution
		print >> sys.stderr, ''
		print >> sys.stderr, 'Your flywheel.version key in config.toml is ' + str(version) + ', expected ' + str(expectedVersion) + '.'
		print >> sys.stderr, 'Unexpected behaviour may occur!'
		print >> sys.stderr, ''
	elif version < expectedVersion:
		# Config is too new; assume broken
		print >> sys.stderr, ''
		print >> sys.stderr, 'Your flywheel.version key in config.toml is ' + str(version) + ', expected ' + str(expectedVersion) + '.'
		print >> sys.stderr, 'See the readme for migration instructions:'
		print >> sys.stderr, ''
		print >> sys.stderr, 'https://github.com/scitran/scitran#migrating'
		sys.exit(2)

else:
	print >> sys.stderr, ''
	print >> sys.stderr, 'No version key found in your config.toml.'
	print >> sys.stderr, 'This likely means your configuration is very old, or invalid.'
	print >> sys.stderr, 'Delete your config.toml to generate a new default configuration.'
	sys.exit(2)


try:
	sys.stderr.flush()
except:
	pass
