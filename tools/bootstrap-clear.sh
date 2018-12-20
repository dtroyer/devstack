#!/bin/bash
# bootstrap-clear.sh
#
# Stand-alone script to bootstrap a DevStack workspace on Clear Linux

set -o xtrace
set -o errexit

DEVSTACK_URL=https://github.com/starlingx-staging/devstack.git
DEVSTACK_BRANCH=stx/pike
DEST=/opt/stack
export STACK_USER=$(whoami)

mkdir -p $DEST
cd $DEST

# This currently forcably cleans out any existing devstack directory
# it would be more polite to update an existing one instead...
rm -rf devstack/
git clone --depth=1 ${DEVSTACK_URL} -b ${DEVSTACK_BRANCH}

# OK, we have a devstack dir, let's use it
cd devstack

# Ugly, address the comments in these and they will get merged
curl -O -L https://patch-diff.githubusercontent.com/raw/starlingx-staging/devstack/pull/10.patch
git apply 10.patch

curl -O -L https://patch-diff.githubusercontent.com/raw/starlingx-staging/devstack/pull/24.patch
git apply 24.patch

# Make our non-root user
tools/create-stack-user.sh

# mkdir -p /etc/sudoers.d/
# echo "stack ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/${STACK_USER}

swupd autoupdate --disable
export FORCE_LEGACY_PYTHON=true

# Create the things we assume are under /etc
mkdir -p /etc/libvirt
mkdir -p /etc/bash_completion.d
mkdir -p /etc/tgt/
ln -s /usr/share/defaults/etc/hosts /etc/hosts
ln -s /usr/lib/systemd/journald.conf.d/clear.conf /etc/systemd/journald.conf
ln -s /usr/share/defaults/sudo/sudoers.d /etc/sudoers.d

# Set up rabbit
systemctl start rabbitmq-server.service
cp -p /var/lib/rabbitmq/.erlang.cookie $HOME/.erlang.cookie
cp -p /var/lib/rabbitmq/.erlang.cookie /root/.erlang.cookie

pip2 install --no-binary :all: psycopg2===2.7.3
pip2 install libvirt-python==4.8.0

# Woe be it those who edit requirements.txt on the fly and expect things to actually work
git clone https://git.openstack.org/openstack/requirements.git -b stable/pike /opt/stack/requirements
sed -i -e 's/PyYAML===3.12/PyYAML===3.13/g' requirements/upper-constraints.txt
sed -i -e 's/libvirt-python===3.10.0/libvirt-python===4.8.0/g' requirements/upper-constraints.txt
sed -i -e 's/os-brick===1.15.6/os-brick===1.15.5/g' requirements/upper-constraints.txt
sed -i -e 's/docutils===0.13.1/docutils===0.14/g' requirements/upper-constraints.txt
sed -i -e 's/cffi===1.10.0/cffi===1.11.5/g' requirements/upper-constraints.txt

# Set up a default configuration
cp -p local.conf.example_vanilla local.conf
echo "HOST_IP=127.0.0.1" >> local.conf
echo "GIT_BASE=https://git.openstack.org" >> local.conf

if [ "$1" != "" ]; then
    echo "PIP_INDEX=https://$1" >>local.conf
fi

# Cover up our sins
chown -R ${STACK_USER} ${DEST}
