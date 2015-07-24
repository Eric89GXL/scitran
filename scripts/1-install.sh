# Initial setup for loading configuration.
# This file requires LoadConfig to have been called in a parent subshell.

# See 0-setup.sh for overall design notes.

# Save calculated locations. Required for all later functions.
function DeriveLocations() {
	golangDir=$BB_WORKSPACE/golang/${_version_golang}
	nginxDir=$BB_WORKSPACE/nginx/${_version_nginx}
	sconsDir=$BB_WORKSPACE/scons/${_version_scons}
	mongoDir=$BB_WORKSPACE/mongo/${_version_mongo}
	reflexLoc=$BB_WORKSPACE/reflex
}

function EnsureGolang() {(
	set +e
	bb-flag? golang-${_version_golang} && return
	set -e

	tarF="golang.tar.gz"
	temp="$( bb-tmp-dir )"
	snip="linux-amd64"

	# bb-download appears to have strange quirks. How about no.
	wget https://storage.googleapis.com/golang/go${_version_golang}.${snip}.tar.gz -O $temp/$tarF
	(
		cd $temp
		mkdir -p "$golangDir"
		tar xf $tarF --strip-components=1 -C $golangDir
	)

	GOROOT=$golangDir $golangDir/bin/go version
	bb-log-info Golang ${_version_golang} installed.
	bb-flag-set golang-${_version_golang}
)}

function EnsureScons() {(
	test -f $sconsDir/bin/scons || (
		temp="$( bb-tmp-dir )"

		(
			cd $temp

			wget https://downloads.sourceforge.net/project/scons/scons/${_version_scons}/scons-${_version_scons}.tar.gz -O download.tar.gz
			tar -xf download.tar.gz --strip-components 1

			python setup.py install --prefix=$sconsDir

			rm -rf $temp
		)
	)
)}

function EnsureMongoDb() {(

	test -d $mongoDir || (
		temp="$( bb-tmp-dir )"
		(
			cd $temp

			wget https://github.com/mongodb/mongo/archive/r${_version_mongo}.tar.gz -O download.tar.gz
			tar -xf download.tar.gz --strip-components 1

			nice $sconsDir/bin/scons mongod mongo \
				--disable-warnings-as-errors \
				-j$cores \
				--prefix=$mongoDir

			mkdir -p $mongoDir
			cd build/linux2/normal/mongo
			cp mongo mongod $mongoDir

			rm -rf $temp
		)
	)
)}

function EnsureNginx() {(

	# Ensure server cert for SSL
	test -f $nginxDir/sbin/nginx || (
		temp="$( bb-tmp-dir )"

		(
			cd $temp
			wget http://nginx.org/download/nginx-${_version_nginx}.tar.gz -O download.tar.gz
			tar -xf download.tar.gz --strip-components 1

			# Configure
			#	http://wiki.nginx.org/Install
			#	http://wiki.nginx.org/InstallOptions
			./configure \
				--with-pcre-jit \
				--with-http_ssl_module \
				--prefix=${nginxDir} \
				--conf-path=${_folder_generated}/nginx \
				--pid-path=${_folder_pids} \
				--http-log-path=${_folder_logs}/nginx-access.log \
				--error-log-path=${_folder_logs}/nginx-error.log

			# Compile, install
			nice make -j$cores
			make install

			rm -rf $temp $nginxDir/persistent
		)
	)
)}

function EnsureReflex() {(
	set +e
	bb-flag? reflex && return
	set -e

	temp="$( bb-tmp-dir )"

	GOROOT=$golangDir GOPATH=$temp PATH=$golangDir/bin:$PATH go get -v github.com/cespare/reflex
	mv $temp/bin/reflex $reflexLoc

	$reflexLoc -h 2>&1 | head -n 1
	bb-log-info "Reflex installed"
	bb-flag-set reflex
)}


#
# Environment Config
#
function EnsureTemplates() {(
	# Use the locations we just discovered
	mkdir -p ${_folder_logs} ${_folder_pids} ${_folder_generated} ${_folder_mongo} ${_folder_data}

	# Generate configured templates
	scripts/template.py config.toml ${_folder_templates}/web-config.js yes > ${_folder_generated}/web-config.js
	scripts/template.py config.toml ${_folder_templates}/reflex.config.sh  > ${_folder_generated}/reflex.config.sh
	scripts/template.py config.toml ${_folder_templates}/mongo.config.yaml > ${_folder_generated}/mongo.config.yaml
	scripts/template.py config.toml ${_folder_templates}/uwsgi.config.ini  > ${_folder_generated}/uwsgi.config.ini

	# Nginx is a folder
	cp -r ${_folder_templates}/nginx ${_folder_generated}
	scripts/template.py config.toml ${_folder_templates}/nginx/nginx.conf  > ${_folder_generated}/nginx/nginx.conf
)}

function EnsureCode() {(
	# Folder, ref, URI
	function EnsureClone() {
		test -d $1 || git clone -b $2 $3 $1
	}

	EnsureClone code/api      master   https://github.com/scitran/api.git
	EnsureClone code/www      master   https://github.com/scitran/sdm.git
	EnsureClone code/data     master   https://github.com/scitran/data.git
	EnsureClone code/apps     master   https://github.com/scitran/apps.git
	EnsureClone code/www      master   https://github.com/scitran/sdm.git

	# EnsureClone code/engine   stopgapp https://github.com/scitran/engine.git

	# Web app demands web-config.js
	mkdir -p code/www/app
	cp ${_folder_generated}/web-config.js code/www/app/
)}

function EnsureTestData() {(
	test -d ${_folder_testdata} || (
		temp="$( bb-tmp-file )"

		wget https://github.com/scitran/testdata/archive/master.tar.gz -O $temp

		tar -xvf $temp -C ${_folder_state}/
		mv ${_folder_state}/testdata-master ${_folder_testdata}
		rm -f $temp
	)
)}

function EnsureClientCertificates() {(
	mkdir -p ${_folder_keys}

	# Ensure server cert for SSL
	test -f ${_keys_combined} || (
		# Generate individual files
		openssl req -x509 -newkey rsa:2048 -subj "/C=US/ST=example/L=example/O=example/CN=example" -keyout ${_keys_key} -out ${_keys_cert} -days 999 -nodes

		# Combine for nginx
		cat ${_keys_key} ${_keys_cert} > ${_keys_combined}

		bb-log-info "Generated server certificate"
	)
)}