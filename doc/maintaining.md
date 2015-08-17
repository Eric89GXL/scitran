# Maintenance

### Upgrading python packages

[Pip-tools](https://github.com/nvie/pip-tools) can help upgrade packages.

```
# List packages that have upgrades available.
./live.sh cmd pip-review -r
```

Then review and decide what upgrades to make, if any.<br>
Changes to `requirements.txt` should always be a pull request.
