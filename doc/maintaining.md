# Maintenance

### Upgrading python packages

[Pip-tools](https://github.com/nvie/pip-tools) can help upgrade packages.
Currently, we've got some hacks to be aware of.


```
# Interactively upgrade saved packages.
# Decline upgrades offered that are packages in requirements-manual.txt
./live.sh venv pip-review -i

# Save changes from environment
# Will break some things
./live.sh venv pip-dump

# Don't clobber hack file
git checkout requirements-manual.txt
```

Then review `requirements.txt`. In particular, it will remove packages like `wsgiref` and `argparse` that are needed by the API but are not found by the tool.

Changes to `requirements.txt` should always be a pull request.
