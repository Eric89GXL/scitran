#!/usr/bin/env python
#
import os
import sys
import pystache
import toml
import re

mapP = sys.argv[1]
temP  = sys.argv[2]
repairPythonTypes = True if len(sys.argv) > 3 else False

# Read user and static settings
settings = toml.loads(open(mapP, 'r').read())
static = toml.loads(open('scripts/mandantory.toml', 'r').read())

# Combine maps
mapping = static.copy()
mapping.update(settings)

# Hackaround for any template that needs an absolute path
mapping["absPath"]  = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

result = pystache.render(open(temP, 'r').read(), mapping)

# Horrible hackaround for python booleans being silly
# Better way would be to control pystache template rendering
if repairPythonTypes:
	result = result.replace("True", "true").replace("False", "false")

print result

try:
	sys.stdout.flush()
except:
	pass

