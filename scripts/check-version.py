#!/usr/bin/env python
#
import os
import sys
import pystache
import toml
import re

filename = sys.argv[1]
mapping = toml.loads(open(filename, 'r').read())

template = toml.loads(open('templates/config.toml', 'r').read())

# Check config secret
if 'auth' in mapping and 'shared_secret' in mapping['auth']:
	if mapping['auth']['shared_secret'] == template['auth']['shared_secret']:

		print >> sys.stderr, '\nWarning: Your shared secret has not been changed from its default.\nYour system will be insecure until you change auth.shared_secret in config.toml.\n'


# Check config version
if 'flywheel' in mapping and 'version' in mapping['flywheel'] and ( isinstance( mapping['flywheel']['version'], int ) or isinstance( mapping['flywheel']['version'], float )):

	version  = mapping['flywheel']['version']
	expected = template['flywheel']['version']

	if version > expected:
		# Config is too new; proceed with caution
		print >> sys.stderr, '\nYour flywheel.version key in config.toml is ' + str(version) + ', expected ' + str(expected) + '.\nUnexpected behaviour may occur!\n'
	elif version < expected:
		# Config is too new; assume broken
		print >> sys.stderr, '\nYour flywheel.version key in config.toml is ' + str(version) + ', expected ' + str(expected) + '.\nSee the readme for migration instructions:\n\nhttps://github.com/scitran/scitran#migrating'
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
