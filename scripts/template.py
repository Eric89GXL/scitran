#!/usr/bin/env python
#
import os
import sys
import pystache
import toml

mapP = sys.argv[1]
temP = sys.argv[2]
repairPythonTypes = True if len(sys.argv) > 3 else False

# Read user and static settings
with open(mapP, 'r') as fid:
    settings = toml.loads(fid.read())
with open('scripts/mandantory.toml', 'r') as fid:
    static = toml.loads(fid.read())

# Combine maps
mapping = static.copy()
mapping.update(settings)

# Hackaround for any template that needs an absolute path
mapping["absPath"] = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

with open(temP, 'r') as fid:
    result = pystache.render(fid.read(), mapping)

# Horrible hackaround for python booleans being silly
# Better way would be to control pystache template rendering
if repairPythonTypes:
    result = result.replace("True", "true").replace("False", "false")

print result

try:
    sys.stdout.flush()
except Exception:
    pass
