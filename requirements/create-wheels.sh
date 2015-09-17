#!/usr/bin/env bash
set -e

# Designed to run one VM at a time.
vagrant halt

vagrant up precise
vagrant ssh precise -c '/vagrant/vagrant-build.sh 12.04'
vagrant halt

vagrant up trusty
vagrant ssh trusty -c '/vagrant/vagrant-build.sh 14.04'
vagrant halt

vagrant up vivid
vagrant ssh vivid -c '/vagrant/vagrant-build.sh 15.04'
vagrant halt

# vagrant up wily
# vagrant ssh wily -c '/vagrant/vagrant-build.sh 15.10'
# vagrant halt wily
