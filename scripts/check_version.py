#!/usr/bin/env python
#
import sys
import toml

with open(sys.argv[1], 'r') as fid:
    mapping = toml.loads(fid.read())

with open('templates/config.toml', 'r') as fid:
    template = toml.loads(fid.read())

# Check config secret
if 'auth' in mapping and 'shared_secret' in mapping['auth']:
    if mapping['auth']['shared_secret'] == template['auth']['shared_secret']:

        sys.stderr.write('\nWarning: Your shared secret has not been changed from its default.\n'
                         'Your system will be insecure until you change auth.shared_secret in config.toml.\n')


# Check config version
if ('flywheel' in mapping and 'version' in mapping['flywheel'] and
        isinstance(mapping['flywheel']['version'], (int, float))):
    version = mapping['flywheel']['version']
    expected = template['flywheel']['version']

    if version > expected:
        # Config is too new; proceed with caution
        sys.stderr.write('\nYour flywheel.version key in config.toml is %s, expected %s.\n'
                         'Unexpected behaviour may occur!\n' % (version, expected))
    elif version < expected:
        # Config is too new; assume broken
        sys.stderr.write('\nYour flywheel.version key in config.toml is %s, expected %s.\n'
                         'See the readme for migration instructions:\n\n'
                         'https://github.com/scitran/scitran#migrating' % (version, expected))
        sys.exit(2)

else:
    sys.stderr.write('\nNo version key found in your config.toml.\n'
                     'This likely means your configuration is very old, or invalid.\n'
                     'Delete your config.toml to generate a new default configuration.\n')
    sys.exit(2)


try:
    sys.stderr.flush()
except Exception:
    pass
