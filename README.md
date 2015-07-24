# SciTran – Scientific Data Management

Do Research. Extract Opportunity.

> The Flywheel Scientific Data Management tool can move us into a new generation — to draw much more value and insight from our data by bringing us together. It’s for the shareable age. It will make us extract much more value out of the hard work that we’re doing now in our own separate labs.

> \- [Brian A. Wandell](https://web.stanford.edu/group/vista/cgi-bin/wandell), Professor at Stanford University

[![Build Status](https://img.shields.io/travis/scitran/scitran.svg?style=flat-square)](https://travis-ci.org/scitran/scitran)

## Setup

You'll need [Python 2.7](https://www.python.org) and [Git](https://git-scm.com).<br>
You'll also need to grab a few things, depending on your operating system.

### Ubuntu 64-bit

For Ubuntu, we have a convenient script target:

```bash
./live.sh prepare
```

This will ask for sudo to install a couple packages.

### Vagrant

If you prefer, you can run Scitran inside a [Vagrant](https://www.vagrantup.com/) virtual machine - skip straight to installation!

### Other

Platforms not listed here are not officially supported yet, but should work fine.

Make sure you have your distribution's equivalent of `build-essential`, `python-dev`, `python-virtualenv`, and pip before continuing.


## Installation

You will need to edit [templates/bootstrap.json](templates/bootstrap.json) with your name and email address, before launching. In the future, this will be [handled for you](https://github.com/scitran/scitran/issues/37).

```bash
git clone https://github.com/scitran/scitran.git && cd scitran

./live.sh
```

Or, if you're using Vagrant, the command is the same but on the guest:

```bash
vagrant up

vagrant ssh -c /scitran/live.sh
```

In either case, you can now check out your local instance at [https://localhost:8443](https://localhost:8443)!

Your first run of `live.sh` will take quite awhile to install; subsequent runs will be much faster.
This script will start everything it needs (nginx, mongo, uwsgi) and run them until you quit (Control-C).

### Managing processes

Right now, uwsgi is sometimes poorly behaved, and remains running after quitting the script.

You can remediate this manually with `killall -9 uwsgi`.<br>
We will correct this problem soon.

## Configuring

The first setup will create a config.toml file for you from this [template](templates/config.toml).<br>
This has everything you need to configure your instance.

If you're looking to use scitran in production, there are a few things to prepare:

### Serving valid SSL keys

You'll find a few files in `persistent/keys`. Notably, `base-key+cert.pem` is used to serve scitran.<br>
Due to our current architecture, SSL is mandatory. Switch this key for one of your own as desired.

### Setting your machine auth secret

Automated requests (such as from a [reaper](https://github.com/scitran/reaper)) will need a shared secret.<br>
Anyone who knows this secret can make API requests, so you should protect it accordingly.<br>

We recommend using makepasswd to generate a suitable secret:

```bash
sudo apt-get install -y makepasswd

makepasswd --minchars=20 --maxchars=30
```

Save this value in your `config.toml` file as `auth.shared_secret`.

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
Right now, only a few providers have been tested. [Ask us](https://github.com/scitran/scitran/issues/new) if you have problems!

### Note about virtual installs

Finally, note that if you're trying out scitran with vagrant, the database is not stored on the host.<br>
MongoDB does not play well with vagrant mounts, so you'll find it on the guest at `/scitran-mongo`.

Launching the vagrant with an existing host database will intentionally fail.<br>
Move `persistent/mongo` elsewhere before switching to vagrant.

In general, it is not wise to mix host and vagrant usage of a single instance.<br>
Separate scitran folders are recommended!


## Migrating

If your [`config.toml`](templates/config.toml) is out of date, `live.sh` will decline to run.<br>
Usually, updating can be easily achieved by adding a new config key.

Check which version you're at, and read each neccesary section:

#### To 1.3

This version removes the `mongo.location` and `data.location` keys.

These folders are no longer configurable, by design.<br>
Bind mounts will allow you to place folders on different drives or locations: `mount --bind /folder1 /folder2`.

Remove both keys to upgrade.

#### To 1.2

This version removes the `ports.machine` key.<br>
Due to the changes we're making to authentication, this client-certificate port will no longer be used.

This version also adds the `auth.shared_secret` key.<br>
See our section about [configuring auth secret](#setting-your-machine-auth-secret) to set up.

#### To 1.1

Since config v1, we've added a `nginx.user` key.<br>
This will allow production users running as root to configure permissions for nginx workers.

See [our default `config.toml`](templates/config.toml) and copy the nginx section to upgrade.
