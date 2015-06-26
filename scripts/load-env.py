#!/usr/bin/env python

import sys
import toml
import re

mapP = sys.argv[1]
mapping = toml.loads(open(mapP, 'r').read())

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

