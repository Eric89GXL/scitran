# SciTran – Scientific Data Management

## Installation

You'll need [Python 2.7](https://www.python.org) and [Git](https://git-scm.com).<br>
Scitran runs on Ubuntu 64-bit, or inside a virtual environment.

```bash
git clone https://github.com/scitran/scitran.git && cd scitran

./live.sh
```

If you're not using Linux, the command is the same but inside [Vagrant](https://www.vagrantup.com):

```bash
vagrant up

vagrant ssh -c /scitran/live.sh
```

In either case, you can now check out your local instance at [https://localhost:8443](https://localhost:8443)!

### Managing processes

Right now, uwsgi is sometimes poorly behaved, and remains running after quitting the script.

You can remediate this manually with `killall -9 uwsgi`.<br>
We will correct this problem soon.

## Configuring

The first setup will create a config.toml file for you from this [template](templates/config.toml).<br>
This has everything you need to configure your instance.


If you're looking to use scitran in production

### Serving valid SSL keys

You'll find a few files in `persistent/keys`

### Setting up your own OAuth provider

Scitran ships with a google OAuth key that will allow you to authenticate to a local instance.<br>
This key is not intended for production deployment - you'll need to acquire a new one.

For example, to set up with google:

1. Open the [google developer console](https://console.developers.google.com).
1. Create a new project, or select an existing project.
1. In the menu bar on the right side, click 'APIs & auth'.
	1. In 'APIs', enable the 'Google+' API.
	1. In 'Consent Screen', configure the 'Product Name' and 'email' fields.
	1. In 'Credentials', create a new Client ID for a web application.
		1. Javascript origin: URL where you will access the webapp.
			1. Example: https://domain.example.com
		1. Redirect URI: Oauth2 callback URL
			1. Example: https://domain.example.com/components/authentication/oauth2callback.html
	1. Note the client-ID, you will need this for config.toml.


You can enter your key and endpoints in config.toml under the `auth` section.<br>
Right now, only

### Note about virtual installs

Finally, note that if you're trying out scitran with vagrant, the database is not stored on the host.<br>
MongoDB does not play well with vagrant mounts, so you'll find it on the guest at `/scitran-mongo`.

Launching the vagrant with an existing host database will intentionally fail.<br>
Move `persistent/mongo` elsewhere before switching to vagrant.

In general, it is not wise to mix host and vagrant usage of a single instance.<br>
Separate scitran folders are recommended!
