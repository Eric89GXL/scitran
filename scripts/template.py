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

mapping = toml.loads(open(mapP, 'r').read())

# Locations that are not configurable
mapping["tDir"]     ="templates"
mapping["stateDir"] ="persistent"
mapping["gDir"]     ="persistent/generated"
mapping["lDir"]     ="persistent/logs"
mapping["pDir"]     ="persistent/pids"
mapping["venv"]     ="persistent/venv"

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

