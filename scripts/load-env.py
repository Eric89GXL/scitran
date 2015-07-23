#!/usr/bin/env python

import os
import sys
import toml
import re

mapP = sys.argv[1]

# Read user and static settings
settings = toml.loads(open(mapP, 'r').read())
static = toml.loads(open('scripts/mandantory.toml', 'r').read())

# Combine maps
mapping = static.copy()
mapping.update(settings)

# Hackaround for any template that needs an absolute path
mapping["absPath"]  = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def serialize(value, name):
	if value is None:
		print('{0}=""'.format(name))
	elif hasattr(value, 'items'):
		for key, subvalue in value.items():
			key = re.sub(r'[\W]', '_', key)
			serialize(subvalue, name + '_' + key)
	elif hasattr(value, '__iter__'):
		print("{0}_len={1}".format(name, len(value)))
		for i, v in enumerate(value):
			serialize(v, name + '_' + str(i))
	else:
		print('{0}="{1}"'.format(name, value))

serialize(mapping, '')

try:
	sys.stdout.flush()
except:
	pass

