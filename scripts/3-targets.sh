# User-level targets to run, aggregating a loose dep tree

# TODO: review and possibly use http://www.bashbooster.net/#task


# Install basic deps and load config.
# Likely required by all other targets.
function Setup() {
	DetectPlatform

	EnsurePackages
	EnsurePip
	EnsureVirtualEnv
	EnsurePipPackages
	EnsureConfig

	DeriveLocations
}

# Install prequisites
function Install() {
	EnsureNginx
	EnsureMongoDb
	EnsureGolang
	EnsureReflex
	EnsureTemplates
	EnsureCode
	EnsureClientCertificates
}

# Scitran-specific stateful setup
# Will temporarily launch platform for bootstrapping purposes
function Bootstrap() {
	bb-log-info "Bootstrapping users and test data"

	bb-log-info "Preparing infrastructre for bootstrap..."
	StartReflex

	echo
	echo "You probably want to add an initial superuser account to login."
	echo "This will let you into the system and add more users."
	echo

	while true; do
		read -p "Would you like to load a superuser account? [y/n] " yn
		case $yn in
			[Yy]* ) go=true;  break;;
			[Nn]* ) go=false; break;;
			* ) echo "Please answer yes or no.";;
		esac
	done

	if $go; then
		echo
		echo "This account's email address needs to be an email that can be used to login with google."
		echo "For example, a gmail account."
		echo

		read -p "Enter your email address: " email
		read -p "Enter your first name: " fname
		read -p "Enter your last name: " lname
		echo

		# Simple alternative to more mustache templating
		temp="$( bb-tmp-file )"
		cat templates/bootstrap.json | sed "s/your_address@email.com/$email/g" | sed "s/YourFirstName/$fname/g" | sed "s/YourLastName/$lname/g" > $temp

		BootStrapUsers $temp
	fi

	echo
	echo "You probably want to load an initial dataset to view & manage."
	echo "This will make it easier to understand how scitran works.."
	echo

	while true; do
		read -p "Would you like to load an initial dataset to view? [y/n] " yn
		case $yn in
			[Yy]* ) go=true;  break;;
			[Nn]* ) go=false; break;;
			* ) echo "Please answer yes or no.";;
		esac
	done
	echo

	if $go; then
		EnsureTestData
		BootStrapData
	fi

	bb-log-info "Finishing bootstrap..."
	StopReflex
}


# No-prompt initial setup
function SetupTarget() {
	Setup
	Install

	bb-log-info "Your shared secret is: ${_auth_shared_secret}"

	echo
	echo "Setup complete! You should now edit config.toml to configure your instance."
	echo "After that, continue with: ./live.sh bootstrap and or ./live.sh run"
	echo
}

function BootstrapTarget() {
	Setup
	Install
	Bootstrap

	echo
	echo "You are now ready to launch scitran!"
	echo "Try it out with: ./live.sh run"
	echo
}

# Default: run the platform
function RunTarget() {
	bb-log-info "Preparing environment"
	Setup
	Install

	# Run
	bb-log-info "Launching"
	Reflex
}

# Print the shared secret
function PrintSecret() {
	Setup
	echo ${_auth_shared_secret}
}

# What should our CI target run?
function CiTarget() {
	Setup
	Install

	# No-prompt varient of bootstrap target
	EnsureTestData
	EnsureBootstrapData

	# Sanity check some targets
	./live.sh cmd pip freeze
	./live.sh api ./bin/bootstrap.py -h
	./live.sh lint
}

function PyLint() {
	EnsurePackages
	EnsurePip
	EnsureVirtualEnv
	EnsurePipPackages
	PylintAll
}

function Release() {
	DetectPlatform

	# Remove old tar
	rm -f release.tar

	# Whitelist files to ship (AKA, don't put random certs + config in dist)
	bb-log-info "Preparing list of files to ship..."
	files=(`git ls-files`)
	files+=("code")

	bb-log-info "Creating release tarball..."
	# Don't create a tarbomb
	if [[ $platform == 'linux' ]]; then
		tar --transform 's,^,scitran/,rSh' -cf release.tar ${files[@]}
	elif [[ $platform == 'mac' ]]; then
		tar -s ',^,scitran/,' -cf release.tar ${files[@]}
	fi
}

function Update() {
	find . -type d -name .git -exec git -C "{}/.." pull \;
}
