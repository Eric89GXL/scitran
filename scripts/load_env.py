#!/usr/bin/env python

from __future__ import print_function

import os
import sys
import toml
import re

mapP = sys.argv[1]

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
except Exception:
    pass
