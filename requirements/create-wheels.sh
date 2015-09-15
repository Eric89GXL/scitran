#!/usr/bin/env bash
set -e

vagrant up trusty
vagrant ssh trusty -c '/vagrant/vagrant-build.sh 14.04'
vagrant halt trusty

vagrant up vivid
vagrant ssh vivid -c '/vagrant/vagrant-build.sh 15.04'
vagrant halt vivid

# vagrant up wily
# vagrant ssh wily -c '/vagrant/vagrant-build.sh 15.10'
# vagrant halt wily
