#!/bin/bash
# bootstrap-clear.sh
#
# Stand-alone script to bootstrap a DevStack workspace on Clear Linux

set -x
set -e
whoami
mkdir  /opt
useradd -s /bin/bash -d /opt/stack -m stack
chown -R stack:stack /opt/stack
mkdir -p /etc/sudoers.d/
echo "stack ALL=(ALL) NOPASSWD: ALL" | tee /etc/sudoers.d/stack

swupd autoupdate --disable
export FORCE_LEGACY_PYTHON=true

cat > /opt/stack/_devstack.sh << EOF
#!/bin/bash
set -x
set -e
cd /opt/stack
export http_proxy="http://child-prc.intel.com:913"
export https_proxy="http://child-prc.intel.com:913"
export no_proxy="localhost,127.0.0.0/8,.intel.com,192.168.122.0/8"

echo "create folders under /etc"
sudo mkdir -p /etc/libvirt
sudo mkdir -p /etc/bash_completion.d
sudo mkdir -p /etc/tgt/
echo "create symblinks under /etc"
sudo ln -s /usr/share/defaults/etc/hosts /etc/hosts
sudo ln -s /usr/lib/systemd/journald.conf.d/clear.conf /etc/systemd/journald.conf
sudo ln -s /usr/share/defaults/sudo/sudoers.d /etc/sudoers.d
echo "start needed services"
sudo systemctl start rabbitmq-server.service
sudo cp /var/lib/rabbitmq/.erlang.cookie $HOME/.erlang.cookie
sudo cp /var/lib/rabbitmq/.erlang.cookie /root/.erlang.cookie
sudo pip2 install --no-binary :all: psycopg2===2.7.3
sudo pip2 install libvirt-python==4.8.0

rm -rf devstack/
git clone --depth=1 https://github.com/starlingx-staging/devstack.git -b stx/pike
curl -O -L https://patch-diff.githubusercontent.com/raw/starlingx-staging/devstack/pull/10.patch
curl -O -L https://patch-diff.githubusercontent.com/raw/starlingx-staging/devstack/pull/24.patch

git clone https://git.openstack.org/openstack/requirements.git -b stable/pike /opt/stack/requirements
sudo sed -i -e 's/PyYAML===3.12/PyYAML===3.13/g' requirements/upper-constraints.txt
sudo sed -i -e 's/libvirt-python===3.10.0/libvirt-python===4.8.0/g' requirements/upper-constraints.txt
sudo sed -i -e 's/os-brick===1.15.6/os-brick===1.15.5/g' requirements/upper-constraints.txt
sudo sed -i -e 's/docutils===0.13.1/docutils===0.14/g' requirements/upper-constraints.txt
sudo sed -i -e 's/cffi===1.10.0/cffi===1.11.5/g' requirements/upper-constraints.txt

git clone https://git.openstack.org/openstack/neutron.git -b stable/pike /opt/stack/neutron
sudo sed -i -e 's/\/usr\/sbin\/dnsmasq/\/usr\/bin\/dnsmasq/g' neutron/etc/neutron/rootwrap.d/dhcp.filters
sudo sed -i -e 's/\/sbin\/dnsmasq/\/usr\/bin\/dnsmasq/g' neutron/etc/neutron/rootwrap.d/dhcp.filters

cd devstack/
git apply ../10.patch
git apply ../24.patch
if [ "$1" != "" ]; then
    sudo sed -i -e 's/\$cmd_pip install/\$cmd_pip install -i https:\/\/$1/g' inc/python
fi
mv  local.conf.example_vanilla local.conf
echo "HOST_IP=127.0.0.1" >> local.conf
echo "GIT_BASE=https://git.openstack.org" >> local.conf

# Enable plugin's services
#echo "enable_service fm-common" >> local.conf
#echo "enable_service fm-api" >> local.conf
#echo "enable_service fm-mgr" >> local.conf
#echo "enable_service fm-rest-api" >> local.conf
#echo "enable_service sm-common" >> local.conf
#echo "enable_service sm-api" >> local.conf
#echo "enable_service nfv-common" >> local.conf
#echo "enable_service nfv-vim" >> local.conf
#echo "disable_service mysql" >> local.conf
#echo "enable_service postgresql" >> local.conf

# Enable plugins

#echo "enable_plugin stx-fault https://git.openstack.org/openstack/stx-fault.git" >> local.conf
#echo "enable_plugin stx-nfv https://git.openstack.org/openstack/stx-nfv.git" >> local.conf
#echo "enable_plugin stx-update https://git.openstack.org/openstack/stx-update.git" >> local.conf
#echo "enable_plugin stx-config https://git.openstack.org/openstack/stx-config.git" >> local.conf
#echo "enable_plugin stx-integ https://git.openstack.org/openstack/stx-integ.git" >> local.conf
#echo "enable_plugin stx-metal https://git.openstack.org/openstack/stx-metal.git" >> local.conf
#echo "enable_plugin stx-ha https://git.openstack.org/openstack//stx-ha.git" >> local.conf
#echo "enable_plugin stx-gui https://git.openstack.org/openstack/stx-gui.git" >> local.conf

./stack.sh
EOF
chmod 777 /opt/stack/_devstack.sh
if [ "$1" != "" ]; then
    su stack -c "/opt/stack/_devstack.sh $1"
else
    su stack -c "/opt/stack/_devstack.sh"
fi
