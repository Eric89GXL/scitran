# -*- mode: ruby -*-
# vi: set ft=ruby :


Vagrant.configure(2) do |config|

	#
	# Instructions for boxing an environment, currently not in use
	#
	# To create:
	# vagrant package --output scitran-vX.box
	#
	# To load from disk:
	# vagrant box add --name scitran-vX scitran-vX.box
	#
	# Docs:
	# http://docs.vagrantup.com/v2/cli/package.html

	# Box provided by Ubuntu
	config.vm.box = "trusty"
	config.vm.box_url = "https://cloud-images.ubuntu.com/vagrant/trusty/current/trusty-server-cloudimg-amd64-vagrant-disk1.box"
	config.vm.box_check_update = false

	# Port for humans and machines, respectively
	# Hackaround: Unlike everything else, these ports are NOT templated from config.toml, update them manually!
	config.vm.network "forwarded_port", guest: 8443, host: 8443
	config.vm.network "forwarded_port", guest: 8444, host: 8444

	# Create a private network, which allows host-only access to the machine using a specific IP.
	config.vm.network "private_network", type: "dhcp"

	# Create a public network, which generally matched to bridged network.
	# Bridged networks make the machine appear as another physical device on your network.
	# config.vm.network "public_network"

	# Share an additional folder to the guest VM (host, guest, [options...])
	# Could add (owner: "root", group: "root",) or similar if needed
	config.vm.synced_folder ".", "/scitran", mount_options: ["rw"]

	config.vm.provider "virtualbox" do |vb|
		vb.gui = false

		# VBoxManage settings
		vb.customize ["modifyvm", :id,
			# Better I/O, disable if problems
			"--ioapic", "on",

			# Set this to the number of CPU cores you have
			"--cpus",   "4",

			# RAM allocation
			"--memory", "1024"
		]
	end

	# Install scitran. Currently ran manually
	config.vm.provision "shell", :path => "./scripts/vagrant-once.sh"

end
